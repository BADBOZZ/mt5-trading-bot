"""
Price breakout strategy using Donchian channels and ATR scaling.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, Optional

from core.enums import SignalDirection, SignalStrength, StrategyType
from core.types import MarketDataSlice, StrategySignal
from indicators.technicals import atr, donchian_channel

from .base import BaseStrategy


@dataclass(slots=True)
class BreakoutParameters:
    channel_period: int = 55
    atr_period: int = 21
    atr_multiplier: float = 2.5
    breakout_buffer: float = 0.0002


class BreakoutStrategy(BaseStrategy):
    strategy_type = StrategyType.BREAKOUT

    def __init__(
        self,
        symbol: str,
        timeframe,
        context,
        parameters: Optional[Dict[str, float]] = None,
    ):
        super().__init__(symbol, timeframe, context, parameters)
        default_params = asdict(BreakoutParameters())
        default_params.update(parameters or {})
        self.params = BreakoutParameters(**default_params)

    def generate_signal(self, market_data: MarketDataSlice) -> StrategySignal:
        highs = market_data.highs()
        lows = market_data.lows()
        closes = market_data.closes()

        if len(highs) < max(self.params.channel_period, self.params.atr_period) + 1:
            return self._flat_signal()

        channel = donchian_channel(highs, lows, self.params.channel_period)
        atr_values = atr(highs, lows, closes, self.params.atr_period)

        upper, lower = channel[-1]
        last_close = closes[-1]
        last_atr = atr_values[-1]

        if upper is None or lower is None or last_atr is None:
            return self._flat_signal()

        direction = SignalDirection.FLAT
        if last_close > upper + self.params.breakout_buffer:
            direction = SignalDirection.LONG
            stop_loss = last_close - last_atr * self.params.atr_multiplier
            take_profit = last_close + last_atr * self.params.atr_multiplier * 2
        elif last_close < lower - self.params.breakout_buffer:
            direction = SignalDirection.SHORT
            stop_loss = last_close + last_atr * self.params.atr_multiplier
            take_profit = last_close - last_atr * self.params.atr_multiplier * 2
        else:
            return self._flat_signal()

        confidence = min(1.0, abs(last_close - (upper if direction == SignalDirection.LONG else lower)) / last_atr)
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
                "channel_upper": upper,
                "channel_lower": lower,
                "atr": last_atr,
            },
        )


__all__ = ["BreakoutStrategy"]

