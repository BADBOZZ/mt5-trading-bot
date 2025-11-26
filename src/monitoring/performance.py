from __future__ import annotations

import time
from contextlib import ContextDecorator
from typing import Dict, Optional

from .events import MetricPoint

if False:  # pragma: no cover - avoid circular import during runtime
    from .manager import MonitoringManager


class PerformanceTimer(ContextDecorator):
    """Context manager/decorator for recording execution latency."""

    def __init__(
        self,
        manager: "MonitoringManager",
        name: str,
        *,
        threshold_ms: Optional[float] = None,
        tags: Optional[Dict[str, str]] = None,
    ) -> None:
        self.manager = manager
        self.name = name
        self.threshold_ms = threshold_ms
        self.tags = tags or {}
        self._start: Optional[float] = None

    def __enter__(self) -> "PerformanceTimer":
        self._start = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc, exc_tb) -> None:
        if self._start is None:
            return
        elapsed_ms = (time.perf_counter() - self._start) * 1000
        self.manager.track_metric(
            MetricPoint(
                name=f"latency.{self.name}",
                value=elapsed_ms,
                unit="ms",
                tags=self.tags,
            )
        )
        if self.threshold_ms and elapsed_ms > self.threshold_ms:
            self.manager.raise_performance_alert(
                name=self.name, elapsed_ms=elapsed_ms, threshold_ms=self.threshold_ms
            )
        return None
