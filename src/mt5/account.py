"""Account level helpers for MT5."""

from __future__ import annotations

import logging
from dataclasses import dataclass

from .connection import MT5ConnectionManager
from .exceptions import MT5AccountError

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class AccountSummary:
    login: int
    name: str
    leverage: int
    balance: float
    equity: float
    margin: float
    margin_free: float
    margin_level: float
    currency: str


class MT5AccountManager:
    def __init__(self, connection: MT5ConnectionManager):
        self.connection = connection

    def _info(self):
        self.connection.ensure_connected()
        info = self.connection.api.account_info()
        if info is None:
            raise MT5AccountError("Unable to fetch MT5 account info")
        logger.debug("Fetched account info for login %s", info.login)
        return info

    def summary(self) -> AccountSummary:
        info = self._info()
        return AccountSummary(
            login=info.login,
            name=info.name,
            leverage=info.leverage,
            balance=info.balance,
            equity=info.equity,
            margin=info.margin,
            margin_free=info.margin_free,
            margin_level=info.margin_level,
            currency=info.currency,
        )

    def check_margin_level(self, min_level: float = 100.0) -> bool:
        info = self._info()
        if info.margin_level <= 0:
            raise MT5AccountError("Margin level is zero or negative")
        meets_requirement = info.margin_level >= min_level
        logger.debug("Margin level %.2f%% compared to minimum %.2f%%", info.margin_level, min_level)
        return meets_requirement

    def verify_login(self) -> bool:
        info = self._info()
        matches = info.login == self.connection.config.login
        if not matches:
            logger.warning("Connected login %s does not match expected %s", info.login, self.connection.config.login)
        return matches

    def exposure_by_symbol(self, symbol: str) -> float:
        self.connection.ensure_connected()
        positions = self.connection.api.positions_get(symbol=symbol)
        if not positions:
            return 0.0
        return sum(pos.volume for pos in positions)

    def equity_buffer_ok(self, min_equity: float) -> bool:
        info = self._info()
        meets = info.equity >= min_equity
        logger.debug("Equity %.2f vs min %.2f", info.equity, min_equity)
        return meets

    def ensure_margin_and_equity(self, *, min_level: float, min_equity: float) -> None:
        if not self.check_margin_level(min_level):
            raise MT5AccountError(
                f"Margin level below required threshold ({min_level})"
            )
        if not self.equity_buffer_ok(min_equity):
            raise MT5AccountError(
                f"Equity below required buffer ({min_equity})"
            )
