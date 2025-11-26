from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Sequence

import numpy as np
import pandas as pd
import torch
from torch.utils.data import Dataset

from ..features.feature_builder import FeatureBuilder


@dataclass
class MarketDatasetConfig:
    lookback: int
    prediction_horizon: int
    features: Sequence[str]
    target: str


class MarketSequenceDataset(Dataset):
    def __init__(self, frame: pd.DataFrame, config: MarketDatasetConfig):
        self.frame = frame.reset_index(drop=True)
        self.config = config
        self.feature_array = self.frame[self.config.features].values.astype(np.float32)
        self.target_array = self.frame[self.config.target].values.astype(np.float32)
        self.timestamps = self.frame["timestamp"].values
        self.indices = self._build_indices()

    def __len__(self) -> int:
        return len(self.indices)

    def __getitem__(self, idx: int):
        start = self.indices[idx]
        end = start + self.config.lookback
        features = torch.from_numpy(self.feature_array[start:end])
        target = torch.tensor(self.target_array[end - 1], dtype=torch.float32)
        timestamp = self.timestamps[end - 1]
        return features, target, timestamp

    def _build_indices(self) -> List[int]:
        total = len(self.frame) - self.config.lookback - self.config.prediction_horizon
        return list(range(total))


def load_dataset(
    path: Path,
    builder: FeatureBuilder,
    config: MarketDatasetConfig,
    limit: int | None = None,
) -> pd.DataFrame:
    frame = pd.read_csv(path, parse_dates=["timestamp"])
    if limit:
        frame = frame.tail(limit)
    return builder.transform(frame)


def train_val_test_split(
    dataset: MarketSequenceDataset,
    train_split: float,
    val_split: float,
):
    total = len(dataset)
    train_end = int(total * train_split)
    val_end = train_end + int(total * val_split)
    indices = torch.randperm(total).tolist()
    train_idx = indices[:train_end]
    val_idx = indices[train_end:val_end]
    test_idx = indices[val_end:]
    return train_idx, val_idx, test_idx


def sequence_collate(batch):
    features, targets, timestamps = zip(*batch)
    return torch.stack(features), torch.stack(targets), list(timestamps)
