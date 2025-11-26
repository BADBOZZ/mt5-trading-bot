"""Risk limit enforcement including drawdown and loss controls."""
from __future__ import annotations

from typing import Optional

from .config import RiskConfig
from .exceptions import DailyLossLimitError, DrawdownLimitError, ExposureLimitError
from .position_sizing import SizeBreakdown
from .state import AccountState, RiskState, TradeIntent


class RiskLimitEnforcer:
    """Ensures that new trades comply with configured risk limits."""

    def __init__(self, config: RiskConfig, state: RiskState):
        config.validate()
        self.config = config
        self.state = state

    def validate_trade(
        self,
        account: AccountState,
        trade: TradeIntent,
        sizing: SizeBreakdown,
    ) -> None:
        """Run every limit check for a prospective trade."""

        self._check_cooldown()
        self._check_drawdown(account)
        self._check_daily_loss(account)
        self._check_portfolio_limits(account, trade, sizing)

    def commit_trade(
        self,
        trade: TradeIntent,
        sizing: SizeBreakdown,
    ) -> None:
        """Persist exposure changes after an order is placed."""

        notional = sizing.notional
        signed_notional = notional if trade.direction == "long" else -notional
        self.state.adjust_exposure(
            trade.symbol,
            signed_notional,
            trade.correlation_bucket,
            asset_class=trade.asset_class,
        )

    def register_realized_pnl(self, pnl: float, timestamp) -> None:
        self.state.register_pnl(pnl, timestamp)

    # --- Individual checks -------------------------------------------------

    def _check_cooldown(self) -> None:
        if self.state.in_cooldown():
            raise DrawdownLimitError("Trading paused due to cooling-off period")

    def _check_drawdown(self, account: AccountState) -> None:
        self.state.update_equity(account.equity, account.timestamp)
        if self.state.current_drawdown >= self.config.drawdown.max_drawdown_pct:
            self.state.apply_cooldown(self.config.drawdown.cooling_off_minutes)
            raise DrawdownLimitError(
                f"Max drawdown reached: {self.state.current_drawdown:.2%}"
            )

    def _check_daily_loss(self, account: AccountState) -> None:
        reference = self.state.daily_start_equity or account.equity
        if reference <= 0:
            return

        loss_pct = self.state.daily_loss / reference
        if loss_pct >= self.config.drawdown.max_daily_loss_pct:
            self.state.apply_cooldown(self.config.drawdown.cooling_off_minutes)
            raise DailyLossLimitError(
                f"Daily loss limit reached: {loss_pct:.2%} of equity"
            )

        abs_limit = self.config.drawdown.max_daily_loss_abs
        if abs_limit and self.state.daily_loss >= abs_limit:
            self.state.apply_cooldown(self.config.drawdown.cooling_off_minutes)
            raise DailyLossLimitError(
                "Daily absolute loss limit reached"
            )

    def _check_portfolio_limits(
        self,
        account: AccountState,
        trade: TradeIntent,
        sizing: SizeBreakdown,
    ) -> None:
        if account.equity <= 0:
            raise ExposureLimitError("Account equity must be positive for exposure checks")

        notional = sizing.notional
        signed_notional = notional if trade.direction == "long" else -notional

        # Per symbol exposure
        projected_symbol = abs(self.state.open_exposure.get(trade.symbol, 0.0) + signed_notional)
        symbol_ratio = projected_symbol / account.equity
        if symbol_ratio > self.config.portfolio.per_symbol_exposure_pct:
            raise ExposureLimitError(
                f"Symbol exposure {symbol_ratio:.2%} exceeds limit "
                f"{self.config.portfolio.per_symbol_exposure_pct:.2%}"
            )

        # Total exposure
        current_total = sum(abs(v) for v in self.state.open_exposure.values())
        current_symbol = abs(self.state.open_exposure.get(trade.symbol, 0.0))
        projected_total = current_total - current_symbol + projected_symbol
        total_ratio = projected_total / account.equity
        if total_ratio > self.config.portfolio.max_total_exposure_pct:
            raise ExposureLimitError(
                f"Total exposure {total_ratio:.2%} exceeds limit "
                f"{self.config.portfolio.max_total_exposure_pct:.2%}"
            )

        # Asset class specific
        if trade.asset_class:
            asset_limit = self.config.portfolio.limit_for_asset_class(trade.asset_class)
        else:
            asset_limit = None
        if asset_limit is not None:
            projected_asset = abs(
                self.state.asset_exposure.get(trade.asset_class, 0.0) + signed_notional
            )
            asset_ratio = projected_asset / account.equity
            if asset_ratio > asset_limit:
                raise ExposureLimitError(
                    f"Asset class exposure {asset_ratio:.2%} exceeds limit {asset_limit:.2%}"
                )

        # Correlation bucket specific
        if trade.correlation_bucket:
            bucket_limit = self.config.portfolio.limit_for_bucket(trade.correlation_bucket)
            if bucket_limit is not None:
                bucket_total = abs(
                    self.state.bucket_exposure.get(trade.correlation_bucket, 0.0) + signed_notional
                )
                bucket_ratio = bucket_total / account.equity
                if bucket_ratio > bucket_limit:
                    raise ExposureLimitError(
                        f"Bucket exposure {bucket_ratio:.2%} exceeds limit {bucket_limit:.2%}"
                    )
*** End of File