from __future__ import annotations

from dataclasses import dataclass

import torch
from torch import nn


@dataclass
class PatternModelConfig:
    input_dim: int
    channels: int = 32
    depth: int = 3
    kernel_size: int = 3


class PatternRecognitionNet(nn.Module):
    def __init__(self, config: PatternModelConfig):
        super().__init__()
        layers = []
        in_channels = config.input_dim
        for _ in range(config.depth):
            layers.append(nn.Conv1d(in_channels, config.channels, config.kernel_size, padding=config.kernel_size // 2))
            layers.append(nn.BatchNorm1d(config.channels))
            layers.append(nn.SiLU())
            in_channels = config.channels
        self.body = nn.Sequential(*layers)
        self.head = nn.Sequential(
            nn.AdaptiveMaxPool1d(1),
            nn.Flatten(),
            nn.Linear(config.channels, 4),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = x.transpose(1, 2)
        encoded = self.body(x)
        logits = self.head(encoded)
        return torch.softmax(logits, dim=-1)
