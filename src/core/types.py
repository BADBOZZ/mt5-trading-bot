from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Literal, Sequence

OrderSide = Literal["buy", "sell"]


@dataclass(slots=True)
class Position:
    """Represents an open MT5 position."""

    symbol: str
    volume: float  # Lots
    entry_price: float
    stop_loss: float | None = None
    take_profit: float | None = None
    risk_amount: float = 0.0


@dataclass(slots=True)
class AccountState:
    """Aggregated account level metrics used for risk checks."""

    balance: float
    equity: float
    daily_pl: float
    total_pl: float
    open_positions: Sequence[Position] = field(default_factory=tuple)
    trades_today: int = 0
    margin_used: float = 0.0
    margin_available: float = 0.0
    open_risk: float = 0.0
    last_reset: datetime | None = None


@dataclass(slots=True)
class OrderRequest:
    """Incoming intent to submit a trade."""

    symbol: str
    side: OrderSide
    volume: float  # Lots
    price: float
    stop_loss: float | None
    take_profit: float | None
    timestamp: datetime
    strategy_id: str


@dataclass(slots=True)
class TradeResult:
    """Result of a trade used to update limits."""

    strategy_id: str
    profit: float
    loss: float
    closed_volume: float
    timestamp: datetime


__all__ = [
    "OrderSide",
    "Position",
    "AccountState",
    "OrderRequest",
    "TradeResult",
]
