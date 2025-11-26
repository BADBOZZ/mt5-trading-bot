"""Utility functions for summarizing Strategy Tester performance outputs."""

from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from typing import Iterable, Sequence


@dataclass
class BacktestSummary:
    """Container with the most common MT5 Strategy Tester stats."""

    trades: int
    win_rate: float
    sharpe_ratio: float
    profit_factor: float
    recovery_factor: float
    max_drawdown: float
    net_profit: float


def _ensure_sequence(values: Iterable[float]) -> Sequence[float]:
    data = list(values)
    if not data:
        return [0.0]
    return data


def sharpe_ratio(returns: Iterable[float], risk_free: float = 0.0) -> float:
    """Return the trade-based Sharpe ratio (per-trade granularity)."""

    series = _ensure_sequence(returns)
    if len(series) < 2:
        return 0.0

    avg = sum(series) / len(series)
    variance = sum((val - avg) ** 2 for val in series) / (len(series) - 1)
    if variance <= 0.0:
        return 0.0

    return (avg - risk_free) / sqrt(variance)


def max_drawdown(equity_curve: Iterable[float]) -> float:
    """Return the maximum relative drawdown from an MT5 equity curve."""

    equity = _ensure_sequence(equity_curve)
    peak = equity[0]
    max_dd = 0.0

    for value in equity:
        peak = max(peak, value)
        if peak == 0:
            continue
        drawdown = (peak - value) / peak
        max_dd = max(max_dd, drawdown)

    return max_dd


def profit_factor(trade_profits: Iterable[float]) -> float:
    """Return the profit factor (gross profit / gross loss absolute)."""

    profits = _ensure_sequence(trade_profits)
    gross_profit = sum(p for p in profits if p > 0)
    gross_loss = abs(sum(p for p in profits if p < 0))

    if gross_loss == 0:
        return float("inf") if gross_profit > 0 else 0.0

    return gross_profit / gross_loss


def win_rate(outcomes: Iterable[bool]) -> float:
    """Return the win rate for the sample size."""

    sample = list(outcomes)
    if not sample:
        return 0.0
    return sum(1 for outcome in sample if outcome) / len(sample)


def summarize_trades(trade_history: Sequence[dict]) -> BacktestSummary:
    """Aggregate Strategy Tester trade history into the requested metrics.

    The function expects each trade entry to expose at least the following
    keys (or attributes via __getattr__): `profit`, `balance`, and `equity`.
    """

    def _value(trade, key, default=0.0):
        if isinstance(trade, dict):
            return trade.get(key, default)
        return getattr(trade, key, default)

    profits = [_value(trade, "profit") for trade in trade_history]
    equity = [_value(trade, "equity", _value(trade, "balance", 0.0)) for trade in trade_history]
    outcomes = [profit > 0 for profit in profits]
    net_profit = sum(profits)
    dd = max_drawdown(equity)
    pf = profit_factor(profits)
    sr = sharpe_ratio(profits)
    wr = win_rate(outcomes)
    recovery = net_profit / dd if dd else float("inf")

    return BacktestSummary(
        trades=len(trade_history),
        win_rate=wr,
        sharpe_ratio=sr,
        profit_factor=pf,
        recovery_factor=recovery,
        max_drawdown=dd,
        net_profit=net_profit,
    )
