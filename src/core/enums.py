"""
Shared enumerations for strategies, order routing, and signal semantics.
"""

from __future__ import annotations

from enum import Enum


class SignalDirection(str, Enum):
    """Directional bias of a strategy signal."""

    LONG = "long"
    SHORT = "short"
    FLAT = "flat"


class StrategyType(str, Enum):
    """High-level strategy classification."""

    TREND_FOLLOWING = "trend_following"
    MEAN_REVERSION = "mean_reversion"
    BREAKOUT = "breakout"
    NEURAL_NETWORK = "neural_network"


class SignalStrength(str, Enum):
    """Confidence bucket attached to a signal."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class OrderType(str, Enum):
    """Supported order execution types."""

    MARKET = "market"
    LIMIT = "limit"
    STOP = "stop"


class Timeframe(str, Enum):
    """Supported MT5 timeframes."""

    M1 = "M1"
    M5 = "M5"
    M15 = "M15"
    M30 = "M30"
    H1 = "H1"
    H4 = "H4"
    D1 = "D1"
    W1 = "W1"


__all__ = [
    "SignalDirection",
    "StrategyType",
    "SignalStrength",
    "OrderType",
    "Timeframe",
]

