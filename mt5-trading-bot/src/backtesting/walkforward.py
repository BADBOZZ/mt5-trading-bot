"""
Utilities to build walk-forward schedules that stay in sync with the
Strategy Tester walk-forward logic implemented in the MQL5 layer.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Sequence

import json


@dataclass
class WalkForwardWindow:
    in_start: datetime
    in_end: datetime
    out_start: datetime
    out_end: datetime

    def as_tuple(self) -> tuple[datetime, datetime, datetime, datetime]:
        return self.in_start, self.in_end, self.out_start, self.out_end


class WalkForwardPlanner:
    """Generate rolling in-sample/out-of-sample windows."""

    def __init__(self, in_sample_days: int = 90, out_sample_days: int = 30) -> None:
        if in_sample_days <= 0 or out_sample_days <= 0:
            raise ValueError("Sample sizes must be positive.")
        self.in_sample_days = in_sample_days
        self.out_sample_days = out_sample_days

    def generate(self, start: datetime, end: datetime) -> List[WalkForwardWindow]:
        windows: List[WalkForwardWindow] = []
        cursor = start
        delta_in = timedelta(days=self.in_sample_days)
        delta_out = timedelta(days=self.out_sample_days)
        while cursor + delta_in + delta_out <= end:
            window = WalkForwardWindow(
                in_start=cursor,
                in_end=cursor + delta_in,
                out_start=cursor + delta_in,
                out_end=cursor + delta_in + delta_out,
            )
            windows.append(window)
            cursor += delta_out
        if not windows:
            raise ValueError("Walk-forward plan is empty; extend the date range.")
        return windows


def serialize_plan(windows: Sequence[WalkForwardWindow], path: Path) -> None:
    payload = [
        {
            "in_start": win.in_start.isoformat(),
            "in_end": win.in_end.isoformat(),
            "out_start": win.out_start.isoformat(),
            "out_end": win.out_end.isoformat(),
        }
        for win in windows
    ]
    path.write_text(json.dumps(payload, indent=2))


def load_plan(path: Path) -> List[WalkForwardWindow]:
    payload = json.loads(path.read_text())
    windows = [
        WalkForwardWindow(
            in_start=datetime.fromisoformat(row["in_start"]),
            in_end=datetime.fromisoformat(row["in_end"]),
            out_start=datetime.fromisoformat(row["out_start"]),
            out_end=datetime.fromisoformat(row["out_end"]),
        )
        for row in payload
    ]
    return windows
