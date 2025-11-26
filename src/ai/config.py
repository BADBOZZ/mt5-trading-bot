from __future__ import annotations

from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, Iterable, Optional

import yaml


@dataclass
class DataConfig:
    lookback: int = 128
    prediction_horizon: int = 12
    max_samples: Optional[int] = None
    features: Iterable[str] = field(
        default_factory=lambda: [
            "open",
            "high",
            "low",
            "close",
            "tick_volume",
            "spread",
            "rsi",
            "ema_fast",
            "ema_slow",
            "macd",
            "volatility",
            "regime",
        ]
    )
    target: str = "future_return"
    train_split: float = 0.8
    val_split: float = 0.1


@dataclass
class ModelConfig:
    hidden_size: int = 128
    num_layers: int = 3
    dropout: float = 0.15
    pattern_kernel_size: int = 5
    attention_heads: int = 4
    use_monte_carlo_dropout: bool = True


@dataclass
class TrainingConfig:
    batch_size: int = 256
    epochs: int = 50
    learning_rate: float = 1e-3
    weight_decay: float = 1e-4
    gradient_clip: float = 1.0
    device: str = "cuda"
    mixed_precision: bool = True


@dataclass
class SignalConfig:
    buy_threshold: float = 0.52
    sell_threshold: float = 0.48
    cooldown_minutes: int = 15
    export_path: Path = Path("./artifacts/ai_signals.json")


@dataclass
class Config:
    data: DataConfig = field(default_factory=DataConfig)
    model: ModelConfig = field(default_factory=ModelConfig)
    training: TrainingConfig = field(default_factory=TrainingConfig)
    signals: SignalConfig = field(default_factory=SignalConfig)

    @staticmethod
    def from_dict(payload: Dict[str, Any]) -> "Config":
        data = payload.get("data", {})
        model = payload.get("model", {})
        training = payload.get("training", {})
        signals = payload.get("signals", {})
        return Config(
            data=DataConfig(**data),
            model=ModelConfig(**model),
            training=TrainingConfig(**training),
            signals=SignalConfig(**signals),
        )

    @staticmethod
    def load(path: Optional[Path] = None) -> "Config":
        if path is None:
            return Config()
        resolved = Path(path)
        with resolved.open("r", encoding="utf-8") as handle:
            payload = yaml.safe_load(handle)
        return Config.from_dict(payload)

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data["signals"]["export_path"] = str(self.signals.export_path)
        return data


DEFAULT_CONFIG = Config()
