from __future__ import annotations

from core.types import StrategyConfig, StrategyContext, StrategyRecommendation
from signals.generators import NeuralNetworkSignalGenerator, GeneratorConfig

from .base import SignalStrategy


class NeuralNetworkStrategy(SignalStrategy):
    """AI-driven strategy that evaluates non-linear price patterns."""

    def __init__(self, config: StrategyConfig):
        params = config.params
        generator_config = GeneratorConfig(
            min_confidence=params.get("min_confidence", 0.6),
        )
        self.lookback = params.get("lookback", 60)
        generator = NeuralNetworkSignalGenerator(
            config=generator_config,
            lookback=self.lookback,
        )
        super().__init__(
            config=config,
            generator=generator,
            atr_period=params.get("atr_period", 14),
            reward_to_risk=params.get("reward_to_risk", 2.0),
        )

    @property
    def required_history(self) -> int:  # type: ignore[override]
        return max(self.lookback + 10, super().required_history)
