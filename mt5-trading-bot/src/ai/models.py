"""Model definitions for hybrid MT5 AI strategy."""
from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Dict, Tuple

import numpy as np


@dataclass
class FeatureNormalizer:
    """Keeps running statistics for feature scaling."""

    mean: np.ndarray = field(default_factory=lambda: np.zeros(1))
    std: np.ndarray = field(default_factory=lambda: np.ones(1))

    def fit(self, features: np.ndarray) -> None:
        self.mean = features.mean(axis=0)
        self.std = features.std(axis=0) + 1e-8

    def transform(self, features: np.ndarray) -> np.ndarray:
        return (features - self.mean) / self.std

    def to_dict(self) -> Dict[str, Any]:
        return {
            "mean": self.mean.tolist(),
            "std": self.std.tolist(),
        }

    @classmethod
    def from_dict(cls, payload: Dict[str, Any]) -> "FeatureNormalizer":
        instance = cls()
        instance.mean = np.asarray(payload["mean"], dtype=np.float32)
        instance.std = np.asarray(payload["std"], dtype=np.float32)
        return instance


class HybridSignalNet:
    """Tiny fully connected network used to mirror the MQL5 strategy."""

    def __init__(self, input_dim: int, hidden_dim: int = 16, seed: int = 7) -> None:
        rng = np.random.default_rng(seed)
        limit = 1.0 / np.sqrt(input_dim)
        self.w1 = rng.uniform(-limit, limit, size=(input_dim, hidden_dim)).astype(np.float32)
        self.b1 = np.zeros(hidden_dim, dtype=np.float32)
        self.w2 = rng.uniform(-0.5, 0.5, size=(hidden_dim, 1)).astype(np.float32)
        self.b2 = np.zeros(1, dtype=np.float32)

    def forward(self, features: np.ndarray) -> np.ndarray:
        z1 = np.tanh(features @ self.w1 + self.b1)
        logits = z1 @ self.w2 + self.b2
        return 1.0 / (1.0 + np.exp(-logits))

    def parameters(self) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
        return self.w1, self.b1, self.w2, self.b2

    def train(self, features: np.ndarray, labels: np.ndarray, epochs: int = 200, lr: float = 0.01) -> None:
        for epoch in range(epochs):
            preds = self.forward(features)
            error = preds - labels.reshape(-1, 1)
            z1 = np.tanh(features @ self.w1 + self.b1)
            grad_w2 = z1.T @ error / len(features)
            grad_b2 = error.mean(axis=0)

            dz1 = (error @ self.w2.T) * (1 - z1 ** 2)
            grad_w1 = features.T @ dz1 / len(features)
            grad_b1 = dz1.mean(axis=0)

            self.w1 -= lr * grad_w1
            self.b1 -= lr * grad_b1
            self.w2 -= lr * grad_w2
            self.b2 -= lr * grad_b2

            if epoch % 50 == 0:
                loss = float(((preds - labels.reshape(-1, 1)) ** 2).mean())
                print(f"[train] epoch={epoch} loss={loss:.6f}")

    def save(self, path: Path, normalizer: FeatureNormalizer) -> None:
        payload = {
            "w1": self.w1.tolist(),
            "b1": self.b1.tolist(),
            "w2": self.w2.tolist(),
            "b2": self.b2.tolist(),
            "normalizer": normalizer.to_dict(),
        }
        path.write_text(json.dumps(payload, indent=2))

    @classmethod
    def load(cls, path: Path) -> Tuple["HybridSignalNet", FeatureNormalizer]:
        payload = json.loads(path.read_text())
        normalizer = FeatureNormalizer.from_dict(payload["normalizer"])
        instance = cls(input_dim=len(payload["w1"][0]), hidden_dim=len(payload["b1"]))
        instance.w1 = np.asarray(payload["w1"], dtype=np.float32)
        instance.b1 = np.asarray(payload["b1"], dtype=np.float32)
        instance.w2 = np.asarray(payload["w2"], dtype=np.float32)
        instance.b2 = np.asarray(payload["b2"], dtype=np.float32)
        return instance, normalizer

    def export_for_mql5(self, output_path: Path) -> None:
        """Write a lightweight weight file that the EA can parse."""
        lines = ["# HybridSignalNet Weights", str(self.w1.shape[0])]
        for row in self.w1:
            lines.append(",".join(f"{weight:.8f}" for weight in row))
        lines.append(",".join(f"{bias:.8f}" for bias in self.b1))
        lines.append(",".join(f"{weight:.8f}" for weight in self.w2.flatten()))
        lines.append(",".join(f"{bias:.8f}" for bias in self.b2.flatten()))
        output_path.write_text("\n".join(lines))
