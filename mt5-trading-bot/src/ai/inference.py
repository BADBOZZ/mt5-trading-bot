"""Inference helpers for coordinating MT5 data with the HybridSignalNet."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import MetaTrader5 as mt5
import numpy as np

from .models import FeatureNormalizer, HybridSignalNet


@dataclass
class InferenceConfig:
    symbol: str
    timeframe: int
    lookback: int = 128
    model_path: Path = Path("artifacts/hybrid_model.json")


class SignalInferencer:
    def __init__(self, config: InferenceConfig) -> None:
        self.config = config
        self.model, self.normalizer = HybridSignalNet.load(config.model_path)

    @staticmethod
    def _feature_vector(rates: np.ndarray) -> np.ndarray:
        close = rates["close"]
        high = rates["high"]
        low = rates["low"]
        atr = np.mean(np.abs(high[:-1] - low[:-1]))
        momentum = (close[0] - close[10]) / max(atr, 1e-6)
        velocity = (close[:5].mean() - close[5:10].mean())
        spread = np.mean(high - low)
        win_rate_proxy = np.clip((close[:20] > close[1:21]).mean(), 0.0, 1.0)
        return np.asarray([momentum, velocity, atr, spread, win_rate_proxy, 0.0], dtype=np.float32)

    def _collect_rates(self) -> np.ndarray:
        rates = mt5.copy_rates_from_pos(self.config.symbol, self.config.timeframe, 0, self.config.lookback)
        if rates is None:
            raise RuntimeError("Failed to fetch rates from MT5")
        return np.array(rates)

    def predict(self) -> Dict[str, float]:
        rates = self._collect_rates()
        features = self._feature_vector(rates)
        features_norm = self.normalizer.transform(features[np.newaxis, :])
        confidence = float(self.model.forward(features_norm)[0, 0])
        return {
            "symbol": self.config.symbol,
            "confidence": confidence,
            "regime": "trend" if confidence > 0.6 else "range",
        }


def batch_score(symbols: Iterable[str], timeframe: int, model_path: Path) -> List[Tuple[str, float]]:
    scores: List[Tuple[str, float]] = []
    for symbol in symbols:
        config = InferenceConfig(symbol=symbol, timeframe=timeframe, model_path=model_path)
        inferencer = SignalInferencer(config)
        result = inferencer.predict()
        scores.append((symbol, result["confidence"]))
    return scores
