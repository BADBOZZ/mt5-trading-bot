"""Datasets and dataloaders for sequence modeling."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple

import numpy as np
import torch
from torch.utils.data import Dataset


@dataclass
class MarketSequence:
    inputs: torch.Tensor
    cls_target: torch.Tensor
    reg_target: torch.Tensor


class SequenceDataset(Dataset):
    def __init__(self, inputs: np.ndarray, targets: np.ndarray):
        cls_target = targets[:, 0].astype(np.int64)
        reg_target = targets[:, 1:].astype(np.float32)
        self.inputs = torch.from_numpy(inputs).float()
        self.cls_target = torch.from_numpy(cls_target)
        self.reg_target = torch.from_numpy(reg_target)

    def __len__(self) -> int:  # pragma: no cover - trivial
        return len(self.inputs)

    def __getitem__(self, idx: int) -> MarketSequence:
        return MarketSequence(
            inputs=self.inputs[idx],
            cls_target=self.cls_target[idx],
            reg_target=self.reg_target[idx],
        )


def train_val_test_split(
    inputs: np.ndarray,
    targets: np.ndarray,
    train_split: float,
    val_split: float,
) -> Tuple[SequenceDataset, SequenceDataset, SequenceDataset]:
    n = len(inputs)
    train_end = int(n * train_split)
    val_end = int(n * (train_split + val_split))

    train = SequenceDataset(inputs[:train_end], targets[:train_end])
    val = SequenceDataset(inputs[train_end:val_end], targets[train_end:val_end])
    test = SequenceDataset(inputs[val_end:], targets[val_end:])
    return train, val, test
