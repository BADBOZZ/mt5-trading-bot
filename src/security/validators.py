from __future__ import annotations

from datetime import time

from core.types import AccountState, OrderRequest
from risk.limits import RiskLimits


def _is_within_trading_window(timestamp, window: tuple[time, time]) -> bool:
    start, end = window
    t = timestamp.time()
    if start <= end:
        return start <= t <= end
    # Window spans midnight
    return t >= start or t <= end


def validate_order_request(order: OrderRequest, account: AccountState, limits: RiskLimits) -> list[str]:
    errors = []
    if not _is_within_trading_window(order.timestamp, limits.trading_window_utc):
        errors.append("outside-trading-window")

    errors.extend(limits.validate_order(order, account))
    return errors


def validate_account_health(account: AccountState, limits: RiskLimits) -> list[str]:
    return limits.validate_account(account)


__all__ = ["validate_order_request", "validate_account_health"]
