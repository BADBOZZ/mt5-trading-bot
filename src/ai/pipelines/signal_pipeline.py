from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
from typing import Dict, Optional, Tuple

import torch
import torch.nn.functional as F
from torch.utils.data import DataLoader, Subset

from ..config import Config
from ..data.market_dataset import (
    MarketDatasetConfig,
    MarketSequenceDataset,
    load_dataset,
    sequence_collate,
    train_val_test_split,
)
from ..features.feature_builder import FeatureBuilder
from ..models.temporal import DualStreamConfig, DualStreamTemporalModel
from ..utils.logger import get_logger


class SignalPipeline:
    def __init__(self, config: Config):
        self.config = config
        self.logger = get_logger("signal-pipeline")
        self.builder = FeatureBuilder()
        self.device = torch.device(config.training.device if torch.cuda.is_available() else "cpu")

    def _dataset_config(self) -> MarketDatasetConfig:
        return MarketDatasetConfig(
            lookback=self.config.data.lookback,
            prediction_horizon=self.config.data.prediction_horizon,
            features=self.config.data.features,
            target=self.config.data.target,
        )

    def _create_dataloaders(self, csv_path: Path) -> Tuple[DataLoader, DataLoader, DataLoader]:
        frame = load_dataset(csv_path, self.builder, self._dataset_config(), self.config.data.max_samples)
        dataset = MarketSequenceDataset(frame, self._dataset_config())
        train_idx, val_idx, test_idx = train_val_test_split(
            dataset,
            self.config.data.train_split,
            self.config.data.val_split,
        )
        train_loader = DataLoader(
            Subset(dataset, train_idx),
            batch_size=self.config.training.batch_size,
            shuffle=True,
            collate_fn=sequence_collate,
        )
        val_loader = DataLoader(
            Subset(dataset, val_idx),
            batch_size=self.config.training.batch_size,
            shuffle=False,
            collate_fn=sequence_collate,
        )
        test_loader = DataLoader(
            Subset(dataset, test_idx),
            batch_size=self.config.training.batch_size,
            shuffle=False,
            collate_fn=sequence_collate,
        )
        return train_loader, val_loader, test_loader

    def _build_model(self) -> DualStreamTemporalModel:
        model = DualStreamTemporalModel(
            DualStreamConfig(
                input_dim=len(self.config.data.features),
                hidden_dim=self.config.model.hidden_size,
                num_layers=self.config.model.num_layers,
                dropout=self.config.model.dropout,
                pattern_kernel_size=self.config.model.pattern_kernel_size,
                attention_heads=self.config.model.attention_heads,
            )
        )
        return model.to(self.device)

    def train(self, csv_path: Path, checkpoint_path: Optional[Path] = None) -> Dict[str, float]:
        train_loader, val_loader, test_loader = self._create_dataloaders(csv_path)
        model = self._build_model()
        optimizer = torch.optim.AdamW(
            model.parameters(),
            lr=self.config.training.learning_rate,
            weight_decay=self.config.training.weight_decay,
        )
        scaler = torch.cuda.amp.GradScaler(enabled=self.config.training.mixed_precision)
        best_val = float("inf")
        best_state = None

        for epoch in range(self.config.training.epochs):
            model.train()
            train_loss = 0.0
            for features, target, _ in train_loader:
                features, target = features.to(self.device), target.to(self.device)
                optimizer.zero_grad(set_to_none=True)
                with torch.cuda.amp.autocast(enabled=self.config.training.mixed_precision):
                    trend, volatility, direction = model(features)
                    direction_target = (target > 0).float()
                    volatility_target = target.abs().clamp(max=0.02)
                    loss = (
                        F.smooth_l1_loss(trend.squeeze(), target)
                        + 0.2 * F.mse_loss(volatility.squeeze(), volatility_target)
                        + 0.8 * F.binary_cross_entropy(direction.squeeze(), direction_target)
                    )
                scaler.scale(loss).backward()
                torch.nn.utils.clip_grad_norm_(model.parameters(), self.config.training.gradient_clip)
                scaler.step(optimizer)
                scaler.update()
                train_loss += loss.item() * features.size(0)
            train_loss /= len(train_loader.dataset)

            val_loss = self._evaluate(model, val_loader)
            self.logger.info("epoch=%s train=%.4f val=%.4f", epoch + 1, train_loss, val_loss)
            if val_loss < best_val:
                best_val = val_loss
                best_state = model.state_dict()

        if best_state is None:
            raise RuntimeError("Training did not produce a valid model state.")
        model.load_state_dict(best_state)
        test_loss = self._evaluate(model, test_loader)
        stats = {"val_loss": best_val, "test_loss": test_loss}
        artifacts_dir = Path("artifacts")
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        target_checkpoint = checkpoint_path or artifacts_dir / "model_checkpoint.pt"
        Path(target_checkpoint).parent.mkdir(parents=True, exist_ok=True)
        torch.save(
            {
                "state_dict": best_state,
                "config": asdict(self.config),
                "metrics": stats,
            },
            target_checkpoint,
        )
        self.logger.info("Best metrics: %s", stats)
        return stats

    def _evaluate(self, model: DualStreamTemporalModel, loader: DataLoader) -> float:
        model.eval()
        loss = 0.0
        with torch.no_grad():
            for features, target, _ in loader:
                features, target = features.to(self.device), target.to(self.device)
                trend, volatility, direction = model(features)
                direction_target = (target > 0).float()
                volatility_target = target.abs().clamp(max=0.02)
                batch_loss = (
                    F.smooth_l1_loss(trend.squeeze(), target)
                    + 0.2 * F.mse_loss(volatility.squeeze(), volatility_target)
                    + 0.8 * F.binary_cross_entropy(direction.squeeze(), direction_target)
                )
                loss += batch_loss.item() * features.size(0)
        return loss / len(loader.dataset)

    def generate_signals(self, csv_path: Path, checkpoint: Path) -> Path:
        from ..inference.runtime import InferenceEngine

        engine = InferenceEngine.from_checkpoint(checkpoint, self.config)
        return engine.run(csv_path)
