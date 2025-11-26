from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional


class TradeDirection(str, Enum):
    """Represents the direction bias of a signal."""

    LONG = "long"
    SHORT = "short"
    FLAT = "flat"


class TradeAction(str, Enum):
    """Concrete trade decision produced by a strategy."""

    ENTER_LONG = "enter_long"
    ENTER_SHORT = "enter_short"
    HOLD = "hold"
    EXIT = "exit"


@dataclass(slots=True)
class MarketDataPoint:
    symbol: str
    timeframe: str
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float


@dataclass(slots=True)
class Signal:
    symbol: str
    timeframe: str
    direction: TradeDirection
    strength: float
    confidence: float
    reason: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class StrategyRecommendation:
    action: TradeAction
    signal: Signal
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    position_size: Optional[float] = None


@dataclass(slots=True)
class StrategyConfig:
    name: str
    symbols: tuple[str, ...]
    timeframes: tuple[str, ...]
    risk_per_trade: float = 0.01
    params: Dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class StrategyContext:
    config: StrategyConfig
    equity: float
    volatility: Optional[float] = None
    open_positions: Dict[str, Any] = field(default_factory=dict)
