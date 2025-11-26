from __future__ import annotations

from core.types import StrategyConfig
from signals.generators import GeneratorConfig, MeanReversionSignalGenerator

from .base import SignalStrategy


class MeanReversionStrategy(SignalStrategy):
    """Reverts price extremes back toward the mean using Bollinger Bands."""

    def __init__(self, config: StrategyConfig):
        params = config.params
        generator_config = GeneratorConfig(
            bollinger_period=params.get("bollinger_period", 20),
            bollinger_std=params.get("bollinger_std", 2.0),
        )
        super().__init__(
            config=config,
            generator=MeanReversionSignalGenerator(generator_config),
            atr_period=params.get("atr_period", 14),
            reward_to_risk=params.get("reward_to_risk", 1.5),
        )
