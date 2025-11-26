from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Iterator


@dataclass(frozen=True)
class WalkForwardWindow:
    """Train/test ranges for one walk-forward optimization iteration."""

    train_start: datetime
    train_end: datetime
    test_start: datetime
    test_end: datetime


def _add_months(date: datetime, months: int) -> datetime:
    if months <= 0:
        return date
    month_index = date.month - 1 + months
    year = date.year + month_index // 12
    month = month_index % 12 + 1
    day = min(date.day, calendar.monthrange(year, month)[1])
    return date.replace(year=year, month=month, day=day)


def generate_walk_forward_windows(
    start: datetime,
    end: datetime,
    train_months: int,
    test_months: int,
) -> Iterator[WalkForwardWindow]:
    """Yield sequential walk-forward windows until the requested end date."""
    cursor = start
    if start >= end:
        return
    while True:
        train_end_exclusive = _add_months(cursor, train_months)
        test_start = train_end_exclusive
        test_end_exclusive = _add_months(test_start, test_months)
        if test_start >= end:
            break
        window = WalkForwardWindow(
            train_start=cursor,
            train_end=train_end_exclusive - timedelta(days=1),
            test_start=test_start,
            test_end=min(test_end_exclusive - timedelta(days=1), end),
        )
        yield window
        cursor = test_start
        if cursor >= end:
            break
