"""Utilities for parsing Strategy Tester reports and generating analytics."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Sequence

import matplotlib.pyplot as plt
import pandas as pd


@dataclass
class PerformanceSnapshot:
    """Computed metrics for a single strategy run."""

    name: str
    sharpe: float
    win_rate: float
    profit_factor: float
    recovery_factor: float
    max_drawdown: float
    net_profit: float


class BacktestReport:
    """Helper that wraps a CSV trade history exported from MT5."""

    def __init__(self, trades: pd.DataFrame, name: str | None = None) -> None:
        self.trades = trades.sort_values("time").reset_index(drop=True)
        self.name = name or "strategy"
        self.trades["equity"] = self.trades["profit"].cumsum()

    @classmethod
    def from_csv(cls, path: Path) -> "BacktestReport":
        trades = pd.read_csv(path, parse_dates=["time"])
        return cls(trades, name=path.stem)

    def sharpe_ratio(self, risk_free: float = 0.0) -> float:
        if self.trades.empty:
            return 0.0
        returns = self.trades["profit"]
        excess = returns - (risk_free / 252.0)
        stdev = returns.std(ddof=1)
        if stdev == 0 or pd.isna(stdev):
            return 0.0
        return (excess.mean() / stdev) * (252 ** 0.5)

    def win_rate(self) -> float:
        if self.trades.empty:
            return 0.0
        wins = (self.trades["profit"] > 0).sum()
        total = (self.trades["profit"] != 0).sum()
        return (wins / total) * 100 if total else 0.0

    def profit_factor(self) -> float:
        gross_profit = self.trades.loc[self.trades["profit"] > 0, "profit"].sum()
        gross_loss = self.trades.loc[self.trades["profit"] < 0, "profit"].sum()
        return gross_profit / abs(gross_loss) if gross_loss != 0 else 0.0

    def max_drawdown(self) -> float:
        equity = self.trades["equity"]
        peak = equity.cummax()
        drawdowns = peak - equity
        return drawdowns.max() if not drawdowns.empty else 0.0

    def recovery_factor(self) -> float:
        dd = self.max_drawdown()
        net_profit = self.trades["profit"].sum()
        return net_profit / dd if dd else 0.0

    def plot_equity(self, output: Path) -> Path:
        output.parent.mkdir(parents=True, exist_ok=True)
        plt.figure(figsize=(8, 4))
        plt.plot(self.trades["time"], self.trades["equity"], label=self.name)
        plt.title(f"Equity curve - {self.name}")
        plt.xlabel("Time")
        plt.ylabel("Equity change")
        plt.grid(True, alpha=0.3)
        plt.legend()
        plt.tight_layout()
        plt.savefig(output)
        plt.close()
        return output

    def summary(self) -> PerformanceSnapshot:
        return PerformanceSnapshot(
            name=self.name,
            sharpe=self.sharpe_ratio(),
            win_rate=self.win_rate(),
            profit_factor=self.profit_factor(),
            recovery_factor=self.recovery_factor(),
            max_drawdown=self.max_drawdown(),
            net_profit=self.trades["profit"].sum(),
        )


def compare_strategies(reports: Sequence[BacktestReport]) -> pd.DataFrame:
    """Return a dataframe ranking strategies by Sharpe and net profit."""

    rows = [report.summary().__dict__ for report in reports]
    df = pd.DataFrame(rows).set_index("name")
    return df.sort_values(by=["sharpe", "net_profit"], ascending=False)


def export_trade_history(trades: Iterable[Dict[str, float]], output: Path) -> Path:
    """Write trade history to disk for archival or Strategy Tester imports."""

    frame = pd.DataFrame(trades)
    frame.to_csv(output, index=False)
    return output
