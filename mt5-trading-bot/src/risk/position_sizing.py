"""Position sizing calculations."""
from typing import Dict
from .config import RiskConfig

def calculate_position_size(
    account_balance: float,
    entry_price: float,
    stop_loss_price: float,
    risk_config: RiskConfig,
    point_value: float = 0.0001,
    contract_size: int = 100000
) -> float:
    """
    Calculate position size in LOTS based on risk percentage.
    
    Formula: Lots = (Risk Amount) / (Stop Loss in Pips * Pip Value per Lot)
    
    For forex:
    - 1 standard lot = 100,000 units
    - Pip value per lot ≈ $10 for major pairs (varies by pair)
    - For GBPUSD: 1 pip = 0.0001, pip value ≈ $10 per lot
    
    Args:
        account_balance: Account balance in account currency
        entry_price: Entry price
        stop_loss_price: Stop loss price
        risk_config: Risk configuration
        point_value: Point size (0.0001 for most pairs, 0.00001 for JPY pairs)
        contract_size: Contract size (100,000 for standard lot)
    
    Returns:
        Position size in lots
    """
    # Calculate risk amount (e.g., 2% of $20,000 = $400)
    risk_amount = account_balance * risk_config.risk_per_trade_pct
    
    # Calculate stop loss distance in pips
    price_diff = abs(entry_price - stop_loss_price)
    if price_diff == 0:
        return 0.01  # Minimum lot size
    
    stop_loss_pips = price_diff / point_value
    
    # Calculate pip value per lot
    # For forex pairs with USD account:
    # - Major pairs (EURUSD, GBPUSD, AUDUSD, NZDUSD): ~$10 per pip per lot
    # - USD pairs (USDJPY, USDCHF, USDCAD): ~$10 per pip per lot (but point is 0.01 for JPY)
    # - Cross pairs: varies based on quote currency
    
    # Simplified: For most major pairs, pip value ≈ $10 per lot for USD account
    # More accurate: pip_value = (point_value * contract_size) / quote_currency_rate
    # For simplicity, we'll use $10 as approximation for major pairs
    pip_value_per_lot = 10.0  # $10 per pip per standard lot for major pairs
    
    # Calculate position size in lots
    # Lots = Risk Amount / (Stop Loss Pips * Pip Value per Lot)
    if stop_loss_pips == 0:
        return 0.01  # Minimum lot size if no stop loss
    
    position_size_lots = risk_amount / (stop_loss_pips * pip_value_per_lot)
    
    # Apply maximum position size limit (as percentage of account)
    # Max position should be reasonable - cap at 2% of account value in lots
    max_position_lots = (account_balance * 0.02) / (entry_price * contract_size)
    
    # Ensure reasonable limits: min 0.01, max 2.0 lots (or calculated max, whichever is smaller)
    position_size_lots = max(0.01, min(position_size_lots, min(max_position_lots, 2.0)))
    
    # Debug output
    print(f"    Position sizing: Risk=${risk_amount:.2f}, Pips={stop_loss_pips:.1f}, Lots={position_size_lots:.4f}")
    
    return position_size_lots

def calculate_lot_size(position_size: float, contract_size: int = 100000) -> float:
    """Convert position size to lot size."""
    return position_size / contract_size
