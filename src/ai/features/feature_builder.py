from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, Iterable, Tuple

import numpy as np
import pandas as pd


@dataclass
class FeatureBuilder:
    price_columns: Tuple[str, str, str, str] = ("open", "high", "low", "close")
    volume_column: str = "tick_volume"
    spread_column: str = "spread"
    windows: Iterable[int] = field(default_factory=lambda: (5, 12, 24, 48, 96))

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        enriched = df.copy()
        enriched = self._technical_indicators(enriched)
        enriched = self._regime_features(enriched)
        enriched = self._future_return(enriched)
        return enriched.dropna()

    def _technical_indicators(self, df: pd.DataFrame) -> pd.DataFrame:
        close = df[self.price_columns[3]]
        high = df[self.price_columns[1]]
        low = df[self.price_columns[2]]
        volume = df[self.volume_column]

        for window in self.windows:
            df[f"ema_{window}"] = close.ewm(span=window, adjust=False).mean()
            df[f"volatility_{window}"] = close.pct_change().rolling(window).std().fillna(0.0)
            df[f"atr_{window}"] = (high - low).rolling(window).mean()

        fast, slow = 12, 26
        ema_fast = close.ewm(span=fast, adjust=False).mean()
        ema_slow = close.ewm(span=slow, adjust=False).mean()
        macd = ema_fast - ema_slow
        signal = macd.ewm(span=9, adjust=False).mean()
        df["macd"] = macd
        df["macd_signal"] = signal
        df["macd_hist"] = macd - signal

        delta = close.diff()
        gain = delta.clip(lower=0).rolling(14).mean()
        loss = -delta.clip(upper=0).rolling(14).mean()
        rs = gain / (loss + 1e-6)
        df["rsi"] = 100 - (100 / (1 + rs))

        mfi_raw = ((high + low + close) / 3) * volume
        positive_flow = mfi_raw.where(close > close.shift(1), 0)
        negative_flow = mfi_raw.where(close < close.shift(1), 0)
        money_ratio = positive_flow.rolling(14).sum() / (negative_flow.rolling(14).sum() + 1e-6)
        df["mfi"] = 100 - (100 / (1 + money_ratio))

        df["spread_zscore"] = (df[self.spread_column] - df[self.spread_column].rolling(96).mean()) / (
            df[self.spread_column].rolling(96).std() + 1e-6
        )
        return df

    def _regime_features(self, df: pd.DataFrame) -> pd.DataFrame:
        returns = df[self.price_columns[3]].pct_change().fillna(0.0)
        volatility = returns.rolling(48).std()
        trend = df[self.price_columns[3]].rolling(96).apply(self._hurst_exponent, raw=True)
        df["regime"] = np.select(
            [
                (trend > 0.6) & (volatility < 0.005),
                (trend < 0.4) & (volatility > 0.01),
            ],
            [1, -1],
            default=0,
        )
        df["volatility"] = volatility
        df["hurst"] = trend
        return df

    def _future_return(self, df: pd.DataFrame, horizon: int = 12) -> pd.DataFrame:
        close = df[self.price_columns[3]]
        df["future_return"] = (close.shift(-horizon) - close) / close
        df["future_direction"] = (df["future_return"] > 0).astype(int)
        return df

    @staticmethod
    def _hurst_exponent(series: np.ndarray) -> float:
        if len(series) < 20:
            return 0.5
        ts = np.array(series)
        taus = range(2, min(50, len(series)))
        variances = [np.var(ts[lag:] - ts[:-lag]) for lag in taus]
        log_variances = np.log(variances)
        log_taus = np.log(list(taus))
        slope, _ = np.polyfit(log_taus, log_variances, 1)
        return slope / 2
