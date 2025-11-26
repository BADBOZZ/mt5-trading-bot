"""Strategy execution engine."""
from typing import List, Dict
from .types import StrategyConfig, StrategyRecommendation
from ..strategies.base import SignalStrategy

class StrategyEngine:
    """Manages and executes multiple trading strategies."""
    
    def __init__(self):
        self.strategies: Dict[str, SignalStrategy] = {}
        self.configs: Dict[str, StrategyConfig] = {}
    
    def register_strategy(self, name: str, strategy: SignalStrategy, config: StrategyConfig):
        """Register a strategy with its configuration."""
        self.strategies[name] = strategy
        self.configs[name] = config
    
    def get_recommendations(self, market_data: Dict) -> List[StrategyRecommendation]:
        """Get recommendations from all enabled strategies."""
        recommendations = []
        
        for name, strategy in self.strategies.items():
            config = self.configs[name]
            if config.enabled:
                try:
                    recs = strategy.analyze(market_data, config)
                    recommendations.extend(recs)
                except Exception as e:
                    print(f"Error in strategy {name}: {e}")
        
        return recommendations
    
    def update_market_data(self, market_data: Dict):
        """Update market data for all strategies."""
        for strategy in self.strategies.values():
            if hasattr(strategy, 'update_data'):
                strategy.update_data(market_data)
