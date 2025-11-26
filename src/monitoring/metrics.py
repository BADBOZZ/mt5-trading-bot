from __future__ import annotations

import statistics
import threading
from collections import Counter, deque
from typing import Deque, Dict, Iterable, List, Optional, Tuple

from .events import MetricPoint


class MetricStore:
    """Thread-safe storage for recent metric points."""

    def __init__(self, retention: int = 5000) -> None:
        self._retention = retention
        self._metrics: Dict[str, Deque[MetricPoint]] = {}
        self._lock = threading.Lock()

    def add(self, point: MetricPoint) -> None:
        with self._lock:
            bucket = self._metrics.setdefault(point.name, deque(maxlen=self._retention))
            bucket.append(point)

    def latest(self, name: str) -> Optional[MetricPoint]:
        with self._lock:
            bucket = self._metrics.get(name)
            if not bucket:
                return None
            return bucket[-1]

    def summarize(self, name: str) -> Optional[Dict[str, float]]:
        with self._lock:
            bucket = self._metrics.get(name)
            if not bucket:
                return None
            values = [p.value for p in bucket]
            return {
                "count": len(values),
                "min": min(values),
                "max": max(values),
                "avg": statistics.fmean(values),
                "p95": _percentile(values, 95),
                "p99": _percentile(values, 99),
            }

    def snapshot(self) -> Dict[str, List[Dict[str, float]]]:
        with self._lock:
            snap: Dict[str, List[Dict[str, float]]] = {}
            for name, points in self._metrics.items():
                snap[name] = [
                    {
                        "value": p.value,
                        "unit": p.unit,
                        "timestamp": p.timestamp.isoformat(),
                        **p.tags,
                    }
                    for p in points
                ]
            return snap

    def top_values(self, name: str, limit: int = 5) -> List[Tuple[float, int]]:
        with self._lock:
            bucket = self._metrics.get(name)
            if not bucket:
                return []
            counter = Counter(round(p.value, 4) for p in bucket)
            return counter.most_common(limit)


def _percentile(values: Iterable[float], percentile: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    k = (len(ordered) - 1) * (percentile / 100.0)
    f = int(k)
    c = min(f + 1, len(ordered) - 1)
    if f == c:
        return ordered[int(k)]
    d0 = ordered[f] * (c - k)
    d1 = ordered[c] * (k - f)
    return d0 + d1
