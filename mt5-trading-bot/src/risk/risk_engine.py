"""Risk engine orchestrator."""
from typing import Optional
from ..core.types import StrategyRecommendation
from .config import RiskConfig
from .state import RiskState, AccountState
from .limits import RiskLimits
from .position_sizing import calculate_position_size

class RiskEngine:
    """Orchestrates risk management."""
    
    def __init__(self, config: RiskConfig):
        self.config = config
        self.risk_state = RiskState()
        self.limits = RiskLimits(config)
    
    def update_account_state(self, account_state: AccountState):
        """Update account state."""
        self.risk_state.update_account(account_state)
    
    def validate_trade(self, recommendation: StrategyRecommendation) -> bool:
        """Validate if trade should be executed."""
        # Check drawdown
        drawdown_ok, msg = self.limits.check_drawdown(self.risk_state)
        if not drawdown_ok:
            print(f"Trade rejected: {msg}")
            return False
        
        # Check daily loss
        daily_ok, msg = self.limits.check_daily_loss(self.risk_state)
        if not daily_ok:
            print(f"Trade rejected: {msg}")
            return False
        
        # Check exposure
        exposure_ok, msg = self.limits.check_exposure(self.risk_state)
        if not exposure_ok:
            print(f"Trade rejected: {msg}")
            return False
        
        # Check cooldown
        cooldown_ok, msg = self.limits.check_cooldown()
        if not cooldown_ok:
            print(f"Trade rejected: {msg}")
            return False
        
        return True
    
    def calculate_position_size(self, recommendation: StrategyRecommendation) -> float:
        """Calculate position size for recommendation in lots."""
        if not self.risk_state.account_state:
            return 0.01  # Return minimum lot size
        
        stop_loss = recommendation.stop_loss or (
            recommendation.entry_price * (1 - self.config.stop_loss_pct)
        )
        
        # Determine point value based on symbol (0.0001 for most, 0.00001 for JPY pairs)
        symbol = recommendation.symbol
        if 'JPY' in symbol:
            point_value = 0.01  # JPY pairs use 0.01 as point
        else:
            point_value = 0.0001  # Most pairs use 0.0001
        
        # Calculate position size directly in lots
        position_size_lots = calculate_position_size(
            self.risk_state.account_state.equity,
            recommendation.entry_price,
            stop_loss,
            self.config,
            point_value=point_value,
            contract_size=100000
        )
        
        # Ensure reasonable limits
        position_size_lots = max(0.01, min(position_size_lots, 10.0))  # Max 10 lots
        
        return position_size_lots
