"""Stop loss and take profit logic."""
from typing import Optional
from ..core.types import StrategyRecommendation

def calculate_stop_loss(
    entry_price: float,
    direction: str,
    risk_pct: float = 0.02
) -> float:
    """Calculate stop loss price."""
    if direction.lower() == "buy":
        return entry_price * (1 - risk_pct)
    else:
        return entry_price * (1 + risk_pct)

def calculate_take_profit(
    entry_price: float,
    stop_loss: float,
    reward_ratio: float = 2.0
) -> float:
    """Calculate take profit price."""
    risk = abs(entry_price - stop_loss)
    if direction == "buy":
        return entry_price + (risk * reward_ratio)
    else:
        return entry_price - (risk * reward_ratio)

def apply_stop_loss_take_profit(recommendation: StrategyRecommendation, risk_pct: float = 0.02):
    """Apply stop loss and take profit to recommendation."""
    if recommendation.signal.value == "buy":
        recommendation.stop_loss = recommendation.entry_price * (1 - risk_pct)
        recommendation.take_profit = recommendation.entry_price * (1 + risk_pct * 2.0)
    elif recommendation.signal.value == "sell":
        recommendation.stop_loss = recommendation.entry_price * (1 + risk_pct)
        recommendation.take_profit = recommendation.entry_price * (1 - risk_pct * 2.0)
