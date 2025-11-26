"""Export utilities for deploying the trained model."""
from __future__ import annotations

from pathlib import Path

import torch

from .config import DEFAULT_CONFIG, PipelineConfig
from .features import build_feature_matrix, load_ohlcv
from .models import HybridSignalNet


def export_onnx(cfg: PipelineConfig) -> Path:
    checkpoint = torch.load(cfg.inference.model_path, map_location="cpu")
    state = checkpoint["model_state"] if "model_state" in checkpoint else checkpoint
    df = load_ohlcv(cfg.data.data_path)
    inputs, _ = build_feature_matrix(df, cfg.data)
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

    dummy = torch.randn(1, cfg.data.window_size, input_dim)
    onnx_path = cfg.inference.onnx_path
    onnx_path.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        model,
        dummy,
        onnx_path,
        input_names=["input"],
        output_names=["logits", "regression"],
        dynamic_axes={"input": {0: "batch", 1: "window"}},
        opset_version=17,
    )
    return onnx_path


def main(config_path: Path | None = None) -> Path:
    cfg = PipelineConfig.from_file(config_path) if config_path else DEFAULT_CONFIG
    path = export_onnx(cfg)
    print(f"Exported model to {path}")
    return path


if __name__ == "__main__":
    main()
