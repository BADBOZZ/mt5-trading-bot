"""Walk-forward segmentation utilities for the MT5 Strategy Tester."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
from typing import List, Sequence

from .config import StrategyTesterConfig, WalkForwardWindow


@dataclass
class SlidingWindowWalkForward:
    """Build fixed-width walk-forward windows, sliding across the date range."""

    config: StrategyTesterConfig
    train_days: int
    test_days: int
    step_days: int | None = None

    def build_windows(self) -> Sequence[WalkForwardWindow]:
        start = self.config.start
        end = self.config.end
        cursor = start
        windows: List[WalkForwardWindow] = []
        step = self.step_days or self.test_days

        while cursor + timedelta(days=self.train_days + self.test_days) <= end:
            train_start = cursor
            train_end = cursor + timedelta(days=self.train_days)
            test_start = train_end
            test_end = test_start + timedelta(days=self.test_days)

            windows.append(
                WalkForwardWindow(
                    train_start=train_start,
                    train_end=train_end,
                    test_start=test_start,
                    test_end=test_end,
                )
            )
            cursor += timedelta(days=step)

        return windows


__all__ = ["SlidingWindowWalkForward"]
