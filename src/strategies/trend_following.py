from __future__ import annotations

from core.types import StrategyConfig
from signals.generators import GeneratorConfig, TrendFollowingSignalGenerator

from .base import SignalStrategy


class TrendFollowingStrategy(SignalStrategy):
    """Momentum-based strategy leveraging moving averages and RSI confirmation."""

    def __init__(self, config: StrategyConfig):
        params = config.params
        generator_config = GeneratorConfig(
            fast_period=params.get("fast_period", 12),
            slow_period=params.get("slow_period", 48),
            rsi_period=params.get("rsi_period", 14),
        )
        super().__init__(
            config=config,
            generator=TrendFollowingSignalGenerator(generator_config),
            atr_period=params.get("atr_period", 14),
            reward_to_risk=params.get("reward_to_risk", 3.0),
        )
