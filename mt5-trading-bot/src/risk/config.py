"""Risk management configuration."""
from dataclasses import dataclass
from typing import Optional

@dataclass
class RiskConfig:
    """Risk management configuration."""
    max_drawdown_pct: float = 0.20  # 20% max drawdown
    daily_loss_limit_pct: float = 0.05  # 5% daily loss limit
    risk_per_trade_pct: float = 0.02  # 2% risk per trade
    max_position_size_pct: float = 0.10  # 10% max position size
    max_total_exposure_pct: float = 0.50  # 50% max total exposure
    stop_loss_pct: float = 0.02  # 2% stop loss
    take_profit_ratio: float = 2.0  # 2:1 reward:risk ratio
    cooldown_after_loss_minutes: int = 60  # 1 hour cooldown after loss
