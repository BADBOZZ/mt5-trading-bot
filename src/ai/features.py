"""Feature engineering utilities for market data."""
from __future__ import annotations

from pathlib import Path
from typing import Tuple

import numpy as np
import pandas as pd

from .config import DataConfig

try:
    import ta  # type: ignore
except ImportError:  # pragma: no cover - optional dependency
    ta = None


def load_ohlcv(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    if "time" in df.columns:
        df["time"] = pd.to_datetime(df["time"])
        df = df.sort_values("time")
        df = df.set_index("time")
    df = df.rename(columns=str.lower)
    required = {"open", "high", "low", "close", "volume"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Input file lacks required columns: {missing}")
    return df


def _safe_indicator(series: pd.Series, fn, default: float = 0.0) -> pd.Series:
    try:
        values = fn()
        if isinstance(values, pd.DataFrame):
            values = values.iloc[:, 0]
        return values.astype(np.float32)
    except Exception:
        return pd.Series(np.full(len(series), default), index=series.index)


def compute_features(df: pd.DataFrame, cfg: DataConfig) -> pd.DataFrame:
    features = pd.DataFrame(index=df.index)
    close = df["close"].astype(np.float32)

    features["close"] = close
    features["volume"] = df["volume"].astype(np.float32)
    returns = close.pct_change().fillna(0.0)
    features["returns"] = returns
    features["log_returns"] = np.log1p(returns)

    if ta is not None:
        features["ema_fast"] = _safe_indicator(
            close,
            lambda: ta.trend.EMAIndicator(close, window=12).ema_indicator(),
        )
        features["ema_slow"] = _safe_indicator(
            close,
            lambda: ta.trend.EMAIndicator(close, window=48).ema_indicator(),
        )
        features["rsi"] = _safe_indicator(close, lambda: ta.momentum.RSIIndicator(close).rsi())
        features["atr"] = _safe_indicator(
            close,
            lambda: ta.volatility.AverageTrueRange(df["high"], df["low"], close).average_true_range(),
        )
        features["stoch"] = _safe_indicator(
            close,
            lambda: ta.momentum.StochasticOscillator(df["high"], df["low"], close).stoch(),
        )
        features["roc"] = _safe_indicator(close, lambda: ta.momentum.ROCIndicator(close).roc())
        bb = ta.volatility.BollingerBands(close)
        features["bb_width"] = _safe_indicator(close, lambda: bb.bollinger_wband())
    else:
        features["ema_fast"] = close.ewm(span=12).mean()
        features["ema_slow"] = close.ewm(span=48).mean()
        features["rsi"] = close.diff().fillna(0.0)
        features["atr"] = (df["high"] - df["low"]).rolling(14).mean().fillna(method="bfill")
        features["stoch"] = (close - df["low"].rolling(14).min()) / (
            df["high"].rolling(14).max() - df["low"].rolling(14).min()
        )
        features["roc"] = close.pct_change(10).fillna(0.0)
        features["bb_width"] = (
            close.rolling(20).std().fillna(method="bfill") / close.rolling(20).mean().fillna(method="bfill")
        )

    features = features.fillna(method="ffill").fillna(0.0)
    return features.astype(np.float32)


def build_feature_matrix(df: pd.DataFrame, cfg: DataConfig) -> Tuple[np.ndarray, np.ndarray]:
    features = compute_features(df, cfg)
    window = cfg.window_size
    horizon = cfg.prediction_horizon

    if len(df) <= window + horizon:
        raise ValueError("Not enough rows to build feature matrix. Increase dataset length or reduce window/horizon.")

    X, y_cls, y_reg = [], [], []
    closes = df["close"].values

    for idx in range(window, len(df) - horizon):
        frame = features.iloc[idx - window : idx].values
        future_close = closes[idx + horizon]
        current_close = closes[idx]
        delta = (future_close - current_close) / current_close
        regime = 1  # flat
        if delta > cfg.target_smoothing:
            regime = 2  # long
        elif delta < -cfg.target_smoothing:
            regime = 0  # short
        volatility = float(np.std(closes[idx - window : idx]))
        X.append(frame)
        y_cls.append(regime)
        y_reg.append([delta, volatility])

    X = np.stack(X)
    y_cls = np.array(y_cls, dtype=np.int64)
    y_reg = np.array(y_reg, dtype=np.float32)
    return X, np.concatenate([y_cls[:, None], y_reg], axis=1)
