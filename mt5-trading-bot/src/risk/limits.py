"""Risk limits enforcement."""
from typing import Optional
from datetime import datetime, timedelta
from .config import RiskConfig
from .state import RiskState

class RiskLimits:
    """Enforces risk limits."""
    
    def __init__(self, config: RiskConfig):
        self.config = config
        self.last_loss_time: Optional[datetime] = None
        self.cooldown_active = False
    
    def _require_account_state(self, risk_state: RiskState, context: str) -> tuple[bool, str]:
        """Ensure account state is available and valid."""
        account = risk_state.account_state
        if account is None:
            return False, f"{context}: account state unavailable"
        if account.balance <= 0 or account.equity <= 0:
            return False, f"{context}: invalid account balance/equity"
        return True, "OK"
    
    def check_drawdown(self, risk_state: RiskState) -> tuple[bool, str]:
        """Check if drawdown limit is exceeded."""
        if risk_state.max_drawdown > self.config.max_drawdown_pct:
            return False, f"Max drawdown exceeded: {risk_state.max_drawdown:.2%}"
        return True, "OK"
    
    def check_daily_loss(self, risk_state: RiskState) -> tuple[bool, str]:
        """Check if daily loss limit is exceeded."""
        account_ok, msg = self._require_account_state(risk_state, "Daily loss check")
        if not account_ok:
            return False, msg
        
        balance = risk_state.account_state.balance
        loss_limit = balance * abs(self.config.daily_loss_limit_pct)
        if loss_limit <= 0:
            return False, "Daily loss limit configuration invalid"
        
        if risk_state.daily_pnl < -loss_limit:
            return False, (
                f"Daily loss limit exceeded: {risk_state.daily_pnl:.2f} < "
                f"-{loss_limit:.2f}"
            )
        return True, "OK"
    
    def check_exposure(self, risk_state: RiskState) -> tuple[bool, str]:
        """Check if exposure limit is exceeded."""
        account_ok, msg = self._require_account_state(risk_state, "Exposure check")
        if not account_ok:
            return False, msg
        
        exposure = risk_state.get_total_exposure()
        if exposure > self.config.max_total_exposure_pct:
            return False, f"Max exposure exceeded: {exposure:.2%}"
        return True, "OK"
    
    def check_cooldown(self) -> tuple[bool, str]:
        """Check if cooldown period is active."""
        if self.cooldown_active:
            if self.last_loss_time:
                elapsed = datetime.now() - self.last_loss_time
                if elapsed < timedelta(minutes=self.config.cooldown_after_loss_minutes):
                    remaining = self.config.cooldown_after_loss_minutes - elapsed.total_seconds() / 60
                    return False, f"Cooldown active: {remaining:.1f} minutes remaining"
                else:
                    self.cooldown_active = False
        return True, "OK"
    
    def trigger_cooldown(self):
        """Trigger cooldown after loss."""
        self.last_loss_time = datetime.now()
        self.cooldown_active = True
