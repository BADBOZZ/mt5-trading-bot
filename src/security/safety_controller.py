from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

from core.types import AccountState, OrderRequest, TradeResult
from risk.limits import RiskLimits, default_limits
from security.emergency_stop import EmergencyStop
from security.validators import validate_account_health, validate_order_request


@dataclass(slots=True)
class SafetyDecision:
    allowed: bool
    reasons: Sequence[str]


class SafetyController:
    """Central coordinator for safety, risk, and emergency stops."""

    def __init__(self, limits: RiskLimits | None = None, emergency_stop: EmergencyStop | None = None) -> None:
        self.limits = limits or default_limits()
        self.emergency_stop = emergency_stop or EmergencyStop(self.limits)

    def evaluate_order(self, order: OrderRequest, account: AccountState) -> SafetyDecision:
        reasons: list[str] = []
        if not self.emergency_stop.allows_trading(order.timestamp):
            reasons.append("emergency-stop-engaged")

        reasons.extend(validate_account_health(account, self.limits))
        reasons.extend(validate_order_request(order, account, self.limits))

        allowed = len(reasons) == 0
        if not allowed:
            self.emergency_stop.check_account(account, order.timestamp)
        return SafetyDecision(allowed=allowed, reasons=tuple(sorted(set(reasons))))

    def record_trade_outcome(self, account: AccountState, result: TradeResult) -> SafetyDecision:
        updated_account = AccountState(
            balance=account.balance + result.profit - result.loss,
            equity=account.equity + result.profit - result.loss,
            daily_pl=account.daily_pl + result.profit - result.loss,
            total_pl=account.total_pl + result.profit - result.loss,
            open_positions=account.open_positions,
            trades_today=account.trades_today,
            margin_used=account.margin_used,
            margin_available=account.margin_available,
            open_risk=max(account.open_risk - result.closed_volume, 0.0),
            last_reset=account.last_reset,
        )
        reasons = validate_account_health(updated_account, self.limits)
        reasons.extend(self.emergency_stop.check_account(updated_account, result.timestamp))
        allowed = len(reasons) == 0 and self.emergency_stop.allows_trading(result.timestamp)
        return SafetyDecision(allowed=allowed, reasons=tuple(sorted(set(reasons))))


__all__ = ["SafetyController", "SafetyDecision"]
