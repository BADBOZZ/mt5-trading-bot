"""
Signal orchestration across multiple strategies, symbols, and timeframes.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, List, Tuple, Type

from core.config import EngineConfig, StrategySettings
from core.enums import SignalDirection, StrategyType
from core.types import MarketDataSlice, StrategyContext, StrategySignal
from data.market_data_provider import MarketDataProvider
from strategies.base import BaseStrategy
from strategies.breakout import BreakoutStrategy
from strategies.mean_reversion import MeanReversionStrategy
from strategies.neural_network import NeuralNetworkStrategy
from strategies.trend_following import TrendFollowingStrategy


STRATEGY_REGISTRY: Dict[StrategyType, Type[BaseStrategy]] = {
    StrategyType.TREND_FOLLOWING: TrendFollowingStrategy,
    StrategyType.MEAN_REVERSION: MeanReversionStrategy,
    StrategyType.BREAKOUT: BreakoutStrategy,
    StrategyType.NEURAL_NETWORK: NeuralNetworkStrategy,
}


class StrategyEngine:
    """Coordinates data retrieval and signal generation for multiple strategies."""

    def __init__(
        self,
        data_provider: MarketDataProvider,
        context: StrategyContext,
        settings: Iterable[StrategySettings],
    ):
        self.data_provider = data_provider
        self.context = context
        self._strategies: Dict[Tuple[str, str, StrategyType], BaseStrategy] = {}
        self._prime(settings)

    def _prime(self, settings: Iterable[StrategySettings]) -> None:
        for config in settings:
            strategy_cls = STRATEGY_REGISTRY[config.strategy_type]
            key = (config.symbol, config.timeframe.value, config.strategy_type)
            self._strategies[key] = strategy_cls(
                symbol=config.symbol,
                timeframe=config.timeframe,
                context=self.context,
                parameters=config.parameters,
            )

    def refresh_context(self, context: StrategyContext) -> None:
        self.context = context
        for strategy in self._strategies.values():
            strategy.update_context(context)

    def generate_signals(self, bars: int = 500) -> List[StrategySignal]:
        data_cache: Dict[Tuple[str, str], MarketDataSlice] = {}
        signals: List[StrategySignal] = []

        for (symbol, timeframe_value, strategy_type), strategy in self._strategies.items():
            cache_key = (symbol, timeframe_value)
            if cache_key not in data_cache:
                market_data = self.data_provider.fetch(
                    symbol=symbol,
                    timeframe=strategy.timeframe,
                    bars=bars,
                )
                data_cache[cache_key] = market_data
            else:
                market_data = data_cache[cache_key]

            signal = strategy.generate_signal(market_data)
            if signal.direction != SignalDirection.FLAT:
                signals.append(signal)

        return signals


@dataclass
class MultiTimeframeSignalGenerator:
    """
    High-level façade that builds and runs a StrategyEngine from an EngineConfig.
    """

    engine_config: EngineConfig
    data_provider: MarketDataProvider
    context: StrategyContext

    def run(self, bars: int = 500) -> List[StrategySignal]:
        settings = self.engine_config.build_matrix()
        engine = StrategyEngine(
            data_provider=self.data_provider,
            context=self.context,
            settings=settings,
        )
        return engine.generate_signals(bars=bars)


__all__ = ["StrategyEngine", "MultiTimeframeSignalGenerator", "STRATEGY_REGISTRY"]

