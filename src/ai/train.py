"""Training pipeline for the hybrid neural network."""
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Dict

import numpy as np
import torch
from torch.optim import AdamW
from torch.optim.lr_scheduler import CosineAnnealingLR
from torch.utils.data import DataLoader

from .config import DEFAULT_CONFIG, PipelineConfig
from .datasets import train_val_test_split
from .features import build_feature_matrix, load_ohlcv
from .losses import signal_loss
from .models import HybridSignalNet


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def prepare_dataloaders(cfg: PipelineConfig):
    df = load_ohlcv(cfg.data.data_path)
    inputs, targets = build_feature_matrix(df, cfg.data)
    train_ds, val_ds, test_ds = train_val_test_split(
        inputs,
        targets,
        train_split=cfg.training.train_split,
        val_split=cfg.training.val_split,
    )
    loader_args = dict(batch_size=cfg.training.batch_size, num_workers=cfg.training.num_workers)
    train_loader = DataLoader(train_ds, shuffle=True, drop_last=True, **loader_args)
    val_loader = DataLoader(val_ds, shuffle=False, drop_last=False, **loader_args)
    test_loader = DataLoader(test_ds, shuffle=False, drop_last=False, **loader_args)
    return train_loader, val_loader, test_loader


def train(cfg: PipelineConfig) -> Dict[str, float]:
    set_seed(cfg.training.seed)
    train_loader, val_loader, test_loader = prepare_dataloaders(cfg)
    input_dim = train_loader.dataset.inputs.shape[-1]
    model = HybridSignalNet(
        input_dim=input_dim,
        hidden_dim=cfg.model.hidden_dim,
        num_classes=cfg.model.num_classes,
        regression_targets=cfg.model.regression_targets,
        kernel_size=cfg.model.temporal_kernel_size,
        dilations=tuple(cfg.model.dilations),
        num_lstm_layers=cfg.model.num_lstm_layers,
        attn_heads=cfg.model.attn_heads,
        dropout=cfg.model.dropout,
    )

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)

    optimizer = AdamW(
        model.parameters(),
        lr=cfg.training.learning_rate,
        weight_decay=cfg.training.weight_decay,
    )
    scheduler = CosineAnnealingLR(optimizer, T_max=cfg.training.epochs)

    scaler = torch.cuda.amp.GradScaler(enabled=cfg.training.mixed_precision)
    best_val = float("inf")
    patience_left = cfg.training.early_stopping_patience
    metrics: Dict[str, float] = {}

    for epoch in range(1, cfg.training.epochs + 1):
        model.train()
        running_loss = 0.0
        for batch in train_loader:
            inputs = batch.inputs.to(device)
            cls_target = batch.cls_target.to(device)
            reg_target = batch.reg_target.to(device)

            optimizer.zero_grad()
            with torch.cuda.amp.autocast(enabled=cfg.training.mixed_precision):
                outputs = model(inputs)
                loss = signal_loss(
                    outputs["logits"],
                    cls_target,
                    outputs["regression"],
                    reg_target,
                )

            scaler.scale(loss).backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.training.grad_clip)
            scaler.step(optimizer)
            scaler.update()
            running_loss += loss.item()

        scheduler.step()
        val_loss = evaluate(model, val_loader, device)
        metrics = {"train_loss": running_loss / len(train_loader), "val_loss": val_loss}

        if val_loss < best_val:
            best_val = val_loss
            patience_left = cfg.training.early_stopping_patience
            cfg.training.checkpoint_dir.mkdir(parents=True, exist_ok=True)
            torch.save({"model_state": model.state_dict(), "config": cfg}, cfg.training.checkpoint_dir / "hybrid_signal_net.pt")
        else:
            patience_left -= 1
            if patience_left <= 0:
                break

    test_loss = evaluate(model, test_loader, device)
    metrics["test_loss"] = test_loss
    summary_path = cfg.training.checkpoint_dir / "training_metrics.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    with summary_path.open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, indent=2)
    return metrics


def evaluate(model: HybridSignalNet, loader: DataLoader, device: torch.device) -> float:
    model.eval()
    loss_val = 0.0
    with torch.no_grad():
        for batch in loader:
            inputs = batch.inputs.to(device)
            cls_target = batch.cls_target.to(device)
            reg_target = batch.reg_target.to(device)
            outputs = model(inputs)
            loss = signal_loss(outputs["logits"], cls_target, outputs["regression"], reg_target)
            loss_val += loss.item()
    return loss_val / max(1, len(loader))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train the hybrid neural network model")
    parser.add_argument("--config", type=Path, default=None, help="Optional YAML config")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    cfg = PipelineConfig.from_file(args.config) if args.config else DEFAULT_CONFIG
    metrics = train(cfg)
    print(json.dumps(metrics, indent=2))
