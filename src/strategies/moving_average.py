from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd

from .base import BaseStrategy


class MovingAverageCrossoverStrategy(BaseStrategy):
    """
    Simple but effective strategy used as the default validation target.

    Parameters
    ----------
    fast_period: int
        Window for the fast moving average.
    slow_period: int
        Window for the slow moving average.
    volatility_filter: int, optional
        Lookback window for the rolling standard deviation filter. When provided,
        signals are muted when volatility is below its rolling median.
    """

    def __init__(self, **parameters: Any) -> None:
        defaults = {"fast_period": 20, "slow_period": 50, "volatility_filter": None}
        defaults.update(parameters)
        super().__init__(**defaults)

    def generate_signals(self, data: pd.DataFrame) -> pd.Series:
        self._assert_columns(data, "close")

        fast = data["close"].rolling(self.parameters["fast_period"]).mean()
        slow = data["close"].rolling(self.parameters["slow_period"]).mean()
        raw = np.where(fast > slow, 1, -1)
        signals = pd.Series(raw, index=data.index)

        # Optional volatility filter to avoid chop
        vol_window = self.parameters.get("volatility_filter")
        if vol_window:
            rolling_vol = data["close"].pct_change().rolling(vol_window).std()
            vol_threshold = rolling_vol.rolling(vol_window).median()
            signals = signals.where(rolling_vol >= vol_threshold, 0)

        # Hold previous signal when inputs are NaN
        return signals.ffill().fillna(0.0)
