"""
Configuration helpers for building multi-strategy, multi-symbol runs.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List

from .enums import StrategyType, Timeframe


@dataclass(slots=True)
class StrategySettings:
    """Serializable description of a single strategy instance."""

    strategy_type: StrategyType
    symbol: str
    timeframe: Timeframe
    parameters: Dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class EngineConfig:
    """Top-level execution configuration for the strategy engine."""

    symbols: Iterable[str]
    timeframes: Iterable[Timeframe]
    base_parameters: Dict[str, Any] = field(default_factory=dict)
    strategy_settings: List[StrategySettings] = field(default_factory=list)
    capital_allocation: float = 1.0

    def build_matrix(self) -> List[StrategySettings]:
        """
        Produce the cartesian product of configured strategy instances.

        When explicit strategy_settings are provided they are returned as-is;
        otherwise a combination of symbols/timeframes is produced with the
        base_parameters.
        """

        if self.strategy_settings:
            return self.strategy_settings

        return [
            StrategySettings(
                strategy_type=strategy_name,
                symbol=symbol,
                timeframe=timeframe,
                parameters=self.base_parameters.copy(),
            )
            for strategy_name in (
                StrategyType.TREND_FOLLOWING,
                StrategyType.MEAN_REVERSION,
                StrategyType.BREAKOUT,
                StrategyType.NEURAL_NETWORK,
            )
            for symbol in self.symbols
            for timeframe in self.timeframes
        ]


__all__ = ["StrategySettings", "EngineConfig"]

