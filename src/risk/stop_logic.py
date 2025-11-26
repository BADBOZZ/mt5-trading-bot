"""Stop-loss and take-profit calculation utilities."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .config import StopConfig
from .exceptions import StopLogicError


@dataclass
class StopResult:
    stop_loss: float
    take_profit: float
    risk_per_unit: float  # price distance between entry and stop


class StopManager:
    """Centralizes stop/take-profit calculations."""

    def __init__(self, config: StopConfig):
        config.validate()
        self.config = config

    def atr_based_stop(
        self,
        entry_price: float,
        direction: str,
        atr: float,
        pip_size: float = 0.0001,
    ) -> StopResult:
        """Create stops using ATR multiples while honoring min/max limits."""

        if atr <= 0 or entry_price <= 0:
            raise StopLogicError("ATR and entry price must be positive")
        raw_distance = atr * self.config.atr_multiplier
        return self._build_stop(entry_price, direction, raw_distance, pip_size)

    def fixed_stop(
        self,
        entry_price: float,
        direction: str,
        stop_distance_pips: Optional[float] = None,
        pip_size: float = 0.0001,
    ) -> StopResult:
        """Create stops from a user supplied pip distance."""

        if stop_distance_pips is None:
            stop_distance_pips = self.config.hard_stop_pips
        if stop_distance_pips is None or stop_distance_pips <= 0:
            raise StopLogicError("A positive stop_distance_pips is required")
        distance = stop_distance_pips * pip_size
        return self._build_stop(entry_price, direction, distance, pip_size)

    def trailing_trigger(
        self,
        entry_price: float,
        current_price: float,
        stop_loss: float,
        direction: str,
        pip_size: float = 0.0001,
    ) -> float:
        """Return a new stop level if trailing should move, else the same stop."""

        profit = (current_price - entry_price) if direction == "long" else (entry_price - current_price)
        risk = (entry_price - stop_loss) if direction == "long" else (stop_loss - entry_price)
        if risk <= 0:
            raise StopLogicError("Invalid risk distance for trailing stop")

        realized_r_multiple = profit / risk
        if realized_r_multiple < self.config.trailing_start_multiple:
            return stop_loss

        distance_price = self.config.trailing_distance_pips * pip_size
        if distance_price <= 0:
            raise StopLogicError("Trailing distance must be positive")

        if direction == "long":
            return max(stop_loss, current_price - distance_price)
        return min(stop_loss, current_price + distance_price)

    def _build_stop(
        self,
        entry_price: float,
        direction: str,
        distance: float,
        pip_size: float,
    ) -> StopResult:
        distance = self._clamp_distance(distance, pip_size)
        if direction not in {"long", "short"}:
            raise StopLogicError("direction must be 'long' or 'short'")

        if direction == "long":
            stop = entry_price - distance
            take_profit = entry_price + distance * self.config.take_profit_multiple
        else:
            stop = entry_price + distance
            take_profit = entry_price - distance * self.config.take_profit_multiple

        if stop <= 0 or take_profit <= 0:
            raise StopLogicError("Computed stop/take-profit must be positive")

        return StopResult(stop_loss=stop, take_profit=take_profit, risk_per_unit=distance)

    def _clamp_distance(self, distance: float, pip_size: float) -> float:
        min_distance = self.config.min_stop_pips * pip_size
        max_distance = self.config.max_stop_pips * pip_size
        return max(min(distance, max_distance), min_distance)
