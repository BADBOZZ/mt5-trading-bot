"""High-level safety orchestration layer."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Tuple

from ..core.types import SignalType, StrategyRecommendation
from ..risk.risk_engine import RiskEngine


@dataclass
class SafetyCheckResult:
    """Represents the outcome of a safety validation."""
    recommendation: StrategyRecommendation
    passed: bool
    violations: List[str] = field(default_factory=list)


class SafetyController:
    """Coordinates safety checks on top of the risk engine."""

    def __init__(
        self,
        risk_engine: RiskEngine,
        *,
        min_confidence: float = 0.55,
        max_stop_loss_pct: float = 0.05,
        reward_risk_tolerance: float = 1e-3,
    ):
        self.risk_engine = risk_engine
        self.min_confidence = min_confidence
        self.max_stop_loss_pct = max_stop_loss_pct
        self.reward_risk_tolerance = reward_risk_tolerance
        self.rejection_log: List[SafetyCheckResult] = []

    def register_trade_result(self, profit: float):
        """Update risk state and trigger cooldowns after a trade outcome."""
        if not self.risk_engine.risk_state:
            return

        self.risk_engine.risk_state.daily_pnl += profit
        if profit < 0:
            self.risk_engine.limits.trigger_cooldown()

    def validate_recommendation(self, recommendation: StrategyRecommendation) -> SafetyCheckResult:
        """Run safety checks on a recommendation prior to order routing."""
        violations = []

        if recommendation.entry_price <= 0:
            violations.append("Entry price must be positive.")

        if recommendation.confidence < self.min_confidence:
            violations.append(
                f"Confidence {recommendation.confidence:.2f} below minimum {self.min_confidence:.2f}"
            )

        violations.extend(self._validate_stop_levels(recommendation))

        if not self.risk_engine.validate_trade(recommendation):
            violations.append("Risk engine rejected trade.")

        passed = len(violations) == 0
        result = SafetyCheckResult(recommendation=recommendation, passed=passed, violations=violations)
        if not passed:
            self.rejection_log.append(result)
        return result

    def filter_recommendations(
        self, recommendations: List[StrategyRecommendation]
    ) -> Tuple[List[StrategyRecommendation], Dict[str, List[str]]]:
        """Return safe recommendations and a rejection report."""
        passed: List[StrategyRecommendation] = []
        rejected: Dict[str, List[str]] = {}

        for rec in recommendations:
            result = self.validate_recommendation(rec)
            if result.passed:
                passed.append(rec)
            else:
                rejected[rec.symbol] = result.violations

        return passed, rejected

    def _validate_stop_levels(self, recommendation: StrategyRecommendation) -> List[str]:
        """Validate stop-loss and take-profit alignment."""
        issues: List[str] = []
        stop_loss = recommendation.stop_loss

        if stop_loss is None:
            issues.append("Stop loss missing.")
            return issues

        distance_pct = abs(recommendation.entry_price - stop_loss) / recommendation.entry_price
        if distance_pct > self.max_stop_loss_pct:
            issues.append(
                f"Stop loss distance {distance_pct:.2%} exceeds {self.max_stop_loss_pct:.2%}"
            )

        if recommendation.signal == SignalType.BUY and stop_loss >= recommendation.entry_price:
            issues.append("Stop loss must be below entry for BUY signals.")
        elif recommendation.signal == SignalType.SELL and stop_loss <= recommendation.entry_price:
            issues.append("Stop loss must be above entry for SELL signals.")

        if recommendation.take_profit is not None:
            reward = abs(recommendation.take_profit - recommendation.entry_price)
            risk = abs(recommendation.entry_price - stop_loss)
            if risk == 0:
                issues.append("Stop loss distance equals zero.")
            else:
                rr = reward / risk
                if rr + self.reward_risk_tolerance < self.risk_engine.config.take_profit_ratio:
                    issues.append(
                        f"Reward/risk {rr:.2f} below minimum {self.risk_engine.config.take_profit_ratio:.2f}"
                    )

        return issues
