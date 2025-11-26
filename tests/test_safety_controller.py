from __future__ import annotations

from dataclasses import replace
from datetime import datetime, time

from core.types import AccountState, OrderRequest, TradeResult
from risk.limits import RiskLimits, SymbolRiskLimit
from security.safety_controller import SafetyController


def make_limits(**overrides) -> RiskLimits:
    limits = RiskLimits(
        per_trade_risk=0.01,
        max_daily_drawdown=1_000.0,
        max_total_drawdown=5_000.0,
        max_concurrent_positions=2,
        max_trades_per_day=3,
        max_account_leverage=5.0,
        min_equity_buffer=250.0,
        trading_window_utc=(time(9, 0), time(17, 0)),
        symbol_limits={
            "EURUSD": SymbolRiskLimit(max_volume=1.0, min_volume=0.01, max_exposure=100_000.0, max_slippage=1.5),
        },
    )
    for key, value in overrides.items():
        setattr(limits, key, value)
    return limits


def make_account(**overrides) -> AccountState:
    account = AccountState(
        balance=10_000.0,
        equity=10_000.0,
        daily_pl=0.0,
        total_pl=0.0,
        open_positions=tuple(),
        trades_today=0,
        margin_used=2_000.0,
        margin_available=8_000.0,
        open_risk=0.0,
        last_reset=None,
    )
    return replace(account, **overrides)


def make_order(ts: datetime, **overrides) -> OrderRequest:
    order = OrderRequest(
        symbol="EURUSD",
        side="buy",
        volume=0.5,
        price=1.10,
        stop_loss=1.08,
        take_profit=1.15,
        timestamp=ts,
        strategy_id="alpha",
    )
    return replace(order, **overrides)


def test_order_rejected_without_stop_loss():
    limits = make_limits()
    controller = SafetyController(limits)
    account = make_account()
    order = make_order(datetime(2024, 1, 2, 10, 0), stop_loss=None)

    decision = controller.evaluate_order(order, account)

    assert not decision.allowed
    assert "missing-stop-loss" in decision.reasons


def test_daily_trade_cap_enforced():
    limits = make_limits()
    controller = SafetyController(limits)
    account = make_account(trades_today=limits.max_trades_per_day)
    order = make_order(datetime(2024, 1, 2, 11, 0))

    decision = controller.evaluate_order(order, account)

    assert not decision.allowed
    assert "daily-trade-limit" in decision.reasons


def test_trading_window_enforced():
    limits = make_limits()
    controller = SafetyController(limits)
    account = make_account()
    order = make_order(datetime(2024, 1, 2, 8, 0))

    decision = controller.evaluate_order(order, account)

    assert not decision.allowed
    assert "outside-trading-window" in decision.reasons


def test_emergency_stop_triggers_on_drawdown():
    limits = make_limits()
    controller = SafetyController(limits)
    account = make_account(daily_pl=-2_000.0, total_pl=-6_000.0, equity=4_000.0)
    order = make_order(datetime(2024, 1, 2, 12, 0))

    decision = controller.evaluate_order(order, account)

    assert not decision.allowed
    assert "daily-drawdown" in decision.reasons
    assert controller.emergency_stop.state.triggered


def test_trade_outcome_updates_emergency_state():
    limits = make_limits()
    controller = SafetyController(limits)
    account = make_account()
    result = TradeResult(
        strategy_id="alpha",
        profit=0.0,
        loss=6_000.0,
        closed_volume=0.5,
        timestamp=datetime(2024, 1, 2, 13, 0),
    )

    decision = controller.record_trade_outcome(account, result)

    assert not decision.allowed
    assert "emergency-total-drawdown" in decision.reasons
    assert controller.emergency_stop.state.triggered


def test_exposure_limit_blocks_large_orders():
    limits = make_limits()
    controller = SafetyController(limits)
    account = make_account()
    order = make_order(datetime(2024, 1, 2, 11, 0), volume=2.0)

    decision = controller.evaluate_order(order, account)

    assert not decision.allowed
    assert "volume-too-high" in decision.reasons or "exposure-too-high" in decision.reasons
