from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Iterable, Sequence


@dataclass(frozen=True)
class TradeRecord:
    profit: float
    balance_after: float


@dataclass(frozen=True)
class PerformanceSummary:
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    profit_factor: float
    recovery_factor: float


def _returns_from_trades(trades: Sequence[TradeRecord]) -> Sequence[float]:
    returns = []
    for trade in trades:
        balance_before = trade.balance_after - trade.profit
        pct_return = trade.profit / balance_before if balance_before else 0.0
        returns.append(pct_return)
    return returns


def sharpe_ratio(returns: Sequence[float], risk_free_rate: float = 0.0) -> float:
    if len(returns) < 2:
        return 0.0
    mean_return = sum(returns) / len(returns)
    variance = sum((r - mean_return) ** 2 for r in returns) / (len(returns) - 1)
    std_dev = math.sqrt(max(variance, 0.0))
    if std_dev == 0:
        return 0.0
    excess = mean_return - (risk_free_rate / 252.0)
    return excess / std_dev


def max_drawdown(trades: Sequence[TradeRecord]) -> float:
    peak = 0.0
    max_dd = 0.0
    for trade in trades:
        if trade.balance_after > peak:
            peak = trade.balance_after
        max_dd = max(max_dd, peak - trade.balance_after)
    return max_dd


def win_rate(trades: Sequence[TradeRecord]) -> float:
    if not trades:
        return 0.0
    wins = sum(1 for trade in trades if trade.profit >= 0)
    return wins / len(trades)


def profit_factor(trades: Sequence[TradeRecord]) -> float:
    gross_profit = sum(trade.profit for trade in trades if trade.profit > 0)
    gross_loss = sum(-trade.profit for trade in trades if trade.profit < 0)
    if gross_loss == 0:
        return 0.0
    return gross_profit / gross_loss


def recovery_factor(trades: Sequence[TradeRecord]) -> float:
    net_profit = sum(trade.profit for trade in trades)
    dd = max_drawdown(trades)
    if dd == 0:
        return 0.0
    return net_profit / dd


def summarize_performance(trades: Iterable[TradeRecord], risk_free_rate: float = 0.0) -> PerformanceSummary:
    trade_list = list(trades)
    return PerformanceSummary(
        sharpe_ratio=sharpe_ratio(_returns_from_trades(trade_list), risk_free_rate),
        max_drawdown=max_drawdown(trade_list),
        win_rate=win_rate(trade_list),
        profit_factor=profit_factor(trade_list),
        recovery_factor=recovery_factor(trade_list),
    )
