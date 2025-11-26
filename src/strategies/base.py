"""
Base classes and utilities shared by all concrete strategies.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Dict, Optional

from core.enums import SignalDirection, SignalStrength, StrategyType, Timeframe
from core.types import MarketDataSlice, StrategyContext, StrategySignal, TradePlan


class BaseStrategy(ABC):
    """Contracts shared by every strategy implementation."""

    strategy_type: StrategyType

    def __init__(
        self,
        symbol: str,
        timeframe: Timeframe,
        context: StrategyContext,
        parameters: Optional[Dict[str, float]] = None,
    ):
        self.symbol = symbol
        self.timeframe = timeframe
        self.context = context
        self.parameters = parameters or {}
        self.min_confidence = self.parameters.get("min_confidence", 0.55)

    def update_context(self, context: StrategyContext) -> None:
        self.context = context

    @abstractmethod
    def generate_signal(self, market_data: MarketDataSlice) -> StrategySignal:
        """Generate a structured signal with entry/exit levels."""

    def _build_trade_plan(
        self,
        direction: SignalDirection,
        entry_price: float,
        stop_loss: float,
        take_profit: float,
    ) -> TradePlan:
        position_size = self._position_size(entry_price, stop_loss)
        return TradePlan(
            entry_price=entry_price,
            stop_loss=stop_loss,
            take_profit=take_profit,
            position_size=position_size,
        )

    def _position_size(self, entry_price: float, stop_loss: float) -> float:
        risk_amount = (
            self.context.account_balance
            * min(self.context.max_risk_per_trade, self.parameters.get("risk_per_trade", 0.01))
        )
        risk_per_unit = abs(entry_price - stop_loss)
        if risk_per_unit <= 0:
            return 0.0
        return max(risk_amount / risk_per_unit, 0.0)

    def _flat_signal(self) -> StrategySignal:
        return StrategySignal(
            strategy_type=self.strategy_type,
            symbol=self.symbol,
            timeframe=self.timeframe,
            direction=SignalDirection.FLAT,
            confidence=0.0,
            strength=SignalStrength.LOW,
            trade_plan=None,
            metadata={},
        )


__all__ = ["BaseStrategy"]

