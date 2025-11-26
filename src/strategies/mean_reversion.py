"""
Mean-reversion strategy combining RSI extremes and Bollinger Bands.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, Optional

from core.enums import SignalDirection, SignalStrength, StrategyType
from core.types import MarketDataSlice, StrategySignal
from indicators.technicals import atr, bollinger_bands, rsi

from .base import BaseStrategy


@dataclass(slots=True)
class MeanReversionParameters:
    rsi_period: int = 14
    lower_rsi: float = 30.0
    upper_rsi: float = 70.0
    bb_period: int = 20
    bb_std: float = 2.0
    atr_period: int = 14
    atr_multiplier: float = 1.0


class MeanReversionStrategy(BaseStrategy):
    strategy_type = StrategyType.MEAN_REVERSION

    def __init__(
        self,
        symbol: str,
        timeframe,
        context,
        parameters: Optional[Dict[str, float]] = None,
    ):
        super().__init__(symbol, timeframe, context, parameters)
        default_params = asdict(MeanReversionParameters())
        default_params.update(parameters or {})
        self.params = MeanReversionParameters(**default_params)

    def generate_signal(self, market_data: MarketDataSlice) -> StrategySignal:
        closes = market_data.closes()
        highs = market_data.highs()
        lows = market_data.lows()

        if len(closes) < max(self.params.bb_period, self.params.atr_period, self.params.rsi_period) + 2:
            return self._flat_signal()

        rsi_values = rsi(closes, self.params.rsi_period)
        bands = bollinger_bands(closes, self.params.bb_period, self.params.bb_std)
        atr_values = atr(highs, lows, closes, self.params.atr_period)

        last_close = closes[-1]
        last_rsi = rsi_values[-1]
        last_band = bands[-1]
        last_atr = atr_values[-1]

        if (
            last_rsi is None
            or last_band[0] is None
            or last_band[1] is None
            or last_band[2] is None
            or last_atr is None
        ):
            return self._flat_signal()

        middle, upper, lower = last_band
        direction = SignalDirection.FLAT
        stop_loss = take_profit = last_close

        if last_rsi < self.params.lower_rsi and last_close <= lower:
            direction = SignalDirection.LONG
            stop_loss = last_close - last_atr * self.params.atr_multiplier
            take_profit = middle
        elif last_rsi > self.params.upper_rsi and last_close >= upper:
            direction = SignalDirection.SHORT
            stop_loss = last_close + last_atr * self.params.atr_multiplier
            take_profit = middle
        else:
            return self._flat_signal()

        confidence = min(1.0, abs(last_rsi - 50) / 50)
        strength = (
            SignalStrength.HIGH if confidence > 0.8 else SignalStrength.MEDIUM if confidence > 0.6 else SignalStrength.LOW
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
                "rsi": last_rsi,
                "bollinger_middle": middle,
                "bollinger_upper": upper,
                "bollinger_lower": lower,
                "atr": last_atr,
            },
        )


__all__ = ["MeanReversionStrategy"]

