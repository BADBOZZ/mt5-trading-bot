"""Walk-forward planning helpers for the MT5 Strategy Tester."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List


@dataclass(frozen=True)
class WalkForwardSlice:
    """Represents one in-sample/out-of-sample iteration."""

    insample_start: datetime
    insample_end: datetime
    outsample_start: datetime
    outsample_end: datetime


@dataclass
class WalkForwardPlan:
    """Collection of walk-forward slices."""

    slices: List[WalkForwardSlice]

    def to_mt5_forward_mode(self) -> str:
        """Provide a readable summary for the Strategy Tester comment."""

        return "; ".join(
            f"In-sample {sl.insample_start:%Y-%m-%d}->{sl.insample_end:%Y-%m-%d} | "
            f"Out-of-sample {sl.outsample_start:%Y-%m-%d}->{sl.outsample_end:%Y-%m-%d}"
            for sl in self.slices
        )

    @property
    def iterations(self) -> int:
        return len(self.slices)


def build_walk_forward_plan(
    start: datetime,
    end: datetime,
    insample_days: int,
    outsample_days: int,
    step_days: int | None = None,
) -> WalkForwardPlan:
    """Generate rolling walk-forward windows that MT5 can replay."""

    if start >= end:
        raise ValueError("start must be earlier than end")
    if insample_days <= 0 or outsample_days <= 0:
        raise ValueError("window sizes must be positive")

    step = step_days or outsample_days
    slices: List[WalkForwardSlice] = []
    window_start = start

    while True:
        insample_start = window_start
        insample_end = insample_start + timedelta(days=insample_days)
        outsample_start = insample_end
        outsample_end = outsample_start + timedelta(days=outsample_days)

        if outsample_end > end:
            break

        slices.append(
            WalkForwardSlice(
                insample_start=insample_start,
                insample_end=insample_end,
                outsample_start=outsample_start,
                outsample_end=outsample_end,
            )
        )

        window_start = window_start + timedelta(days=step)

    if not slices:
        raise ValueError("walk-forward configuration produced no slices")

    return WalkForwardPlan(slices=slices)
