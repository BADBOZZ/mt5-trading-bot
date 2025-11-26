"""Signal generation functions."""
from typing import List, Dict
import numpy as np
from ..strategies.base import SignalStrategy
from ..core.types import StrategyConfig, StrategyRecommendation, SignalType

class TrendFollowingGenerator(SignalStrategy):
    """Trend following signal generator."""
    
    def analyze(self, market_data: Dict, config: StrategyConfig) -> List[StrategyRecommendation]:
        recommendations = []
        # Simplified trend following logic
        for symbol in config.symbols:
            if symbol in market_data:
                data = market_data[symbol]
                if len(data) >= 20:
                    prices = [d['close'] for d in data[-20:]]
                    sma_short = np.mean(prices[-10:])
                    sma_long = np.mean(prices[-20:])
                    
                    if sma_short > sma_long:
                        recommendations.append(StrategyRecommendation(
                            symbol=symbol,
                            timeframe=config.timeframes[0],
                            signal=SignalType.BUY,
                            confidence=0.7,
                            entry_price=prices[-1]
                        ))
        return recommendations

class MeanReversionGenerator(SignalStrategy):
    """Mean reversion signal generator."""
    
    def analyze(self, market_data: Dict, config: StrategyConfig) -> List[StrategyRecommendation]:
        recommendations = []
        for symbol in config.symbols:
            if symbol in market_data:
                data = market_data[symbol]
                if len(data) >= 20:
                    prices = [d['close'] for d in data[-20:]]
                    mean = np.mean(prices)
                    std = np.std(prices)
                    current = prices[-1]
                    
                    if current < mean - std:
                        recommendations.append(StrategyRecommendation(
                            symbol=symbol,
                            timeframe=config.timeframes[0],
                            signal=SignalType.BUY,
                            confidence=0.65,
                            entry_price=current
                        ))
        return recommendations

class BreakoutGenerator(SignalStrategy):
    """Breakout signal generator."""
    
    def analyze(self, market_data: Dict, config: StrategyConfig) -> List[StrategyRecommendation]:
        recommendations = []
        for symbol in config.symbols:
            if symbol in market_data:
                data = market_data[symbol]
                if len(data) >= 20:
                    highs = [d['high'] for d in data[-20:]]
                    lows = [d['low'] for d in data[-20:]]
                    resistance = max(highs)
                    support = min(lows)
                    current = data[-1]['close']
                    
                    if current > resistance * 0.99:
                        recommendations.append(StrategyRecommendation(
                            symbol=symbol,
                            timeframe=config.timeframes[0],
                            signal=SignalType.BUY,
                            confidence=0.75,
                            entry_price=current
                        ))
        return recommendations
