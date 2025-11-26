"""Trading orchestrator runtime."""
from typing import List, Dict
from .engine import StrategyEngine
from .types import StrategyRecommendation
from ..risk.risk_engine import RiskEngine

class TradingOrchestrator:
    """Orchestrates trading operations."""
    
    def __init__(self, strategy_engine: StrategyEngine, risk_engine: RiskEngine):
        self.strategy_engine = strategy_engine
        self.risk_engine = risk_engine
        self.active_positions = []
    
    def process_tick(self, market_data: Dict):
        """Process a new market tick."""
        # Get strategy recommendations
        recommendations = self.strategy_engine.get_recommendations(market_data)
        
        # Filter and validate through risk engine
        valid_recommendations = []
        for rec in recommendations:
            if self.risk_engine.validate_trade(rec):
                valid_recommendations.append(rec)
        
        return valid_recommendations
    
    def execute_trade(self, recommendation: StrategyRecommendation):
        """Execute a trade based on recommendation."""
        if self.risk_engine.validate_trade(recommendation):
            # Calculate position size
            position_size = self.risk_engine.calculate_position_size(recommendation)
            
            # Execute through MT5
            # This would call MT5 integration
            return {
                'status': 'success',
                'recommendation': recommendation,
                'position_size': position_size
            }
        
        return {'status': 'rejected', 'reason': 'Risk validation failed'}
