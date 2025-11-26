from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

from core.types import AccountState
from risk.limits import RiskLimits


@dataclass(slots=True)
class EmergencyStopState:
    triggered: bool = False
    reason: Optional[str] = None
    triggered_at: Optional[datetime] = None


class EmergencyStop:
    """Halts trading when catastrophic risk is detected."""

    def __init__(self, limits: RiskLimits, cooldown: timedelta | None = None) -> None:
        self._limits = limits
        self._cooldown = cooldown or timedelta(minutes=30)
        self._state = EmergencyStopState()

    @property
    def state(self) -> EmergencyStopState:
        return self._state

    def trigger(self, reason: str, timestamp: datetime | None = None) -> None:
        if not self._state.triggered:
            self._state = EmergencyStopState(True, reason, timestamp or datetime.utcnow())

    def reset(self, timestamp: datetime | None = None) -> None:
        if not self._state.triggered:
            return
        if self._state.triggered_at is None:
            self._state = EmergencyStopState()
            return
        elapsed = (timestamp or datetime.utcnow()) - self._state.triggered_at
        if elapsed >= self._cooldown:
            self._state = EmergencyStopState()

    def check_account(self, account: AccountState, timestamp: datetime | None = None) -> list[str]:
        reasons: list[str] = []
        timestamp = timestamp or datetime.utcnow()
        if abs(account.daily_pl) > self._limits.max_daily_drawdown:
            reasons.append("emergency-daily-drawdown")
        if abs(account.total_pl) > self._limits.max_total_drawdown:
            reasons.append("emergency-total-drawdown")
        if account.equity <= 0:
            reasons.append("emergency-negative-equity")

        if reasons:
            self.trigger(";".join(reasons), timestamp)
        else:
            self.reset(timestamp)
        return reasons

    def allows_trading(self, timestamp: datetime | None = None) -> bool:
        if not self._state.triggered:
            return True
        if self._state.triggered_at is None:
            return False
        elapsed = (timestamp or datetime.utcnow()) - self._state.triggered_at
        return elapsed >= self._cooldown


__all__ = ["EmergencyStop", "EmergencyStopState"]
