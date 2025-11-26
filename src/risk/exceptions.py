"""Custom exception types for risk management violations."""


class RiskViolation(Exception):
    """Base exception for any risk rule breach."""


class PositionSizingError(RiskViolation):
    """Raised when a requested trade violates position sizing rules."""


class StopLogicError(RiskViolation):
    """Raised when stop/take-profit logic cannot be satisfied."""


class DrawdownLimitError(RiskViolation):
    """Raised when max drawdown rules would be violated."""


class DailyLossLimitError(RiskViolation):
    """Raised when daily loss limits block new trades."""


class ExposureLimitError(RiskViolation):
    """Raised when portfolio exposure caps would be exceeded."""
