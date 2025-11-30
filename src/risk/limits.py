from __future__ import annotations

from dataclasses import dataclass, field
from datetime import time
from typing import Mapping

from core.types import AccountState, OrderRequest

EXPOSURE_PER_LOT = 100_000


@dataclass(slots=True)
class SymbolRiskLimit:
    """Per-symbol guard rails."""

    max_volume: float
    min_volume: float
    max_exposure: float
    max_slippage: float
    require_stop_loss: bool = True
    allowed_sides: set[str] = field(default_factory=lambda: {"buy", "sell"})

    def validate(self, order: OrderRequest) -> list[str]:
        errors: list[str] = []
        if order.symbol is None:
            errors.append("symbol-missing")
            return errors
        if order.side not in self.allowed_sides:
            errors.append("side-not-allowed")
        if order.volume < self.min_volume:
            errors.append("volume-too-low")
        if order.volume > self.max_volume:
            errors.append("volume-too-high")
        if self.require_stop_loss and order.stop_loss is None:
            errors.append("missing-stop-loss")
        exposure = order.volume * order.price * EXPOSURE_PER_LOT
        if exposure > self.max_exposure:
            errors.append("exposure-too-high")
        return errors


@dataclass(slots=True)
class RiskLimits:
    """Holistic set of safety constraints."""

    per_trade_risk: float  # expressed as fraction of equity (e.g. 0.01)
    max_daily_drawdown: float  # absolute currency loss tolerated per day
    max_total_drawdown: float  # absolute currency loss tolerated overall
    max_concurrent_positions: int
    max_trades_per_day: int
    max_account_leverage: float
    min_equity_buffer: float
    trading_window_utc: tuple[time, time]
    symbol_limits: Mapping[str, SymbolRiskLimit]

    def allowed_symbols(self) -> set[str]:
        return set(self.symbol_limits.keys())

    def validate_order(self, order: OrderRequest, account: AccountState) -> list[str]:
        errors: list[str] = []
        symbol_limit = self.symbol_limits.get(order.symbol)
        if symbol_limit is None:
            errors.append("symbol-not-allowed")
            return errors
        errors.extend(symbol_limit.validate(order))

        if account.trades_today >= self.max_trades_per_day:
            errors.append("daily-trade-limit")
        if len(account.open_positions) >= self.max_concurrent_positions:
            errors.append("max-positions")

        if order.stop_loss is not None:
            potential_loss = abs(order.price - order.stop_loss) * order.volume * EXPOSURE_PER_LOT
        else:
            potential_loss = float("inf")
        max_allowed_loss = account.equity * self.per_trade_risk
        if potential_loss > max_allowed_loss:
            errors.append("per-trade-risk")

        equity_buffer = account.equity - account.margin_used
        if equity_buffer < self.min_equity_buffer:
            errors.append("equity-buffer-breached")

        leverage = 0 if account.margin_available == 0 else (account.equity / max(account.margin_available, 1e-9))
        if leverage > self.max_account_leverage:
            errors.append("max-leverage")
        return errors

    def validate_account(self, account: AccountState) -> list[str]:
        errors: list[str] = []
        if account.daily_pl <= -self.max_daily_drawdown:
            errors.append("daily-drawdown")
        if account.total_pl <= -self.max_total_drawdown:
            errors.append("total-drawdown")
        if account.balance <= 0 or account.equity <= 0:
            errors.append("negative-equity")
        return errors


def default_limits() -> RiskLimits:
    return RiskLimits(
        per_trade_risk=0.01,
        max_daily_drawdown=1000.0,
        max_total_drawdown=5000.0,
        max_concurrent_positions=5,
        max_trades_per_day=20,
        max_account_leverage=5.0,
        min_equity_buffer=250.0,
        trading_window_utc=(time(0, 0), time(23, 59)),
        symbol_limits={
            "EURUSD": SymbolRiskLimit(max_volume=5.0, min_volume=0.01, max_exposure=100000, max_slippage=1.0),
            "GBPUSD": SymbolRiskLimit(max_volume=3.0, min_volume=0.01, max_exposure=60000, max_slippage=1.0),
        },
    )


__all__ = ["SymbolRiskLimit", "RiskLimits", "default_limits"]
