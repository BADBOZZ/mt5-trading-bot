"""Signal generation functions."""
from typing import List, Dict
import numpy as np
from ..strategies.base import SignalStrategy
from ..core.types import StrategyConfig, StrategyRecommendation, SignalType

class TrendFollowingGenerator(SignalStrategy):
    """Trend following signal generator."""
    
    def analyze(self, market_data: Dict, config: StrategyConfig) -> List[StrategyRecommendation]:
        recommendations = []
        params = config.parameters or {}
        fast_period = int(params.get("trend_fast_period", 10))
        slow_period = int(params.get("trend_slow_period", 20))
        if slow_period <= fast_period:
            slow_period = fast_period + 1

        for symbol in config.symbols:
            if symbol in market_data:
                data = market_data[symbol]
                if len(data) >= slow_period:
                    prices = [d['close'] for d in data[-slow_period:]]
                    sma_short = np.mean(prices[-fast_period:])
                    sma_long = np.mean(prices)
                    
                    if sma_short > sma_long:
                        recommendation = StrategyRecommendation(
                            symbol=symbol,
                            timeframe=config.timeframes[0],
                            signal=SignalType.BUY,
                            confidence=0.7,
                            entry_price=prices[-1]
                        )
                        recommendation.strategy = self.name
                        recommendations.append(recommendation)
        return recommendations

class MeanReversionGenerator(SignalStrategy):
    """Mean reversion signal generator."""
    
    def analyze(self, market_data: Dict, config: StrategyConfig) -> List[StrategyRecommendation]:
        recommendations: List[StrategyRecommendation] = []
        params = config.parameters or {}
        lookback = int(params.get("mean_lookback", 20))
        deviation = float(params.get("mean_std_dev", 1.0))
        for symbol in config.symbols:
            if symbol in market_data:
                data = market_data[symbol]
                if len(data) >= lookback:
                    prices = [d['close'] for d in data[-lookback:]]
                    mean = np.mean(prices)
                    std = np.std(prices)
                    current = prices[-1]
                    
                    threshold = mean - deviation * std

                    if current < threshold:
                        recommendation = StrategyRecommendation(
                            symbol=symbol,
                            timeframe=config.timeframes[0],
                            signal=SignalType.BUY,
                            confidence=0.65,
                            entry_price=current
                        )
                        recommendation.strategy = self.name
                        recommendations.append(recommendation)
        return recommendations

class BreakoutGenerator(SignalStrategy):
    """Breakout signal generator."""
    
    def analyze(self, market_data: Dict, config: StrategyConfig) -> List[StrategyRecommendation]:
        recommendations: List[StrategyRecommendation] = []
        params = config.parameters or {}
        lookback = int(params.get("breakout_lookback", 20))
        buffer_pct = float(params.get("breakout_buffer", 0.01))
        for symbol in config.symbols:
            if symbol in market_data:
                data = market_data[symbol]
                if len(data) >= lookback:
                    highs = [d['high'] for d in data[-lookback:]]
                    lows = [d['low'] for d in data[-lookback:]]
                    resistance = max(highs)
                    support = min(lows)
                    current = data[-1]['close']
                    
                    if current > resistance * (1 - buffer_pct):
                        recommendation = StrategyRecommendation(
                            symbol=symbol,
                            timeframe=config.timeframes[0],
                            signal=SignalType.BUY,
                            confidence=0.75,
                            entry_price=current
                        )
                        recommendation.strategy = self.name
                        recommendations.append(recommendation)
        return recommendations
