"""
Momentum / trend-following strategy built around MA crossovers and ATR exits.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, Optional

from core.enums import SignalDirection, SignalStrength, StrategyType
from core.types import MarketDataSlice, StrategySignal
from indicators.technicals import atr, ema

from .base import BaseStrategy


@dataclass(slots=True)
class TrendFollowingParameters:
    fast_period: int = 20
    slow_period: int = 50
    atr_period: int = 14
    atr_multiplier: float = 2.0
    reward_to_risk: float = 2.0


class TrendFollowingStrategy(BaseStrategy):
    strategy_type = StrategyType.TREND_FOLLOWING

    def __init__(
        self,
        symbol: str,
        timeframe,
        context,
        parameters: Optional[Dict[str, float]] = None,
    ):
        super().__init__(symbol, timeframe, context, parameters)
        default_params = asdict(TrendFollowingParameters())
        default_params.update(parameters or {})
        self.params = TrendFollowingParameters(**default_params)

    def generate_signal(self, market_data: MarketDataSlice) -> StrategySignal:
        closes = market_data.closes()
        highs = market_data.highs()
        lows = market_data.lows()

        if len(closes) < max(self.params.slow_period, self.params.atr_period) + 2:
            return self._flat_signal()

        fast = ema(closes, self.params.fast_period)
        slow = ema(closes, self.params.slow_period)
        atr_values = atr(highs, lows, closes, self.params.atr_period)

        if any(series[-1] is None for series in (fast, slow, atr_values)):
            return self._flat_signal()

        bullish = fast[-1] > slow[-1] and fast[-2] <= slow[-2]
        bearish = fast[-1] < slow[-1] and fast[-2] >= slow[-2]

        last_close = closes[-1]
        last_atr = atr_values[-1] or 0.0
        direction = SignalDirection.FLAT
        confidence = 0.0

        if bullish:
            direction = SignalDirection.LONG
            confidence = min(1.0, abs(fast[-1] - slow[-1]) / last_atr)
            stop_loss = last_close - last_atr * self.params.atr_multiplier
            take_profit = last_close + (last_close - stop_loss) * self.params.reward_to_risk
        elif bearish:
            direction = SignalDirection.SHORT
            confidence = min(1.0, abs(fast[-1] - slow[-1]) / last_atr)
            stop_loss = last_close + last_atr * self.params.atr_multiplier
            take_profit = last_close - (stop_loss - last_close) * self.params.reward_to_risk
        else:
            return self._flat_signal()

        trade_plan = self._build_trade_plan(direction, last_close, stop_loss, take_profit)
        strength = (
            SignalStrength.HIGH if confidence > 0.75 else SignalStrength.MEDIUM if confidence > 0.55 else SignalStrength.LOW
        )

        return StrategySignal(
            strategy_type=self.strategy_type,
            symbol=self.symbol,
            timeframe=self.timeframe,
            direction=direction,
            confidence=confidence,
            strength=strength,
            trade_plan=trade_plan,
            metadata={
                "fast_ema": fast[-1],
                "slow_ema": slow[-1],
                "atr": last_atr,
            },
        )


__all__ = ["TrendFollowingStrategy"]

