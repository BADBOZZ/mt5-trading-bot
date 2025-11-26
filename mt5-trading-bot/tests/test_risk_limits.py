"""Risk limit and safety edge-case tests."""
from datetime import timedelta
import unittest

from src.core.types import SignalType, StrategyRecommendation
from src.risk.config import RiskConfig
from src.risk.limits import RiskLimits
from src.risk.risk_engine import RiskEngine
from src.risk.position_sizing import calculate_position_size
from src.risk.state import AccountState, PositionState, RiskState
from src.security.safety_controller import SafetyController


class RiskLimitsTests(unittest.TestCase):
    """Validate RiskLimits against safety edge cases."""

    def setUp(self):
        self.config = RiskConfig(
            max_drawdown_pct=0.20,
            daily_loss_limit_pct=0.05,
            risk_per_trade_pct=0.02,
            max_position_size_pct=0.10,
            max_total_exposure_pct=0.50,
            stop_loss_pct=0.02,
            take_profit_ratio=2.0,
            cooldown_after_loss_minutes=60,
        )
        self.limits = RiskLimits(self.config)
        self.state = RiskState()

    def _with_account(self, balance: float = 10_000.0, equity: float = 10_000.0):
        """Populate the risk state with an account snapshot."""
        account = AccountState(
            balance=balance,
            equity=equity,
            margin=0.0,
            free_margin=equity,
            margin_level=200.0,
        )
        self.state.update_account(account)

    def test_daily_loss_requires_account_state(self):
        allowed, message = self.limits.check_daily_loss(self.state)
        self.assertFalse(allowed)
        self.assertIn("account state unavailable", message)

    def test_daily_loss_limit_enforced(self):
        self._with_account()
        self.state.daily_pnl = -self.state.account_state.balance * 0.06
        allowed, message = self.limits.check_daily_loss(self.state)
        self.assertFalse(allowed)
        self.assertIn("Daily loss limit exceeded", message)

    def test_daily_loss_ok_within_limits(self):
        self._with_account()
        self.state.daily_pnl = -self.state.account_state.balance * 0.03
        allowed, _ = self.limits.check_daily_loss(self.state)
        self.assertTrue(allowed)

    def test_exposure_requires_account_state(self):
        allowed, message = self.limits.check_exposure(self.state)
        self.assertFalse(allowed)
        self.assertIn("account state unavailable", message)

    def test_exposure_enforced_when_over_limit(self):
        self._with_account(balance=1_000.0, equity=1_000.0)
        self.state.add_position(
            PositionState(symbol="EURUSD", volume=600.0, entry_price=1.00, current_price=1.00, profit=0)
        )
        self.state.add_position(
            PositionState(symbol="GBPUSD", volume=200.0, entry_price=1.00, current_price=1.00, profit=0)
        )
        allowed, message = self.limits.check_exposure(self.state)
        self.assertFalse(allowed)
        self.assertIn("Max exposure exceeded", message)

    def test_cooldown_blocks_until_period_elapses(self):
        self.limits.trigger_cooldown()
        allowed, message = self.limits.check_cooldown()
        self.assertFalse(allowed)
        self.assertIn("Cooldown active", message)

        # Fast forward beyond cooldown
        self.limits.last_loss_time -= timedelta(minutes=self.config.cooldown_after_loss_minutes + 1)
        allowed, _ = self.limits.check_cooldown()
        self.assertTrue(allowed)

    def test_get_total_exposure_handles_zero_equity(self):
        self._with_account(equity=0.0)
        self.state.add_position(
            PositionState(symbol="XAUUSD", volume=1.0, entry_price=1900.0, current_price=1890.0, profit=-100)
        )
        exposure = self.state.get_total_exposure()
        self.assertEqual(exposure, 0.0)


class PositionSizingTests(unittest.TestCase):
    """Validate position sizing safety logic."""

    def setUp(self):
        self.config = RiskConfig()

    def test_returns_zero_for_invalid_inputs(self):
        self.assertEqual(calculate_position_size(-1000, 1.1, 1.0, self.config), 0.0)
        self.assertEqual(calculate_position_size(1000, 0, 1.0, self.config), 0.0)
        self.assertEqual(calculate_position_size(1000, 1.1, 0, self.config), 0.0)
        self.assertEqual(calculate_position_size(1000, 1.1, 1.1, self.config), 0.0)

    def test_caps_position_at_maximum_allocation(self):
        size = calculate_position_size(10_000, 1.2, 1.15, self.config)
        max_value = 10_000 * self.config.max_position_size_pct / 1.2
        self.assertLessEqual(size, max_value)


class SafetyControllerTests(unittest.TestCase):
    """Validate the security layer behavior."""

    def setUp(self):
        self.risk_engine = RiskEngine(RiskConfig())
        self.controller = SafetyController(self.risk_engine, min_confidence=0.4)
        self.account = AccountState(
            balance=10_000.0,
            equity=10_000.0,
            margin=0.0,
            free_margin=10_000.0,
            margin_level=200.0,
        )
        self.risk_engine.update_account_state(self.account)

    def _recommendation(self, **overrides) -> StrategyRecommendation:
        base = dict(
            symbol="EURUSD",
            timeframe="H1",
            signal=SignalType.BUY,
            confidence=0.8,
            entry_price=1.1000,
            stop_loss=1.0950,
            take_profit=1.1100,
        )
        base.update(overrides)
        return StrategyRecommendation(**base)

    def test_rejects_missing_stop_loss(self):
        rec = self._recommendation(stop_loss=None)
        result = self.controller.validate_recommendation(rec)
        self.assertFalse(result.passed)
        self.assertIn("Stop loss missing", result.violations[0])

    def test_rejects_low_confidence_signal(self):
        rec = self._recommendation(confidence=0.1)
        result = self.controller.validate_recommendation(rec)
        self.assertFalse(result.passed)
        self.assertTrue(any("Confidence" in msg for msg in result.violations))

    def test_accepts_risk_compliant_trade(self):
        rec = self._recommendation()
        result = self.controller.validate_recommendation(rec)
        self.assertTrue(result.passed)


if __name__ == "__main__":
    unittest.main()
