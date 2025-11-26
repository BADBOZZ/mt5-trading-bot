"""Risk management configuration objects for the MT5 trading bot."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, Optional


@dataclass
class PositionSizingConfig:
    """Settings for position sizing and risk per trade calculations."""

    risk_per_trade: float = 0.005  # 0.5 % default risk
    max_position_risk: float = 0.02  # Hard ceiling per position
    min_lot: float = 0.01
    max_lot: float = 50.0
    lot_step: float = 0.01
    contract_size: float = 100_000  # Standard FX lot
    allow_fractional: bool = True

    def validate(self) -> None:
        if not 0 < self.risk_per_trade < 1:
            raise ValueError("risk_per_trade must be expressed as fraction of equity (0-1)")
        if not 0 < self.max_position_risk <= 1:
            raise ValueError("max_position_risk must be between 0 and 1")
        if self.min_lot <= 0 or self.max_lot <= 0:
            raise ValueError("Lot sizes must be positive")
        if self.min_lot > self.max_lot:
            raise ValueError("min_lot cannot exceed max_lot")
        if self.lot_step <= 0:
            raise ValueError("lot_step must be positive")


@dataclass
class StopConfig:
    """Parameters for stop-loss, take-profit, and trailing logic."""

    atr_multiplier: float = 1.5
    take_profit_multiple: float = 2.0
    hard_stop_pips: Optional[float] = None
    min_stop_pips: float = 5.0
    max_stop_pips: float = 500.0
    trailing_start_multiple: float = 1.0  # when unrealized >= 1R start trailing
    trailing_distance_pips: float = 15.0

    def validate(self) -> None:
        if self.atr_multiplier <= 0:
            raise ValueError("atr_multiplier must be positive")
        if self.take_profit_multiple <= 0:
            raise ValueError("take_profit_multiple must be positive")
        if self.min_stop_pips <= 0:
            raise ValueError("min_stop_pips must be positive")
        if self.max_stop_pips < self.min_stop_pips:
            raise ValueError("max_stop_pips must be greater than min_stop_pips")
        if self.trailing_distance_pips <= 0:
            raise ValueError("trailing_distance_pips must be positive")


@dataclass
class DrawdownConfig:
    """Account-level risk limits for drawdowns and daily losses."""

    max_drawdown_pct: float = 0.2  # 20% maximum peak-to-trough drawdown
    max_daily_loss_pct: float = 0.03  # 3% of equity per day
    max_daily_loss_abs: Optional[float] = None
    cooling_off_minutes: int = 60

    def validate(self) -> None:
        if not 0 < self.max_drawdown_pct < 1:
            raise ValueError("max_drawdown_pct must be a fraction between 0 and 1")
        if not 0 < self.max_daily_loss_pct < 1:
            raise ValueError("max_daily_loss_pct must be a fraction between 0 and 1")
        if self.max_daily_loss_abs is not None and self.max_daily_loss_abs <= 0:
            raise ValueError("max_daily_loss_abs must be positive if provided")
        if self.cooling_off_minutes <= 0:
            raise ValueError("cooling_off_minutes must be positive")


@dataclass
class PortfolioLimitsConfig:
    """Portfolio-wide exposure limits and correlation controls."""

    max_total_exposure_pct: float = 1.5  # Notional exposure vs equity
    per_symbol_exposure_pct: float = 0.25
    asset_class_limits: Dict[str, float] = field(default_factory=dict)
    correlation_buckets: Dict[str, float] = field(default_factory=dict)

    def limit_for_asset_class(self, asset_class: str) -> Optional[float]:
        return self.asset_class_limits.get(asset_class)

    def limit_for_bucket(self, bucket: str) -> Optional[float]:
        return self.correlation_buckets.get(bucket)

    def validate(self) -> None:
        if self.max_total_exposure_pct <= 0:
            raise ValueError("max_total_exposure_pct must be positive")
        if self.per_symbol_exposure_pct <= 0:
            raise ValueError("per_symbol_exposure_pct must be positive")
        for name, value in {**self.asset_class_limits, **self.correlation_buckets}.items():
            if value <= 0:
                raise ValueError(f"Exposure limit for {name} must be positive")


@dataclass
class RiskConfig:
    """Top-level risk configuration holder."""

    position_sizing: PositionSizingConfig = field(default_factory=PositionSizingConfig)
    stops: StopConfig = field(default_factory=StopConfig)
    drawdown: DrawdownConfig = field(default_factory=DrawdownConfig)
    portfolio: PortfolioLimitsConfig = field(default_factory=PortfolioLimitsConfig)

    def validate(self) -> None:
        self.position_sizing.validate()
        self.stops.validate()
        self.drawdown.validate()
        self.portfolio.validate()

    @classmethod
    def from_dict(cls, data: Dict[str, Dict]) -> "RiskConfig":
        return cls(
            position_sizing=PositionSizingConfig(**data.get("position_sizing", {})),
            stops=StopConfig(**data.get("stops", {})),
            drawdown=DrawdownConfig(**data.get("drawdown", {})),
            portfolio=PortfolioLimitsConfig(**data.get("portfolio", {})),
        )
