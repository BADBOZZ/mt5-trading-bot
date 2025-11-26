"""Walk-forward helpers to validate optimised parameter sets."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Sequence, Tuple

import pandas as pd


@dataclass(slots=True)
class WalkForwardWindow:
    """Represents one contiguous train/test slice."""

    train_start: pd.Timestamp
    train_end: pd.Timestamp
    test_start: pd.Timestamp
    test_end: pd.Timestamp

    def __repr__(self) -> str:  # pragma: no cover - debugging helper
        return (
            f"WalkForwardWindow(train={self.train_start:%Y-%m-%d}->{self.train_end:%Y-%m-%d}, "
            f"test={self.test_start:%Y-%m-%d}->{self.test_end:%Y-%m-%d})"
        )


def _ensure_index(data: Sequence | pd.DataFrame | pd.Series) -> pd.Index:
    """Coerce arbitrary inputs into a pandas timestamp index."""
    if isinstance(data, (pd.Series, pd.DataFrame)):
        return pd.Index(data.index)
    return pd.Index(data)


def generate_windows(
    data: Sequence | pd.DataFrame | pd.Series,
    train_size: int,
    test_size: int,
    step_size: int | None = None,
) -> List[WalkForwardWindow]:
    """Create rolling walk-forward windows.

    Args:
        data: Any object providing a pandas-compatible index (the trading timeline).
        train_size: Number of bars inside the optimisation window.
        test_size: Number of bars inside the forward-validation window.
        step_size: Optional stride. Defaults to `test_size`.
    """
    index = _ensure_index(data)
    if len(index) < train_size + test_size:
        raise ValueError("Dataset too short for the requested walk-forward sizes")

    step = step_size or test_size
    cursor = 0
    windows: List[WalkForwardWindow] = []

    while cursor + train_size + test_size <= len(index):
        train_slice = index[cursor : cursor + train_size]
        test_slice = index[cursor + train_size : cursor + train_size + test_size]
        windows.append(
            WalkForwardWindow(
                train_start=train_slice[0],
                train_end=train_slice[-1],
                test_start=test_slice[0],
                test_end=test_slice[-1],
            )
        )
        cursor += step
    return windows


def slice_frame(frame: pd.DataFrame, window: WalkForwardWindow) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """Return train/test splits for a dataframe based on a window definition."""
    train = frame.loc[window.train_start : window.train_end]
    test = frame.loc[window.test_start : window.test_end]
    return train, test
