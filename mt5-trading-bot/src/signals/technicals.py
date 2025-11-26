"""Technical indicators."""
import numpy as np
from typing import List

def calculate_sma(prices: List[float], period: int) -> float:
    """Calculate Simple Moving Average."""
    if len(prices) < period:
        return None
    return np.mean(prices[-period:])

def calculate_ema(prices: List[float], period: int, alpha: float = None) -> float:
    """Calculate Exponential Moving Average."""
    if len(prices) < period:
        return None
    if alpha is None:
        alpha = 2.0 / (period + 1)
    
    ema = prices[0]
    for price in prices[1:]:
        ema = alpha * price + (1 - alpha) * ema
    return ema

def calculate_rsi(prices: List[float], period: int = 14) -> float:
    """Calculate Relative Strength Index."""
    if len(prices) < period + 1:
        return None
    
    deltas = np.diff(prices)
    gains = np.where(deltas > 0, deltas, 0)
    losses = np.where(deltas < 0, -deltas, 0)
    
    avg_gain = np.mean(gains[-period:])
    avg_loss = np.mean(losses[-period:])
    
    if avg_loss == 0:
        return 100
    
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

def calculate_macd(prices: List[float], fast: int = 12, slow: int = 26, signal: int = 9) -> Dict:
    """Calculate MACD indicator."""
    if len(prices) < slow:
        return None
    
    ema_fast = calculate_ema(prices, fast)
    ema_slow = calculate_ema(prices, slow)
    macd_line = ema_fast - ema_slow
    
    # Simplified signal line
    signal_line = calculate_ema([macd_line], signal) if macd_line else None
    
    return {
        'macd': macd_line,
        'signal': signal_line,
        'histogram': macd_line - signal_line if signal_line else None
    }

def calculate_bollinger_bands(prices: List[float], period: int = 20, std_dev: float = 2.0) -> Dict:
    """Calculate Bollinger Bands."""
    if len(prices) < period:
        return None
    
    sma = calculate_sma(prices, period)
    std = np.std(prices[-period:])
    
    return {
        'upper': sma + (std * std_dev),
        'middle': sma,
        'lower': sma - (std * std_dev)
    }
