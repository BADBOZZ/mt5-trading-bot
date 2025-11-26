from __future__ import annotations

from core.types import StrategyConfig
from signals.generators import GeneratorConfig, BreakoutSignalGenerator

from .base import SignalStrategy


class BreakoutStrategy(SignalStrategy):
    """Captures trend accelerations when price escapes consolidation ranges."""

    def __init__(self, config: StrategyConfig):
        params = config.params
        generator_config = GeneratorConfig(
            breakout_period=params.get("breakout_period", 55),
            atr_period=params.get("atr_period", 14),
        )
        super().__init__(
            config=config,
            generator=BreakoutSignalGenerator(generator_config),
            atr_period=params.get("atr_period", 14),
            reward_to_risk=params.get("reward_to_risk", 2.5),
        )
