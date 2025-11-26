"""High-level performance telemetry helpers.

This module acts as a thin shim between the Python orchestration layer and the
new MQL5 monitoring libraries.  The intent is to prepare well-structured
snapshots so that the MT5 scripts can be fed with up-to-date account state
without forcing the rest of the codebase to know anything about MetaTrader
internals.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from datetime import datetime
from typing import Deque, Dict, Iterable, Optional

MQL_LOGGER_LIB = "src/monitoring/Logger.mq5"
MQL_ALERTS_LIB = "src/monitoring/Alerts.mq5"
MQL_PERFORMANCE_LIB = "src/monitoring/PerformanceTracker.mq5"


@dataclass
class DrawdownThresholds:
    """Warn/critical drawdown levels expressed in percent."""

    warn: float = 2.0
    critical: float = 4.0


@dataclass
class PerformanceSample:
    """Single balance/equity snapshot coming from the trading runtime."""

    balance: float
    equity: float
    realized_pnl: float
    timestamp: datetime = field(default_factory=datetime.utcnow)


class PerformanceBuffer:
    """In-memory ring buffer of the most recent performance points."""

    def __init__(self, maxlen: int = 256) -> None:
        self._samples: Deque[PerformanceSample] = deque(maxlen=maxlen)

    def push(self, balance: float, equity: float, realized_pnl: float) -> PerformanceSample:
        sample = PerformanceSample(balance=balance, equity=equity, realized_pnl=realized_pnl)
        self._samples.append(sample)
        return sample

    def tail(self) -> Optional[PerformanceSample]:
        return self._samples[-1] if self._samples else None

    def __len__(self) -> int:  # pragma: no cover - trivial
        return len(self._samples)


class MQLPerformanceBridge:
    """Produces configuration payloads for the MT5 performance tracker."""

    def __init__(self, thresholds: DrawdownThresholds, buffer: PerformanceBuffer) -> None:
        self.thresholds = thresholds
        self.buffer = buffer

    def build_bootstrap_payload(self) -> Dict[str, float]:
        """Return the drawdown configuration expected by PerformanceTracker.mq5."""

        return {
            "warn_drawdown_percent": self.thresholds.warn,
            "critical_drawdown_percent": self.thresholds.critical,
            "logger_library": MQL_LOGGER_LIB,
            "alerts_library": MQL_ALERTS_LIB,
            "performance_library": MQL_PERFORMANCE_LIB,
        }

    def build_snapshot_payload(self) -> Dict[str, float]:
        """Return the values sent to the MT5 bridge for each heartbeat."""

        sample = self.buffer.tail()
        if not sample:
            return {}

        return {
            "balance": sample.balance,
            "equity": sample.equity,
            "realized_pnl": sample.realized_pnl,
            "timestamp": sample.timestamp.timestamp(),
        }


def batch_push(buffer: PerformanceBuffer, entries: Iterable[PerformanceSample]) -> None:
    """Utility to seed the buffer from historical data."""

    for entry in entries:
        buffer.push(entry.balance, entry.equity, entry.realized_pnl)
