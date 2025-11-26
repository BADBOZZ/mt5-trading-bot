"""Performance metric helpers for Strategy Tester trade history exports."""
from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from typing import Iterable, Sequence

import numpy as np
import pandas as pd


@dataclass(slots=True)
class PerformanceStats:
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    profit_factor: float
    recovery_factor: float
    total_trades: int
    net_profit: float


def _equity_curve(trades: pd.DataFrame) -> pd.Series:
    if trades.empty:
        return pd.Series(dtype=float)
    return trades["profit"].cumsum()


def calculate_sharpe_ratio(returns: Sequence[float], risk_free_rate: float = 0.0) -> float:
    series = np.array(returns, dtype=float)
    if series.size == 0 or np.all(series == 0):
        return 0.0
    excess = series - risk_free_rate
    denominator = np.std(excess, ddof=1)
    if denominator == 0:
        return 0.0
    return float(np.mean(excess) / denominator * sqrt(252))


def calculate_max_drawdown(equity: Iterable[float]) -> float:
    peak = float("-inf")
    max_dd = 0.0
    for value in equity:
        peak = max(peak, value)
        drawdown = peak - value
        max_dd = max(max_dd, drawdown)
    return max_dd


def calculate_win_rate(trades: pd.DataFrame) -> float:
    if trades.empty:
        return 0.0
    wins = (trades["profit"] > 0).sum()
    return float(wins / len(trades))


def calculate_profit_factor(trades: pd.DataFrame) -> float:
    gross_profit = trades.loc[trades["profit"] > 0, "profit"].sum()
    gross_loss = trades.loc[trades["profit"] < 0, "profit"].sum()
    if gross_loss == 0:
        return float("inf") if gross_profit > 0 else 0.0
    return float(abs(gross_profit / gross_loss))


def calculate_recovery_factor(net_profit: float, max_drawdown: float) -> float:
    if max_drawdown == 0:
        return float("inf") if net_profit > 0 else 0.0
    return float(net_profit / max_drawdown)


def summarize_performance(trades: pd.DataFrame) -> PerformanceStats:
    if "profit" not in trades.columns:
        raise ValueError("Trade history must include a 'profit' column")

    equity = _equity_curve(trades)
    sharpe = calculate_sharpe_ratio(trades["profit"].tolist())
    drawdown = calculate_max_drawdown(equity.values if not equity.empty else [])
    win_rate = calculate_win_rate(trades)
    profit_factor = calculate_profit_factor(trades)
    net_profit = trades["profit"].sum()
    recovery_factor = calculate_recovery_factor(net_profit, drawdown)

    return PerformanceStats(
        sharpe_ratio=round(sharpe, 4),
        max_drawdown=round(drawdown, 2),
        win_rate=round(win_rate, 4),
        profit_factor=round(profit_factor, 4),
        recovery_factor=round(recovery_factor, 4),
        total_trades=int(len(trades)),
        net_profit=round(net_profit, 2),
    )


__all__ = [
    "PerformanceStats",
    "calculate_max_drawdown",
    "calculate_profit_factor",
    "calculate_recovery_factor",
    "calculate_sharpe_ratio",
    "calculate_win_rate",
    "summarize_performance",
]
