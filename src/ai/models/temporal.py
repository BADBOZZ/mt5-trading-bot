from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Tuple

import torch
from torch import nn


class TemporalConv(nn.Module):
    def __init__(self, input_dim: int, hidden_dim: int, kernel_size: int = 5):
        super().__init__()
        padding = kernel_size // 2
        self.conv = nn.Conv1d(input_dim, hidden_dim, kernel_size, padding=padding)
        self.bn = nn.BatchNorm1d(hidden_dim)
        self.activation = nn.SiLU()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: batch x time x feat
        x = x.transpose(1, 2)
        y = self.activation(self.bn(self.conv(x)))
        return y.transpose(1, 2)


class AttentionBlock(nn.Module):
    def __init__(self, hidden_dim: int, heads: int):
        super().__init__()
        self.heads = heads
        self.scale = (hidden_dim // heads) ** -0.5
        self.qkv = nn.Linear(hidden_dim, hidden_dim * 3)
        self.proj = nn.Linear(hidden_dim, hidden_dim)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        b, t, h = x.size()
        qkv = self.qkv(x).reshape(b, t, 3, self.heads, h // self.heads)
        q, k, v = qkv.unbind(dim=2)
        q = q * self.scale
        scores = torch.einsum("bthd,bThd->bhtT", q, k)
        weights = torch.softmax(scores, dim=-1)
        attn = torch.einsum("bhtT,bThd->bthd", weights, v).reshape(b, t, h)
        return self.proj(attn)


class SignalHead(nn.Module):
    def __init__(self, hidden_dim: int):
        super().__init__()
        self.linear = nn.Sequential(
            nn.LayerNorm(hidden_dim),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.SiLU(),
            nn.Linear(hidden_dim // 2, 3),
        )

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        logits = self.linear(x[:, -1])
        trend = torch.tanh(logits[:, 0])
        volatility = torch.nn.functional.softplus(logits[:, 1])
        direction = torch.sigmoid(logits[:, 2])
        return trend, volatility, direction


@dataclass
class DualStreamConfig:
    input_dim: int
    hidden_dim: int = 128
    num_layers: int = 2
    dropout: float = 0.1
    pattern_kernel_size: int = 5
    attention_heads: int = 4


class DualStreamTemporalModel(nn.Module):
    def __init__(self, config: DualStreamConfig):
        super().__init__()
        self.config = config
        self.lstm = nn.LSTM(
            input_size=config.input_dim,
            hidden_size=config.hidden_dim,
            num_layers=config.num_layers,
            dropout=config.dropout,
            batch_first=True,
        )
        self.temporal_conv = TemporalConv(config.input_dim, config.hidden_dim, config.pattern_kernel_size)
        self.attention = AttentionBlock(config.hidden_dim * 2, config.attention_heads)
        self.head = SignalHead(config.hidden_dim * 2)
        self.dropout = nn.Dropout(config.dropout)

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        lstm_out, _ = self.lstm(x)
        conv_out = self.temporal_conv(x)
        merged = torch.cat([lstm_out, conv_out], dim=-1)
        context = self.attention(self.dropout(merged)) + merged
        return self.head(context)


def monte_carlo_dropout(model: nn.Module, x: torch.Tensor, passes: int = 20):
    model.train()
    outputs = [model(x)[2].detach() for _ in range(passes)]
    stacked = torch.stack(outputs)
    mean = stacked.mean(dim=0)
    std = stacked.std(dim=0)
    return mean, std
