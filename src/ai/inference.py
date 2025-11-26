"""Offline inference utilities for writing MT5-readable signals."""
from __future__ import annotations

import csv
import json
from datetime import datetime
from pathlib import Path
from typing import Dict

import numpy as np
import torch

from .config import DEFAULT_CONFIG, PipelineConfig
from .features import build_feature_matrix, load_ohlcv
from .models import HybridSignalNet


SIGNAL_MAP = {0: "short", 1: "flat", 2: "long"}


def load_model(cfg: PipelineConfig) -> HybridSignalNet:
    checkpoint = torch.load(cfg.inference.model_path, map_location="cpu")
    state = checkpoint["model_state"] if "model_state" in checkpoint else checkpoint
    sample_df = load_ohlcv(cfg.data.data_path)
    inputs, _ = build_feature_matrix(sample_df, cfg.data)
    input_dim = inputs.shape[-1]
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
    model.load_state_dict(state)
    model.eval()
    return model


def infer_latest(cfg: PipelineConfig) -> Dict[str, float | str]:
    df = load_ohlcv(cfg.data.data_path)
    inputs, _ = build_feature_matrix(df, cfg.data)
    latest_window = torch.from_numpy(inputs[-1:]).float()
    model = load_model(cfg)
    with torch.no_grad():
        outputs = model(latest_window)
        probs = torch.softmax(outputs["logits"], dim=-1).squeeze(0)
        regression = outputs["regression"].squeeze(0)
    confidence, idx = torch.max(probs, dim=-1)
    signal = SIGNAL_MAP[int(idx)]
    conf_val = float(confidence)
    delta, volatility = regression.tolist()
    return {
        "timestamp": datetime.utcnow().isoformat(),
        "signal": signal,
        "confidence": conf_val,
        "expected_return": float(delta),
        "volatility": float(volatility),
        "prob_short": float(probs[0]),
        "prob_flat": float(probs[1]),
        "prob_long": float(probs[2]),
    }


def write_signal_csv(signal: Dict[str, float | str], cfg: PipelineConfig) -> Path:
    path = cfg.inference.signal_output
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "timestamp",
                "signal",
                "confidence",
                "expected_return",
                "volatility",
                "prob_short",
                "prob_flat",
                "prob_long",
            ],
        )
        writer.writeheader()
        writer.writerow(signal)
    return path


def main(config_path: Path | None = None) -> Path:
    cfg = PipelineConfig.from_file(config_path) if config_path else DEFAULT_CONFIG
    signal = infer_latest(cfg)
    write_signal_csv(signal, cfg)
    json_path = cfg.inference.signal_output.with_suffix(".json")
    with json_path.open("w", encoding="utf-8") as fh:
        json.dump(signal, fh, indent=2)
    return cfg.inference.signal_output


if __name__ == "__main__":
    file_path = main()
    print(f"Signal written to {file_path}")
