"""Base strategy class."""
from abc import ABC, abstractmethod
from typing import List, Dict
from ..core.types import StrategyConfig, StrategyRecommendation

class SignalStrategy(ABC):
    """Base class for all trading strategies."""
    
    def __init__(self, name: str):
        self.name = name
        self.market_data = {}
    
    @abstractmethod
    def analyze(self, market_data: Dict, config: StrategyConfig) -> List[StrategyRecommendation]:
        """Analyze market data and generate recommendations."""
        pass
    
    def update_data(self, market_data: Dict):
        """Update internal market data."""
        self.market_data = market_data
    
    def calculate_stop_loss(self, entry_price: float, direction: str, risk_pct: float = 0.02) -> float:
        """Calculate stop loss price."""
        if direction == "buy":
            return entry_price * (1 - risk_pct)
        else:
            return entry_price * (1 + risk_pct)
    
    def calculate_take_profit(self, entry_price: float, direction: str, reward_ratio: float = 2.0) -> float:
        """Calculate take profit price."""
        if direction == "buy":
            return entry_price * (1 + reward_ratio * 0.02)
        else:
            return entry_price * (1 - reward_ratio * 0.02)
