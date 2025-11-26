"""
Utility helpers that mirror the MT5-side metrics implemented in
`src/backtesting/PerformanceAnalyzer.mq5`.  The Python copy is used for
post-processing Strategy Tester exports so we can validate performance,
generate comparison charts, and feed results into CI jobs.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Sequence, Tuple

import csv


@dataclass
class TradeSample:
    time: str
    profit: float
    equity: float


@dataclass
class PerformanceSummary:
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    profit_factor: float
    recovery_factor: float
    total_trades: int
    total_profit: float


def sharpe_ratio(returns: Sequence[float], risk_free: float = 0.0) -> float:
    if not returns:
        return 0.0
    mean_ret = sum(returns) / len(returns)
    variance = sum((r - mean_ret) ** 2 for r in returns) / max(1, len(returns) - 1)
    std_dev = variance ** 0.5
    if std_dev == 0:
        return 0.0
    return (mean_ret - risk_free) / std_dev


def max_drawdown(equity_curve: Sequence[float]) -> float:
    peak = float("-inf")
    max_dd = 0.0
    for equity in equity_curve:
        peak = max(peak, equity)
        drawdown = peak - equity
        max_dd = max(max_dd, drawdown)
    return max_dd


def win_rate(trades: Sequence[float]) -> float:
    if not trades:
        return 0.0
    wins = sum(1 for p in trades if p >= 0)
    return wins / len(trades)


def profit_factor(trades: Sequence[float]) -> float:
    gains = sum(p for p in trades if p > 0)
    losses = sum(p for p in trades if p < 0)
    if losses == 0:
        return 0.0
    return gains / abs(losses)


def recovery_factor(total_profit: float, max_dd: float) -> float:
    if max_dd == 0:
        return 0.0
    return total_profit / max_dd


def summarize_trades(trades: Sequence[float], equity_curve: Sequence[float]) -> PerformanceSummary:
    summary = PerformanceSummary(
        sharpe_ratio=sharpe_ratio(trades),
        max_drawdown=max_drawdown(equity_curve),
        win_rate=win_rate(trades),
        profit_factor=profit_factor(trades),
        recovery_factor=recovery_factor(sum(trades), max_drawdown(equity_curve)),
        total_trades=len(trades),
        total_profit=sum(trades),
    )
    return summary


def load_trade_history(path: Path) -> Tuple[List[TradeSample], PerformanceSummary]:
    rows: List[TradeSample] = []
    profits: List[float] = []
    equity: List[float] = []
    with path.open("r", newline="") as fp:
        reader = csv.DictReader(fp, delimiter=";")
        for row in reader:
            sample = TradeSample(
                time=row["time"],
                profit=float(row["profit"]),
                equity=float(row["equity"]),
            )
            rows.append(sample)
            profits.append(sample.profit)
            equity.append(sample.equity)
    summary = summarize_trades(profits, equity)
    return rows, summary
