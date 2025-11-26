"""Strategy configuration types and data structures."""
from dataclasses import dataclass
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum

class SignalType(Enum):
    BUY = "buy"
    SELL = "sell"
    HOLD = "hold"

@dataclass
class StrategyConfig:
    """Configuration for a trading strategy."""
    name: str
    symbols: List[str]
    timeframes: List[str]
    enabled: bool = True
    risk_per_trade: float = 0.02
    max_positions: int = 5
    parameters: Dict[str, Any] = None

@dataclass
class StrategyRecommendation:
    """Trading recommendation from a strategy."""
    symbol: str
    timeframe: str
    signal: SignalType
    confidence: float
    entry_price: float
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    timestamp: datetime = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()
