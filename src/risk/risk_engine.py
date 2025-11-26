"""High-level risk engine orchestrating all safety checks."""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from .config import RiskConfig
from .exceptions import StopLogicError
from .limits import RiskLimitEnforcer
from .position_sizing import PositionSizer, SizeBreakdown
from .state import AccountState, RiskState, TradeIntent, TradePlan
from .stop_logic import StopManager, StopResult


class RiskEngine:
    """Coordinates sizing, stop logic, and limit enforcement."""

    def __init__(self, config: RiskConfig, state: Optional[RiskState] = None):
        self.config = config
        self.state = state or RiskState()
        self.sizer = PositionSizer(config.position_sizing)
        self.stop_manager = StopManager(config.stops)
        self.limits = RiskLimitEnforcer(config, self.state)

    def plan_trade(
        self,
        account: AccountState,
        intent: TradeIntent,
        pip_size: float = 0.0001,
    ) -> TradePlan:
        """Create a fully risk-checked trade plan."""

        stop_result = self._resolve_stop(intent, pip_size)
        sizing = self.sizer.size_from_stop(
            equity=account.equity,
            entry_price=intent.entry_price,
            stop_price=stop_result.stop_loss,
            pip_value=intent.pip_value,
        )

        self.limits.validate_trade(account, intent, sizing)

        risk_amount = sizing.risk_amount
        reward_amount = risk_amount * self.config.stops.take_profit_multiple

        plan = TradePlan(
            symbol=intent.symbol,
            direction=intent.direction,
            volume_lots=sizing.lots,
            entry_price=intent.entry_price,
            stop_loss=stop_result.stop_loss,
            take_profit=stop_result.take_profit,
            risk_amount=risk_amount,
            risk_fraction=sizing.risk_fraction,
            reward_amount=reward_amount,
            notional=sizing.notional,
        )
        return plan

    def commit_plan(self, intent: TradeIntent, account: AccountState, plan: TradePlan) -> None:
        """Record exposures for an approved plan and update equity state."""

        sizing = self._plan_to_sizing(plan)
        self.state.update_equity(account.equity, account.timestamp)
        self.limits.commit_trade(intent, sizing)

    def register_fill(self, realized_pnl: float, timestamp: Optional[datetime] = None) -> None:
        """Update state after a trade closes."""

        ts = timestamp or datetime.utcnow()
        self.limits.register_realized_pnl(realized_pnl, ts)

    def _resolve_stop(self, intent: TradeIntent, pip_size: float) -> StopResult:
        """Determine which stop logic to use based on provided data."""

        if intent.stop_loss and intent.take_profit:
            risk_distance = abs(intent.entry_price - intent.stop_loss)
            return StopResult(intent.stop_loss, intent.take_profit, risk_distance)

        if intent.volatility:
            return self.stop_manager.atr_based_stop(
                entry_price=intent.entry_price,
                direction=intent.direction,
                atr=intent.volatility,
                pip_size=pip_size,
            )

        if intent.stop_loss:
            stop_distance = abs(intent.entry_price - intent.stop_loss) / pip_size
            return self.stop_manager.fixed_stop(
                entry_price=intent.entry_price,
                direction=intent.direction,
                stop_distance_pips=stop_distance,
                pip_size=pip_size,
            )

        raise StopLogicError("Trade intent must supply volatility or stop levels")

    def _plan_to_sizing(self, plan: TradePlan) -> SizeBreakdown:
        return SizeBreakdown(
            lots=plan.volume_lots,
            risk_amount=plan.risk_amount,
            risk_fraction=plan.risk_fraction,
            notional=plan.notional,
        )
