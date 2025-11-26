"""Configuration dataclasses for AI training and inference."""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional
import yaml


@dataclass
class DataConfig:
    data_path: Path = Path("data/historical_ohlcv.csv")
    cache_dir: Path = Path("artifacts/cache")
    window_size: int = 256
    prediction_horizon: int = 12  # bars ahead
    feature_set: List[str] = field(
        default_factory=lambda: [
            "close",
            "volume",
            "returns",
            "ema_fast",
            "ema_slow",
            "rsi",
            "atr",
            "stoch",
            "roc",
            "bb_width",
        ]
    )
    target_smoothing: float = 0.2


@dataclass
class ModelConfig:
    input_dim: int = 64
    hidden_dim: int = 256
    temporal_kernel_size: int = 5
    dilations: List[int] = field(default_factory=lambda: [1, 2, 4, 8])
    num_lstm_layers: int = 2
    attn_heads: int = 4
    dropout: float = 0.15
    num_classes: int = 3  # short, flat, long
    regression_targets: int = 2  # e.g. volatility + expected return


@dataclass
class TrainingConfig:
    epochs: int = 50
    batch_size: int = 64
    learning_rate: float = 1e-3
    weight_decay: float = 1e-4
    lr_warmup_steps: int = 500
    grad_clip: float = 1.0
    optimizer: str = "adamw"
    checkpoint_dir: Path = Path("artifacts/models")
    mixed_precision: bool = True
    early_stopping_patience: int = 8
    train_split: float = 0.8
    val_split: float = 0.1
    num_workers: int = 4
    seed: int = 1337


@dataclass
class InferenceConfig:
    model_path: Path = Path("artifacts/models/hybrid_signal_net.pt")
    onnx_path: Path = Path("artifacts/models/hybrid_signal_net.onnx")
    signal_output: Path = Path("artifacts/signals/ai_signals.csv")
    min_confidence: float = 0.55
    smoothing_beta: float = 0.65


@dataclass
class PipelineConfig:
    data: DataConfig = DataConfig()
    model: ModelConfig = ModelConfig()
    training: TrainingConfig = TrainingConfig()
    inference: InferenceConfig = InferenceConfig()

    @classmethod
    def from_file(cls, path: Path | str) -> "PipelineConfig":
        with open(path, "r", encoding="utf-8") as f:
            raw = yaml.safe_load(f)
        return cls(
            data=DataConfig(**raw.get("data", {})),
            model=ModelConfig(**raw.get("model", {})),
            training=TrainingConfig(**raw.get("training", {})),
            inference=InferenceConfig(**raw.get("inference", {})),
        )


DEFAULT_CONFIG = PipelineConfig()
