from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, List, Sequence

from .strategy import BaseStrategy
from .types import MarketDataPoint, StrategyContext, StrategyRecommendation


@dataclass(slots=True)
class EngineResult:
    strategy: str
    recommendations: List[StrategyRecommendation]


class StrategyEngine:
    """Coordinates multiple strategies across symbols and timeframes."""

    def __init__(self, strategies: Iterable[BaseStrategy]):
        self._strategies: Dict[str, BaseStrategy] = {s.name: s for s in strategies}

    def upsert_strategy(self, strategy: BaseStrategy) -> None:
        self._strategies[strategy.name] = strategy

    def remove_strategy(self, name: str) -> None:
        self._strategies.pop(name, None)

    @property
    def strategies(self) -> Dict[str, BaseStrategy]:
        return dict(self._strategies)

    def run(
        self,
        market_data: Sequence[MarketDataPoint],
        contexts: Dict[str, StrategyContext],
    ) -> List[EngineResult]:
        results: List[EngineResult] = []
        for name, strategy in self._strategies.items():
            context = contexts.get(name)
            if not context:
                continue

            filtered = [
                candle
                for candle in market_data
                if candle.symbol in context.config.symbols
                and candle.timeframe in context.config.timeframes
            ]
            filtered.sort(key=lambda c: c.timestamp)
            if len(filtered) < strategy.required_history:
                continue

            recommendations = strategy.generate_signals(filtered, context)
            results.append(EngineResult(strategy=name, recommendations=recommendations))

        return results
