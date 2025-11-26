from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from math import exp
from random import Random
from typing import Optional, Sequence

from core.types import MarketDataPoint, Signal, TradeDirection
from . import technicals


@dataclass(slots=True)
class GeneratorConfig:
    fast_period: int = 10
    slow_period: int = 40
    rsi_period: int = 14
    bollinger_period: int = 20
    bollinger_std: float = 2.0
    breakout_period: int = 55
    atr_period: int = 14
    min_confidence: float = 0.55


class SignalGenerator(ABC):
    def __init__(self, config: GeneratorConfig | None = None):
        self.config = config or GeneratorConfig()

    @abstractmethod
    def generate(self, candles: Sequence[MarketDataPoint]) -> Optional[Signal]:
        """Return the latest trading signal for the supplied candles."""

    def _closing_prices(self, candles: Sequence[MarketDataPoint]) -> list[float]:
        return [candle.close for candle in candles]


class TrendFollowingSignalGenerator(SignalGenerator):
    def generate(self, candles: Sequence[MarketDataPoint]) -> Optional[Signal]:
        closes = self._closing_prices(candles)
        fast = technicals.exponential_moving_average(closes, self.config.fast_period)
        slow = technicals.exponential_moving_average(closes, self.config.slow_period)
        rsi = technicals.relative_strength_index(closes, self.config.rsi_period)
        if not fast or not slow or not rsi:
            return None
        if len(fast) == 0 or len(slow) == 0:
            return None
        direction = None
        if fast[-1] > slow[-1] and rsi[-1] > 55:
            direction = TradeDirection.LONG
        elif fast[-1] < slow[-1] and rsi[-1] < 45:
            direction = TradeDirection.SHORT
        if not direction:
            return None
        strength = abs(fast[-1] - slow[-1]) / slow[-1]
        confidence = min(0.99, max(0.0, strength * 10))
        latest = candles[-1]
        return Signal(
            symbol=latest.symbol,
            timeframe=latest.timeframe,
            direction=direction,
            strength=strength,
            confidence=confidence,
            reason="trend-following crossover",
            metadata={
                "fast": fast[-1],
                "slow": slow[-1],
                "rsi": rsi[-1],
                "price": latest.close,
            },
        )


class MeanReversionSignalGenerator(SignalGenerator):
    def generate(self, candles: Sequence[MarketDataPoint]) -> Optional[Signal]:
        closes = self._closing_prices(candles)
        upper, mid, lower = technicals.bollinger_bands(
            closes, self.config.bollinger_period, self.config.bollinger_std
        )
        if not upper:
            return None
        price = closes[-1]
        latest = candles[-1]
        if price < lower[-1]:
            direction = TradeDirection.LONG
            deviation = (lower[-1] - price) / lower[-1]
        elif price > upper[-1]:
            direction = TradeDirection.SHORT
            deviation = (price - upper[-1]) / upper[-1]
        else:
            return None
        confidence = min(0.99, max(0.0, deviation * 12))
        return Signal(
            symbol=latest.symbol,
            timeframe=latest.timeframe,
            direction=direction,
            strength=deviation,
            confidence=confidence,
            reason="bollinger reversion",
            metadata={"upper": upper[-1], "lower": lower[-1], "price": price},
        )


class BreakoutSignalGenerator(SignalGenerator):
    def generate(self, candles: Sequence[MarketDataPoint]) -> Optional[Signal]:
        highs = [c.high for c in candles]
        lows = [c.low for c in candles]
        closes = [c.close for c in candles]
        upper, lower = technicals.donchian_channels(highs, lows, self.config.breakout_period)
        atr = technicals.average_true_range(highs, lows, closes, self.config.atr_period)
        if not upper or not atr:
            return None
        price = closes[-1]
        latest = candles[-1]
        if price > upper[-1]:
            direction = TradeDirection.LONG
            breakout_strength = (price - upper[-1]) / upper[-1]
        elif price < lower[-1]:
            direction = TradeDirection.SHORT
            breakout_strength = (lower[-1] - price) / lower[-1]
        else:
            return None
        atr_value = atr[-1]
        confidence = min(0.99, breakout_strength * 8 + min(0.5, atr_value / price))
        return Signal(
            symbol=latest.symbol,
            timeframe=latest.timeframe,
            direction=direction,
            strength=breakout_strength,
            confidence=confidence,
            reason="price breakout",
            metadata={
                "donchian_upper": upper[-1],
                "donchian_lower": lower[-1],
                "atr": atr_value,
                "price": price,
            },
        )


class SimpleFeedForward:
    def __init__(self, input_dim: int, hidden_dim: int = 8, seed: int = 7):
        rng = Random(seed)
        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.w1 = [[rng.uniform(-0.5, 0.5) for _ in range(input_dim)] for _ in range(hidden_dim)]
        self.b1 = [0.0 for _ in range(hidden_dim)]
        self.w2 = [rng.uniform(-0.5, 0.5) for _ in range(hidden_dim)]
        self.b2 = 0.0

    def _relu(self, value: float) -> float:
        return max(0.0, value)

    def _sigmoid(self, value: float) -> float:
        return 1 / (1 + exp(-value))

    def predict(self, features: Sequence[float]) -> float:
        hidden = []
        for node in range(self.hidden_dim):
            weighted = sum(w * f for w, f in zip(self.w1[node], features)) + self.b1[node]
            hidden.append(self._relu(weighted))
        output = sum(w * h for w, h in zip(self.w2, hidden)) + self.b2
        return self._sigmoid(output)


class NeuralNetworkSignalGenerator(SignalGenerator):
    def __init__(self, config: GeneratorConfig | None = None, lookback: int = 50):
        super().__init__(config)
        self.lookback = lookback
        self.model = SimpleFeedForward(input_dim=lookback)

    def _build_features(self, closes: Sequence[float]) -> list[float]:
        window = closes[-self.lookback :]
        base = window[0]
        return [(price - base) / base for price in window]

    def generate(self, candles: Sequence[MarketDataPoint]) -> Optional[Signal]:
        if len(candles) < self.lookback:
            return None
        closes = self._closing_prices(candles)
        features = self._build_features(closes)
        probability = self.model.predict(features)
        latest = candles[-1]
        if probability > 0.6:
            direction = TradeDirection.LONG
            strength = probability - 0.5
        elif probability < 0.4:
            direction = TradeDirection.SHORT
            strength = 0.5 - probability
        else:
            return None
        confidence = max(self.config.min_confidence, min(0.99, abs(probability - 0.5) * 2))
        return Signal(
            symbol=latest.symbol,
            timeframe=latest.timeframe,
            direction=direction,
            strength=strength,
            confidence=confidence,
            reason="neural-network inference",
            metadata={"probability": probability, "price": latest.close},
        )
