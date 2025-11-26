"""Risk state tracking."""
from dataclasses import dataclass
from datetime import datetime
from typing import List, Dict

@dataclass
class AccountState:
    """Current account state."""
    balance: float
    equity: float
    margin: float
    free_margin: float
    margin_level: float
    timestamp: datetime = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()

@dataclass
class PositionState:
    """Current position state."""
    symbol: str
    volume: float
    entry_price: float
    current_price: float
    profit: float
    timestamp: datetime = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()

class RiskState:
    """Tracks risk state."""
    
    def __init__(self):
        self.account_state: AccountState = None
        self.positions: List[PositionState] = []
        self.daily_pnl: float = 0.0
        self.max_drawdown: float = 0.0
        self.peak_equity: float = 0.0
    
    def update_account(self, account_state: AccountState):
        """Update account state."""
        self.account_state = account_state
        
        # Update drawdown
        if account_state.equity > self.peak_equity:
            self.peak_equity = account_state.equity
        
        if self.peak_equity > 0:
            self.max_drawdown = (self.peak_equity - account_state.equity) / self.peak_equity
    
    def add_position(self, position: PositionState):
        """Add a position."""
        self.positions.append(position)
    
    def remove_position(self, symbol: str):
        """Remove a position."""
        self.positions = [p for p in self.positions if p.symbol != symbol]
    
    def get_total_exposure(self) -> float:
        """Get total exposure."""
        if not self.account_state:
            return 0.0
        return sum(p.volume * p.current_price for p in self.positions) / self.account_state.equity
