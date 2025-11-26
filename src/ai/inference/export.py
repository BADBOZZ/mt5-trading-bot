from __future__ import annotations

from pathlib import Path

import torch

from ..config import Config
from ..models.temporal import DualStreamConfig, DualStreamTemporalModel


def export_onnx(checkpoint: Path, output_path: Path, seq_len: int = 128) -> Path:
    payload = torch.load(checkpoint, map_location="cpu")
    config = Config.from_dict(payload["config"]) if "config" in payload else Config()
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
    model.eval()
    dummy = torch.randn(1, seq_len, len(config.data.features))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        model,
        dummy,
        output_path,
        input_names=["sequence"],
        output_names=["trend", "volatility", "direction"],
        dynamic_axes={"sequence": {0: "batch", 1: "time"}},
        opset_version=13,
    )
    return output_path


def export_quantized(checkpoint: Path, output_path: Path) -> Path:
    payload = torch.load(checkpoint, map_location="cpu")
    config = Config.from_dict(payload["config"]) if "config" in payload else Config()
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
    quantized = torch.quantization.quantize_dynamic(model, {torch.nn.Linear}, dtype=torch.qint8)
    torch.save(quantized.state_dict(), output_path)
    return output_path
