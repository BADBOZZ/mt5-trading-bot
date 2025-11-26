"""Performance metric helpers shared by the Strategy Tester and live bot."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from math import sqrt
from typing import Iterable, List, Tuple

import numpy as np
import pandas as pd


def _safe_div(numerator: float, denominator: float) -> float:
    return numerator / denominator if denominator else 0.0


@dataclass(slots=True)
class TradeResult:
    """Container for evaluated trades."""

    symbol: str
    direction: str
    entry_time: datetime
    exit_time: datetime
    entry_price: float
    exit_price: float
    volume: float
    pnl: float
    fees: float
    mae: float = 0.0  # max adverse excursion (price distance)
    mfe: float = 0.0  # max favourable excursion (price distance)
    strategy: str = ""
    exit_reason: str = ""

    @property
    def holding_minutes(self) -> float:
        return max((self.exit_time - self.entry_time).total_seconds() / 60, 0.0)


@dataclass(slots=True)
class PerformanceReport:
    """Aggregated statistics produced after a run."""

    total_return: float
    annual_return: float
    sharpe: float
    sortino: float
    max_drawdown: float
    profit_factor: float
    win_rate: float
    expectancy: float
    avg_trade: float
    trades: int
    gross_profit: float
    gross_loss: float
    equity_curve: pd.Series
    drawdown_curve: pd.Series
    daily_returns: pd.Series

    def to_dict(self) -> dict:
        """Return JSON-serializable summary."""
        return {
            "total_return": self.total_return,
            "annual_return": self.annual_return,
            "sharpe": self.sharpe,
            "sortino": self.sortino,
            "max_drawdown": self.max_drawdown,
            "profit_factor": self.profit_factor,
            "win_rate": self.win_rate,
            "expectancy": self.expectancy,
            "avg_trade": self.avg_trade,
            "trades": self.trades,
            "gross_profit": self.gross_profit,
            "gross_loss": self.gross_loss,
        }


def build_equity_curve(points: List[Tuple[datetime, float]]) -> pd.Series:
    """Convert time/equity tuples into a pandas Series."""
    if not points:
        return pd.Series(dtype=float)
    index, values = zip(*points)
    return pd.Series(values, index=pd.DatetimeIndex(index))


def _annualize_factor(equity_curve: pd.Series) -> float:
    """Estimate how many periods constitute a trading year."""
    if len(equity_curve) < 2:
        return 1.0
    duration_days = (equity_curve.index[-1] - equity_curve.index[0]).days
    duration_days = max(duration_days, 1)
    return 365.0 / duration_days * len(equity_curve)


def _drawdown(curve: pd.Series) -> pd.Series:
    high_water = curve.cummax()
    return (curve - high_water) / high_water.replace(0, np.nan)


def summarize_performance(
    trades: Iterable[TradeResult],
    equity_curve: pd.Series,
    risk_free_rate: float = 0.0,
) -> PerformanceReport:
    """Create a `PerformanceReport` object from trade + equity history."""
    trade_list = list(trades)
    if equity_curve.empty:
        raise ValueError("Equity curve cannot be empty")

    gross_profit = sum(t.pnl for t in trade_list if t.pnl > 0)
    gross_loss = sum(t.pnl for t in trade_list if t.pnl < 0)
    total_return = _safe_div(equity_curve.iloc[-1], equity_curve.iloc[0]) - 1

    daily_returns = equity_curve.resample("1D").last().pct_change().dropna()
    annual_factor = max(_annualize_factor(equity_curve), 1.0)
    per_period_rate = risk_free_rate / annual_factor
    returns = equity_curve.pct_change().dropna()
    sharpe = (
        (returns.mean() - per_period_rate) / returns.std() * sqrt(annual_factor)
        if len(returns) > 1 and returns.std() > 0
        else 0.0
    )
    downside = returns[returns < 0]
    sortino = (
        (returns.mean() - per_period_rate) / downside.std() * sqrt(annual_factor)
        if len(downside) > 1 and downside.std() > 0
        else 0.0
    )

    drawdown_curve = _drawdown(equity_curve).fillna(0.0)
    max_drawdown = drawdown_curve.min()

    profit_factor = (
        gross_profit / abs(gross_loss) if gross_loss != 0 else float("inf")
        if gross_profit > 0
        else 0.0
    )
    wins = [t for t in trade_list if t.pnl > 0]
    losses = [t for t in trade_list if t.pnl <= 0]
    win_rate = _safe_div(len(wins), len(trade_list))
    avg_win = np.mean([t.pnl for t in wins]) if wins else 0.0
    avg_loss = np.mean([t.pnl for t in losses]) if losses else 0.0
    expectancy = win_rate * avg_win + (1 - win_rate) * avg_loss
    avg_trade = np.mean([t.pnl for t in trade_list]) if trade_list else 0.0

    annual_return = (1 + total_return) ** (annual_factor / len(equity_curve)) - 1

    return PerformanceReport(
        total_return=total_return,
        annual_return=annual_return,
        sharpe=sharpe,
        sortino=sortino,
        max_drawdown=max_drawdown,
        profit_factor=profit_factor,
        win_rate=win_rate,
        expectancy=expectancy,
        avg_trade=avg_trade,
        trades=len(trade_list),
        gross_profit=gross_profit,
        gross_loss=gross_loss,
        equity_curve=equity_curve,
        drawdown_curve=drawdown_curve,
        daily_returns=daily_returns,
    )
