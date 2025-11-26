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
        """Calculate position size for recommendation."""
        if not self.risk_state.account_state:
            return 0.0
        
        stop_loss = recommendation.stop_loss or (
            recommendation.entry_price * (1 - self.config.stop_loss_pct)
        )
        
        return calculate_position_size(
            self.risk_state.account_state.equity,
            recommendation.entry_price,
            stop_loss,
            self.config
        )
