"""Shared monitoring configuration primitives."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict


@dataclass(frozen=True)
class MonitoringPaths:
    """Filesystem references to the MQL5 libraries shipped in this repo."""

    logger: str = "src/monitoring/Logger.mq5"
    alerts: str = "src/monitoring/Alerts.mq5"
    performance: str = "src/monitoring/PerformanceTracker.mq5"


@dataclass
class MonitoringSettings:
    """Runtime knobs exposed to the Python control plane."""

    log_file: str = "logs/performance.log"
    warn_drawdown: float = 2.0
    critical_drawdown: float = 4.0
    alert_channels: int = 1
    alert_throttle_seconds: int = 30
    alert_prefix: str = "MT5Bot"
    paths: MonitoringPaths = field(default_factory=MonitoringPaths)

    def bootstrap_payload(self) -> Dict[str, float]:
        """Payload used to seed the MQL PerformanceTracker library."""

        return {
            "log_file": self.log_file,
            "warn_drawdown_percent": self.warn_drawdown,
            "critical_drawdown_percent": self.critical_drawdown,
            "alert_channels": self.alert_channels,
            "alert_throttle_seconds": self.alert_throttle_seconds,
            "alert_prefix": self.alert_prefix,
            "logger_library": self.paths.logger,
            "alerts_library": self.paths.alerts,
            "performance_library": self.paths.performance,
        }


DEFAULT_MONITORING_SETTINGS = MonitoringSettings()
