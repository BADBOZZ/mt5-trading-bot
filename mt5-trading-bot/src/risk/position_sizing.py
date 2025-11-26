"""Position sizing calculations."""
from typing import Dict
from .config import RiskConfig

def calculate_position_size(
    account_balance: float,
    entry_price: float,
    stop_loss_price: float,
    risk_config: RiskConfig
) -> float:
    """Calculate position size based on risk."""
    if account_balance <= 0 or entry_price <= 0 or stop_loss_price <= 0:
        return 0.0
    
    risk_amount = account_balance * abs(risk_config.risk_per_trade_pct)
    price_diff = abs(entry_price - stop_loss_price)
    
    if price_diff == 0:
        return 0.0
    
    position_size = risk_amount / price_diff
    
    # Apply maximum position size limit
    max_position_value = account_balance * risk_config.max_position_size_pct
    max_position_size = max_position_value / entry_price
    
    return min(position_size, max_position_size)

def calculate_lot_size(position_size: float, contract_size: int = 100000) -> float:
    """Convert position size to lot size."""
    return position_size / contract_size
