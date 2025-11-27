from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Iterable, Sequence

from .types import MarketDataPoint, StrategyConfig, StrategyContext, StrategyRecommendation


class BaseStrategy(ABC):
    """Abstract base class for all MT5 trading strategies."""

    def __init__(self, config: StrategyConfig):
        self.config = config

    @property
    def name(self) -> str:
        return self.config.name

    @property
    def required_history(self) -> int:
        """Minimum historical candles required to produce a signal."""

        return 200

    @abstractmethod
    def generate_signals(
        self,
        market_data: Sequence[MarketDataPoint],
        context: StrategyContext,
    ) -> list[StrategyRecommendation]:
        """Produce trade recommendations from historical data."""

    def filter_data(
        self,
        market_data: Iterable[MarketDataPoint],
        symbol: str,
        timeframe: str,
    ) -> list[MarketDataPoint]:
        return [
            candle
            for candle in market_data
            if candle.symbol == symbol and candle.timeframe == timeframe
        ]
