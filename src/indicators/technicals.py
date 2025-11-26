"""
Lightweight technical indicators used by the strategies.
"""

from __future__ import annotations

from collections import deque
from math import sqrt
from typing import Deque, Iterable, List, Optional, Sequence, Tuple


def _validate_period(period: int) -> None:
    if period <= 0:
        raise ValueError("period must be positive")


def sma(values: Sequence[float], period: int) -> List[Optional[float]]:
    """Simple moving average with `None` padding for warm-up bars."""

    _validate_period(period)
    result: List[Optional[float]] = []
    window: Deque[float] = deque()
    running_sum = 0.0

    for price in values:
        window.append(price)
        running_sum += price

        if len(window) > period:
            running_sum -= window.popleft()

        if len(window) == period:
            result.append(running_sum / period)
        else:
            result.append(None)

    return result


def ema(values: Sequence[float], period: int) -> List[Optional[float]]:
    """Exponential moving average with smoothing 2/(N+1)."""

    _validate_period(period)
    multiplier = 2 / (period + 1)
    result: List[Optional[float]] = []
    ema_value: Optional[float] = None

    for price in values:
        if ema_value is None:
            ema_value = price
        else:
            ema_value = (price - ema_value) * multiplier + ema_value
        result.append(ema_value if len(result) >= period - 1 else None)

    return result


def rsi(values: Sequence[float], period: int = 14) -> List[Optional[float]]:
    """Relative Strength Index based on Wilder's smoothing."""

    _validate_period(period)
    gains: Deque[float] = deque(maxlen=period)
    losses: Deque[float] = deque(maxlen=period)
    avg_gain = 0.0
    avg_loss = 0.0
    result: List[Optional[float]] = []
    last_price: Optional[float] = None

    for price in values:
        if last_price is None:
            last_price = price
            result.append(None)
            continue

        delta = price - last_price
        gains.append(max(delta, 0.0))
        losses.append(abs(min(delta, 0.0)))
        last_price = price

        if len(gains) < period:
            result.append(None)
            continue

        if len(result) == period:
            avg_gain = sum(gains) / period
            avg_loss = sum(losses) / period
        else:
            avg_gain = (avg_gain * (period - 1) + gains[-1]) / period
            avg_loss = (avg_loss * (period - 1) + losses[-1]) / period

        rs = (avg_gain / avg_loss) if avg_loss != 0 else float("inf")
        rsi_value = 100 - (100 / (1 + rs))
        result.append(rsi_value)

    return result


def bollinger_bands(
    values: Sequence[float], period: int = 20, num_std: float = 2.0
) -> List[Tuple[Optional[float], Optional[float], Optional[float]]]:
    """Return tuples of (middle, upper, lower) bands."""

    _validate_period(period)
    middle = sma(values, period)
    result: List[Tuple[Optional[float], Optional[float], Optional[float]]] = []

    for idx, price in enumerate(values):
        mid = middle[idx]
        if mid is None:
            result.append((None, None, None))
            continue

        window = values[idx - period + 1 : idx + 1]
        variance = sum((p - mid) ** 2 for p in window) / period
        std = sqrt(variance)
        upper = mid + num_std * std
        lower = mid - num_std * std
        result.append((mid, upper, lower))

    return result


def atr(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    period: int = 14,
) -> List[Optional[float]]:
    """Average True Range used for volatility-aware stops."""

    _validate_period(period)
    result: List[Optional[float]] = []
    tr_values: List[float] = []

    for idx in range(len(highs)):
        if idx == 0:
            tr = highs[idx] - lows[idx]
        else:
            tr = max(
                highs[idx] - lows[idx],
                abs(highs[idx] - closes[idx - 1]),
                abs(lows[idx] - closes[idx - 1]),
            )
        tr_values.append(tr)

        if len(tr_values) < period:
            result.append(None)
        elif len(tr_values) == period:
            result.append(sum(tr_values[-period:]) / period)
        else:
            prev_atr = result[-1] if result[-1] is not None else tr_values[-2]
            result.append(((prev_atr * (period - 1)) + tr) / period)

    return result


def donchian_channel(
    highs: Sequence[float], lows: Sequence[float], period: int = 20
) -> List[Tuple[Optional[float], Optional[float]]]:
    """Upper/lower Donchian channel for breakout detection."""

    _validate_period(period)
    result: List[Tuple[Optional[float], Optional[float]]] = []

    for idx in range(len(highs)):
        if idx + 1 < period:
            result.append((None, None))
            continue

        window_high = max(highs[idx - period + 1 : idx + 1])
        window_low = min(lows[idx - period + 1 : idx + 1])
        result.append((window_high, window_low))

    return result


__all__ = ["sma", "ema", "rsi", "bollinger_bands", "atr", "donchian_channel"]

