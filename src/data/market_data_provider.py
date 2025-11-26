"""
Market data providers abstract away MT5/brokerage integrations.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime, timedelta
from random import gauss
from typing import Iterable, List

from core.enums import Timeframe
from core.types import MarketDataSlice, OHLCVBar


class MarketDataProvider(ABC):
    """Abstract data interface consumed by the strategy engine."""

    @abstractmethod
    def fetch(
        self, symbol: str, timeframe: Timeframe, bars: int = 500
    ) -> MarketDataSlice:
        """Return a slice of OHLCV data sorted from oldest to newest."""


class SyntheticMarketDataProvider(MarketDataProvider):
    """
    Deterministic pseudo-random provider useful for backtests and CI.

    The provider simulates a geometric random walk with mild volatility so
    that strategies can be integrated-tested without connecting to MT5.
    """

    def __init__(self, seed_price: float = 1.0):
        self.seed_price = seed_price

    def fetch(
        self, symbol: str, timeframe: Timeframe, bars: int = 500
    ) -> MarketDataSlice:
        closes: List[float] = []
        price = self.seed_price

        for _ in range(bars):
            drift = gauss(0, 0.001)
            price = max(0.0001, price * (1 + drift))
            closes.append(price)

        created_at = datetime.utcnow()
        delta = self._timeframe_delta(timeframe)
        ohlcv_bars = [
            OHLCVBar(
                timestamp=created_at - delta * (bars - idx),
                open=close * (1 - 0.0005),
                high=close * (1 + 0.001),
                low=close * (1 - 0.001),
                close=close,
                volume=1_000,
            )
            for idx, close in enumerate(closes)
        ]

        return MarketDataSlice(symbol=symbol, timeframe=timeframe, bars=ohlcv_bars)

    @staticmethod
    def _timeframe_delta(timeframe: Timeframe) -> timedelta:
        mapping = {
            Timeframe.M1: timedelta(minutes=1),
            Timeframe.M5: timedelta(minutes=5),
            Timeframe.M15: timedelta(minutes=15),
            Timeframe.M30: timedelta(minutes=30),
            Timeframe.H1: timedelta(hours=1),
            Timeframe.H4: timedelta(hours=4),
            Timeframe.D1: timedelta(days=1),
            Timeframe.W1: timedelta(weeks=1),
        }
        return mapping[timeframe]


__all__ = ["MarketDataProvider", "SyntheticMarketDataProvider"]

