"""
Lightweight neural-network-inspired strategy using engineered features.
"""

from __future__ import annotations

import math
from dataclasses import asdict, dataclass
from statistics import pstdev
from typing import Dict, Optional, Sequence

from core.enums import SignalDirection, SignalStrength, StrategyType
from core.types import MarketDataSlice, StrategySignal
from indicators.technicals import atr, bollinger_bands, ema, rsi

from .base import BaseStrategy


@dataclass(slots=True)
class NeuralNetworkParameters:
    lookback: int = 50
    threshold_high: float = 0.6
    threshold_low: float = 0.4
    atr_period: int = 14
    atr_multiplier: float = 1.8
    reward_to_risk: float = 2.2
    weights: Sequence[float] = (0.8, -0.6, 0.4, 0.3, -0.2)


def _sigmoid(value: float) -> float:
    return 1 / (1 + math.exp(-value))


class NeuralNetworkStrategy(BaseStrategy):
    strategy_type = StrategyType.NEURAL_NETWORK

    def __init__(
        self,
        symbol: str,
        timeframe,
        context,
        parameters: Optional[Dict[str, float]] = None,
    ):
        super().__init__(symbol, timeframe, context, parameters)
        default_params = asdict(NeuralNetworkParameters())
        default_params.update(parameters or {})
        self.params = NeuralNetworkParameters(**default_params)

    def generate_signal(self, market_data: MarketDataSlice) -> StrategySignal:
        closes = market_data.closes()
        highs = market_data.highs()
        lows = market_data.lows()

        if len(closes) < self.params.lookback + 5:
            return self._flat_signal()

        lookback_window = closes[-self.params.lookback :]
        returns = [
            (lookback_window[idx] - lookback_window[idx - 1]) / lookback_window[idx - 1]
            for idx in range(1, len(lookback_window))
        ]
        momentum = (lookback_window[-1] - lookback_window[0]) / lookback_window[0]
        volatility = pstdev(returns) if len(returns) > 1 else 0.0

        ema_short = ema(closes, 12)[-1]
        ema_long = ema(closes, 26)[-1]
        rsi_value = rsi(closes, 14)[-1]
        bands = bollinger_bands(closes, 20, 2.0)[-1]
        atr_value = atr(highs, lows, closes, self.params.atr_period)[-1]

        if None in (ema_short, ema_long, rsi_value, bands[0], bands[1], bands[2], atr_value):
            return self._flat_signal()

        bb_middle, bb_upper, bb_lower = bands
        price_position = (closes[-1] - bb_lower) / max(bb_upper - bb_lower, 1e-6)

        features = [
            momentum,
            volatility,
            (ema_short - ema_long) / closes[-1],
            (rsi_value - 50) / 50,
            price_position - 0.5,
        ]

        weights = list(self.params.weights)
        if len(weights) != len(features):
            raise ValueError("weights length must match engineered feature vector")

        weighted_sum = sum(w * f for w, f in zip(weights, features))
        probability = _sigmoid(weighted_sum)

        direction = SignalDirection.FLAT
        if probability >= self.params.threshold_high:
            direction = SignalDirection.LONG
        elif probability <= self.params.threshold_low:
            direction = SignalDirection.SHORT
        else:
            return self._flat_signal()

        last_close = closes[-1]
        if direction == SignalDirection.LONG:
            stop_loss = last_close - atr_value * self.params.atr_multiplier
            take_profit = last_close + (last_close - stop_loss) * self.params.reward_to_risk
        else:
            stop_loss = last_close + atr_value * self.params.atr_multiplier
            take_profit = last_close - (stop_loss - last_close) * self.params.reward_to_risk

        confidence = probability if direction == SignalDirection.LONG else 1 - probability
        strength = (
            SignalStrength.HIGH if confidence > 0.75 else SignalStrength.MEDIUM if confidence > 0.55 else SignalStrength.LOW
        )

        trade_plan = self._build_trade_plan(direction, last_close, stop_loss, take_profit)

        return StrategySignal(
            strategy_type=self.strategy_type,
            symbol=self.symbol,
            timeframe=self.timeframe,
            direction=direction,
            confidence=confidence,
            strength=strength,
            trade_plan=trade_plan,
            metadata={
                "probability": probability,
                "features": features,
                "weights": weights,
                "atr": atr_value,
            },
        )


__all__ = ["NeuralNetworkStrategy"]

