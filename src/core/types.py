"""
Shared dataclasses used across the trading bot.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional

from .enums import OrderType, SignalDirection, SignalStrength, StrategyType, Timeframe


@dataclass(slots=True)
class OHLCVBar:
    """Single bar of market data."""

    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float = 0.0


@dataclass(slots=True)
class MarketDataSlice:
    """Collection of chronological bars for a symbol/timeframe pair."""

    symbol: str
    timeframe: Timeframe
    bars: List[OHLCVBar]

    def closes(self) -> List[float]:
        return [bar.close for bar in self.bars]

    def highs(self) -> List[float]:
        return [bar.high for bar in self.bars]

    def lows(self) -> List[float]:
        return [bar.low for bar in self.bars]


@dataclass(slots=True)
class TradePlan:
    """Executable instruction for entering or exiting a trade."""

    entry_price: float
    stop_loss: float
    take_profit: float
    order_type: OrderType = OrderType.MARKET
    position_size: float = 0.0


@dataclass(slots=True)
class StrategySignal:
    """Signal emitted by a strategy-specific signal generator."""

    strategy_type: StrategyType
    symbol: str
    timeframe: Timeframe
    direction: SignalDirection
    confidence: float
    strength: SignalStrength
    trade_plan: Optional[TradePlan] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class StrategyContext:
    """Runtime context shared with strategies."""

    account_balance: float
    max_risk_per_trade: float
    volatility_factor: float = 1.0
    extra: Dict[str, Any] = field(default_factory=dict)


__all__ = [
    "OHLCVBar",
    "MarketDataSlice",
    "TradePlan",
    "StrategySignal",
    "StrategyContext",
]

