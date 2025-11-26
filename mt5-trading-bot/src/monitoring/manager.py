"""Monitoring manager orchestrating telemetry & MQL5 libraries."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, Optional

from .performance import DrawdownThresholds, MQLPerformanceBridge, PerformanceBuffer


@dataclass
class MonitoringConfig:
    """User facing knobs shared between Python and MT5 land."""

    log_file: str = "logs/performance.log"
    alert_prefix: str = "MT5Bot"
    alert_channels: int = 1  # Mirrors AlertChannelFlag bitmask
    throttle_seconds: int = 30
    thresholds: DrawdownThresholds = field(default_factory=DrawdownThresholds)


class MonitoringManager:
    """Collects performance samples and produces init payloads for MT5 scripts."""

    def __init__(self, config: Optional[MonitoringConfig] = None, max_samples: int = 256) -> None:
        self.config = config or MonitoringConfig()
        self.buffer = PerformanceBuffer(maxlen=max_samples)
        self.bridge = MQLPerformanceBridge(self.config.thresholds, self.buffer)

    def record_tick(self, balance: float, equity: float, realized_pnl: float) -> None:
        """Add a live sample to the internal buffer."""

        self.buffer.push(balance, equity, realized_pnl)

    def bootstrap_payload(self) -> Dict[str, float]:
        """Payload consumed by the MT5 PerformanceTracker during initialization."""

        payload = self.bridge.build_bootstrap_payload()
        payload.update(
            {
                "log_file": self.config.log_file,
                "alert_prefix": self.config.alert_prefix,
                "alert_channels": self.config.alert_channels,
                "alert_throttle_seconds": self.config.throttle_seconds,
            }
        )
        return payload

    def live_snapshot(self) -> Dict[str, float]:
        """Latest metrics for streaming into the MT5 heartbeat script."""

        return self.bridge.build_snapshot_payload()
