from __future__ import annotations

from dataclasses import replace
from typing import List, Sequence

from core.strategy import BaseStrategy
from core.types import (
    MarketDataPoint,
    Signal,
    StrategyContext,
    StrategyRecommendation,
    TradeAction,
    TradeDirection,
)
from signals.generators import SignalGenerator
from signals import technicals


class SignalStrategy(BaseStrategy):
    """Base strategy that converts generator signals into trade actions."""

    def __init__(
        self,
        config,
        generator: SignalGenerator,
        atr_period: int = 14,
        reward_to_risk: float = 2.0,
    ):
        super().__init__(config)
        self.generator = generator
        self.atr_period = atr_period
        self.reward_to_risk = reward_to_risk

    @property
    def required_history(self) -> int:  # type: ignore[override]
        return max(200, self.atr_period * 5)

    def generate_signals(
        self,
        market_data: Sequence[MarketDataPoint],
        context: StrategyContext,
    ) -> List[StrategyRecommendation]:
        grouped: dict[tuple[str, str], list[MarketDataPoint]] = {}
        for candle in market_data:
            if candle.symbol not in context.config.symbols:
                continue
            if candle.timeframe not in context.config.timeframes:
                continue
            key = (candle.symbol, candle.timeframe)
            grouped.setdefault(key, []).append(candle)
        recommendations: List[StrategyRecommendation] = []
        for symbol in context.config.symbols:
            for timeframe in context.config.timeframes:
                bucket = grouped.get((symbol, timeframe))
                if not bucket or len(bucket) < self.required_history:
                    continue
                bucket.sort(key=lambda c: c.timestamp)
                signal = self.generator.generate(bucket)
                if not signal:
                    continue
                atr_value = self._atr(bucket)
                recommendations.append(self._build_recommendation(signal, atr_value, context))
        return recommendations

    def _atr(self, candles: Sequence[MarketDataPoint]) -> float | None:
        highs = [c.high for c in candles]
        lows = [c.low for c in candles]
        closes = [c.close for c in candles]
        atr_values = technicals.average_true_range(highs, lows, closes, self.atr_period)
        return atr_values[-1] if atr_values else None

    def _build_recommendation(
        self,
        signal: Signal,
        atr_value: float | None,
        context: StrategyContext,
    ) -> StrategyRecommendation:
        latest_price = signal.metadata.get("price") or signal.metadata.get("close")
        if latest_price is None:
            latest_price = signal.metadata.get("donchian_upper") or signal.metadata.get("donchian_lower")
        if latest_price is None:
            latest_price = signal.metadata.get("fast") or signal.metadata.get("mid")
        if latest_price is None:
            latest_price = signal.metadata.get("recent_price")
        if latest_price is None:
            latest_price = context.open_positions.get(signal.symbol, {}).get("last_price")
        if latest_price in (None, 0):
            # fallback to neutral price to avoid division errors
            latest_price = 1.0

        atr = atr_value or max(0.0001, latest_price * 0.001)
        risk_per_trade = context.config.risk_per_trade
        risk_capital = context.equity * risk_per_trade
        position_size = max(0.01, risk_capital / atr)

        if signal.direction == TradeDirection.LONG:
            action = TradeAction.ENTER_LONG
            stop_loss = latest_price - atr * 1.5
            take_profit = latest_price + atr * self.reward_to_risk
        elif signal.direction == TradeDirection.SHORT:
            action = TradeAction.ENTER_SHORT
            stop_loss = latest_price + atr * 1.5
            take_profit = latest_price - atr * self.reward_to_risk
        else:
            action = TradeAction.HOLD
            stop_loss = None
            take_profit = None

        enriched_signal = replace(signal, metadata={**signal.metadata, "atr": atr})
        return StrategyRecommendation(
            action=action,
            signal=enriched_signal,
            stop_loss=stop_loss,
            take_profit=take_profit,
            position_size=position_size,
        )
