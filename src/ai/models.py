"""Neural network architectures for hybrid market modeling."""
from __future__ import annotations

from typing import Dict, Tuple

import torch
import torch.nn as nn
import torch.nn.functional as F


class LayerNorm1d(nn.Module):
    def __init__(self, channels: int):
        super().__init__()
        self.norm = nn.LayerNorm(channels)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        b, c, t = x.shape
        x = x.permute(0, 2, 1)
        x = self.norm(x)
        return x.permute(0, 2, 1)


class GatedResidualBlock(nn.Module):
    def __init__(self, channels: int, kernel_size: int, dilation: int, dropout: float):
        super().__init__()
        self.pad = (kernel_size - 1) * dilation
        self.conv = nn.Conv1d(
            channels,
            channels * 2,
            kernel_size=kernel_size,
            padding=self.pad,
            dilation=dilation,
        )
        self.dropout = nn.Dropout(dropout)
        self.norm = LayerNorm1d(channels)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        residual = x
        out = self.conv(x)
        if self.pad > 0:
            out = out[:, :, :-self.pad]
        gate, value = out.chunk(2, dim=1)
        out = torch.tanh(value) * torch.sigmoid(gate)
        out = self.dropout(out)
        return self.norm(out + residual)


class AttentionPooling(nn.Module):
    def __init__(self, channels: int, heads: int):
        super().__init__()
        self.scale = channels ** -0.5
        self.query = nn.Parameter(torch.randn(heads, channels))
        self.proj = nn.Linear(channels, channels)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: [B, T, C]
        scores = torch.einsum("btc,hc->bth", x, self.query) * self.scale
        attn = torch.softmax(scores, dim=1)
        pooled = torch.einsum("bth,btc->bhc", attn, x)
        pooled = pooled.mean(dim=1)
        return self.proj(pooled)


class HybridSignalNet(nn.Module):
    def __init__(
        self,
        input_dim: int,
        hidden_dim: int,
        num_classes: int,
        regression_targets: int,
        kernel_size: int = 5,
        dilations: Tuple[int, ...] = (1, 2, 4, 8),
        num_lstm_layers: int = 2,
        attn_heads: int = 4,
        dropout: float = 0.15,
    ) -> None:
        super().__init__()
        self.proj = nn.Linear(input_dim, hidden_dim)
        self.residual_blocks = nn.ModuleList(
            [
                GatedResidualBlock(hidden_dim, kernel_size=kernel_size, dilation=d, dropout=dropout)
                for d in dilations
            ]
        )
        self.temporal_dropout = nn.Dropout(dropout)
        self.lstm = nn.LSTM(
            input_size=hidden_dim,
            hidden_size=hidden_dim,
            num_layers=num_lstm_layers,
            batch_first=True,
            dropout=dropout,
        )
        self.attn_pool = AttentionPooling(hidden_dim, attn_heads)
        self.classifier = nn.Sequential(
            nn.LayerNorm(hidden_dim),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.ELU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim // 2, num_classes),
        )
        self.regressor = nn.Sequential(
            nn.LayerNorm(hidden_dim),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.SiLU(),
            nn.Linear(hidden_dim // 2, regression_targets),
        )

    def encode(self, x: torch.Tensor) -> torch.Tensor:
        # x: [B, T, F]
        h = self.proj(x)
        h = h.transpose(1, 2)  # [B, C, T]
        for block in self.residual_blocks:
            h = block(h)
        h = self.temporal_dropout(h)
        h = h.transpose(1, 2)
        lstm_out, _ = self.lstm(h)
        return lstm_out

    def forward(self, x: torch.Tensor) -> Dict[str, torch.Tensor]:
        encoded = self.encode(x)
        pooled = self.attn_pool(encoded)
        logits = self.classifier(pooled)
        regression = self.regressor(pooled)
        return {"logits": logits, "regression": regression}

    def infer(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:  # pragma: no cover
        self.eval()
        with torch.no_grad():
            outputs = self.forward(x)
            probs = F.softmax(outputs["logits"], dim=-1)
            return probs, outputs["regression"]
