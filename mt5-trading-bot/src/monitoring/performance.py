"""Utilities to collect live-performance metrics identical to the backtester."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from datetime import datetime
from typing import Deque, List, Tuple

from ..backtesting.metrics import TradeResult, build_equity_curve, summarize_performance


@dataclass(slots=True)
class EquityPoint:
    """Stores timestamp/equity pairs."""

    timestamp: datetime
    equity: float


class PerformanceTracker:
    """Aggregates trade + equity data and exposes consolidated reports."""

    def __init__(self, initial_balance: float, max_points: int = 5000):
        self.initial_balance = initial_balance
        self.trade_log: List[TradeResult] = []
        self.equity_points: Deque[Tuple[datetime, float]] = deque(maxlen=max_points)
        self.record_equity(datetime.utcnow(), initial_balance)

    def record_trade(self, trade: TradeResult | None = None, **kwargs) -> None:
        """Append a trade to the log."""
        if trade is None:
            trade = TradeResult(**kwargs)
        self.trade_log.append(trade)

    def record_equity(self, timestamp: datetime, equity: float) -> None:
        """Append a new equity value."""
        self.equity_points.append((timestamp, equity))

    def snapshot(self):
        """Return the latest PerformanceReport if enough data is available."""
        if len(self.equity_points) < 2:
            return None
        curve = build_equity_curve(list(self.equity_points))
        return summarize_performance(self.trade_log, curve)

    def summary_dict(self) -> dict:
        report = self.snapshot()
        return report.to_dict() if report else {}

    def reset(self) -> None:
        self.trade_log.clear()
        self.equity_points.clear()
        self.record_equity(datetime.utcnow(), self.initial_balance)
