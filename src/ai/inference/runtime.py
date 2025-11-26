from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List

import torch
from torch.utils.data import DataLoader

from ..config import Config
from ..data.market_dataset import MarketDatasetConfig, MarketSequenceDataset, load_dataset, sequence_collate
from ..features.feature_builder import FeatureBuilder
from ..models.temporal import DualStreamConfig, DualStreamTemporalModel
from ..utils.logger import get_logger


class InferenceEngine:
    def __init__(self, model: DualStreamTemporalModel, config: Config):
        self.model = model
        self.config = config
        self.logger = get_logger("inference")
        self.builder = FeatureBuilder()
        self.device = torch.device(config.training.device if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        self.model.eval()

    @classmethod
    def from_checkpoint(cls, checkpoint: Path, fallback_config: Config | None = None) -> "InferenceEngine":
        payload = torch.load(checkpoint, map_location="cpu")
        cfg_dict = payload.get("config") or (fallback_config.to_dict() if fallback_config else {})
        config = Config.from_dict(cfg_dict) if isinstance(cfg_dict, Dict) else fallback_config or Config()
        model = DualStreamTemporalModel(
            DualStreamConfig(
                input_dim=len(config.data.features),
                hidden_dim=config.model.hidden_size,
                num_layers=config.model.num_layers,
                dropout=config.model.dropout,
                pattern_kernel_size=config.model.pattern_kernel_size,
                attention_heads=config.model.attention_heads,
            )
        )
        model.load_state_dict(payload["state_dict"])
        return cls(model, config)

    def run(self, csv_path: Path, limit: int | None = 2048) -> Path:
        dataset_config = MarketDatasetConfig(
            lookback=self.config.data.lookback,
            prediction_horizon=self.config.data.prediction_horizon,
            features=self.config.data.features,
            target=self.config.data.target,
        )
        frame = load_dataset(csv_path, self.builder, dataset_config, limit)
        dataset = MarketSequenceDataset(frame, dataset_config)
        loader = DataLoader(
            dataset,
            batch_size=128,
            shuffle=False,
            collate_fn=sequence_collate,
        )
        signals: List[Dict[str, float | str]] = []
        with torch.no_grad():
            for features, _, timestamps in loader:
                features = features.to(self.device)
                trend, volatility, direction = self.model(features)
                for idx in range(features.size(0)):
                    buy_score = float(direction[idx].item())
                    sell_score = 1 - buy_score
                    if buy_score >= self.config.signals.buy_threshold:
                        action = "BUY"
                    elif buy_score <= self.config.signals.sell_threshold:
                        action = "SELL"
                    else:
                        action = "HOLD"
                    signal = {
                        "timestamp": str(timestamps[idx]),
                        "buy_score": buy_score,
                        "sell_score": sell_score,
                        "trend": float(trend[idx].item()),
                        "volatility": float(volatility[idx].item()),
                        "action": action,
                    }
                    signals.append(signal)
        export_path = Path(self.config.signals.export_path)
        export_path.parent.mkdir(parents=True, exist_ok=True)
        export_path.write_text(
            json.dumps(
                {
                    "config": self.config.to_dict(),
                    "generated_at": signals[-1]["timestamp"] if signals else None,
                    "signals": signals[-100:],
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        self._write_csv(export_path.with_suffix(".csv"), signals[-100:])
        self.logger.info("Exported %s signals to %s", len(signals[-100:]), export_path)
        return export_path

    def _write_csv(self, path: Path, signals: List[Dict[str, float | str]]) -> None:
        lines = ["timestamp,buy_score,sell_score,trend,volatility,action"]
        for signal in signals:
            lines.append(
                ",".join(
                    [
                        signal["timestamp"],
                        f"{signal['buy_score']:.4f}",
                        f"{signal['sell_score']:.4f}",
                        f"{signal['trend']:.5f}",
                        f"{signal['volatility']:.5f}",
                        signal["action"],
                    ]
                )
            )
        path.write_text("\n".join(lines), encoding="utf-8")
