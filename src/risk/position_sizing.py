"""Position sizing utilities for the MT5 bot."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .config import PositionSizingConfig
from .exceptions import PositionSizingError


@dataclass
class SizeBreakdown:
    """Return object containing details about the sizing decision."""

    lots: float
    risk_amount: float
    risk_fraction: float
    notional: float


class PositionSizer:
    """Calculates optimal position sizes based on configured risk."""

    def __init__(self, config: PositionSizingConfig):
        config.validate()
        self.config = config

    def size_from_stop(
        self,
        equity: float,
        entry_price: float,
        stop_price: float,
        pip_value: float,
        contract_size: Optional[float] = None,
    ) -> SizeBreakdown:
        """Size a position so that stop-out risk stays within limits."""

        if entry_price <= 0 or stop_price <= 0:
            raise PositionSizingError("Entry and stop prices must be positive")
        if pip_value <= 0:
            raise PositionSizingError("Pip value must be positive")

        distance = abs(entry_price - stop_price)
        if distance <= 0:
            raise PositionSizingError("Stop must be different from entry")

        risk_fraction = min(self.config.risk_per_trade, self.config.max_position_risk)
        risk_amount = equity * risk_fraction
        raw_lots = risk_amount / (distance * pip_value)
        lots = self._normalize_lot(raw_lots)
        notional = (contract_size or self.config.contract_size) * lots

        if lots <= 0:
            raise PositionSizingError(
                "Configured risk produces zero lot size. Increase risk or widen stop."
            )

        actual_risk = lots * distance * pip_value
        return SizeBreakdown(
            lots=lots,
            risk_amount=actual_risk,
            risk_fraction=actual_risk / equity,
            notional=notional,
        )

    def size_from_volatility(
        self,
        equity: float,
        volatility: float,
        volatility_r_multiple: float = 1.0,
        contract_size: Optional[float] = None,
    ) -> SizeBreakdown:
        """Size using volatility (e.g. ATR) instead of explicit stop."""

        if volatility <= 0:
            raise PositionSizingError("Volatility must be positive")

        pseudo_stop_distance = volatility * volatility_r_multiple
        risk_fraction = min(self.config.risk_per_trade, self.config.max_position_risk)
        risk_amount = equity * risk_fraction
        raw_lots = risk_amount / pseudo_stop_distance
        lots = self._normalize_lot(raw_lots)
        notional = (contract_size or self.config.contract_size) * lots

        if lots <= 0:
            raise PositionSizingError("Unable to open position within volatility-based risk")

        actual_risk = lots * pseudo_stop_distance
        return SizeBreakdown(
            lots=lots,
            risk_amount=actual_risk,
            risk_fraction=actual_risk / equity,
            notional=notional,
        )

    def _normalize_lot(self, lots: float) -> float:
        """Round lots to comply with broker constraints."""

        lots = max(lots, self.config.min_lot)
        lots = min(lots, self.config.max_lot)
        if self.config.allow_fractional:
            steps = round(lots / self.config.lot_step)
            return round(steps * self.config.lot_step, 5)
        return round(lots)
