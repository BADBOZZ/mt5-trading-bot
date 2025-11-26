from __future__ import annotations

from collections import deque
from typing import Iterable, List, Sequence


def simple_moving_average(values: Sequence[float], period: int) -> List[float]:
    if period <= 0:
        raise ValueError("period must be positive")
    if len(values) < period:
        return []

    window: deque[float] = deque()
    result: List[float] = []
    rolling_sum = 0.0

    for value in values:
        window.append(value)
        rolling_sum += value
        if len(window) > period:
            rolling_sum -= window.popleft()
        if len(window) == period:
            result.append(rolling_sum / period)

    return result


def exponential_moving_average(values: Sequence[float], period: int) -> List[float]:
    if period <= 0:
        raise ValueError("period must be positive")
    if len(values) < period:
        return []

    k = 2 / (period + 1)
    ema_values: List[float] = []
    ema = sum(values[:period]) / period
    ema_values.append(ema)

    for price in values[period:]:
        ema = price * k + ema * (1 - k)
        ema_values.append(ema)

    return ema_values


def relative_strength_index(values: Sequence[float], period: int = 14) -> List[float]:
    if len(values) <= period:
        return []

    gains: List[float] = []
    losses: List[float] = []

    for i in range(1, len(values)):
        delta = values[i] - values[i - 1]
        gains.append(max(delta, 0))
        losses.append(abs(min(delta, 0)))

    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period or 1e-9
    rs = avg_gain / avg_loss
    rsi_values: List[float] = [100 - (100 / (1 + rs))]

    for i in range(period, len(gains)):
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period or 1e-9
        rs = avg_gain / avg_loss
        rsi_values.append(100 - (100 / (1 + rs)))

    return rsi_values


def standard_deviation(values: Sequence[float], period: int) -> List[float]:
    if len(values) < period:
        return []
    sma = simple_moving_average(values, period)
    std_values: List[float] = []
    for idx in range(period - 1, len(values)):
        sample = values[idx - period + 1 : idx + 1]
        mean = sma[idx - period + 1]
        variance = sum((x - mean) ** 2 for x in sample) / period
        std_values.append(variance**0.5)
    return std_values


def bollinger_bands(values: Sequence[float], period: int = 20, std_multiplier: float = 2.0):
    if len(values) < period:
        return [], [], []
    sma = simple_moving_average(values, period)
    std_vals = standard_deviation(values, period)
    upper, lower = [], []
    for mean, std in zip(sma, std_vals):
        upper.append(mean + std_multiplier * std)
        lower.append(mean - std_multiplier * std)
    return upper, sma[-len(upper) :], lower


def true_range(highs: Sequence[float], lows: Sequence[float], closes: Sequence[float]) -> List[float]:
    tr_values: List[float] = []
    for i in range(1, len(closes)):
        tr_values.append(
            max(
                highs[i] - lows[i],
                abs(highs[i] - closes[i - 1]),
                abs(lows[i] - closes[i - 1]),
            )
        )
    return tr_values


def average_true_range(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    period: int = 14,
) -> List[float]:
    tr = true_range(highs, lows, closes)
    if len(tr) < period:
        return []
    atr_values: List[float] = []
    atr = sum(tr[:period]) / period
    atr_values.append(atr)
    for value in tr[period:]:
        atr = (atr * (period - 1) + value) / period
        atr_values.append(atr)
    return atr_values


def donchian_channels(highs: Sequence[float], lows: Sequence[float], period: int = 20):
    if len(highs) != len(lows):
        raise ValueError("highs and lows must be the same length")
    if len(highs) < period:
        return [], []
    upper, lower = [], []
    for idx in range(period - 1, len(highs)):
        upper_window = highs[idx - period + 1 : idx + 1]
        lower_window = lows[idx - period + 1 : idx + 1]
        upper.append(max(upper_window))
        lower.append(min(lower_window))
    return upper, lower
