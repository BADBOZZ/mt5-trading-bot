from __future__ import annotations

from typing import Dict, Iterable, List

from ..events import AlertEvent
from ..logger import build_logger
from ..config import LogConfig
from .base import AlertChannel, HealthcheckCapable


class AlertRouter:
    """Fan-out dispatcher that delivers alerts to multiple channels."""

    def __init__(
        self,
        channels: Iterable[AlertChannel],
        log_config: LogConfig,
    ) -> None:
        self.channels: List[AlertChannel] = list(channels)
        self.logger = build_logger("alert-router", log_config)

    def dispatch(self, alert: AlertEvent) -> None:
        for channel in self.channels:
            try:
                channel.send(alert)
            except Exception as exc:
                self.logger.error(
                    "Alert delivery failed",
                    extra={"channel": channel.name, "error": str(exc), "alert": alert.code},
                )

    def healthcheck(self) -> Dict[str, bool]:
        status: Dict[str, bool] = {}
        for channel in self.channels:
            healthy = True
            if isinstance(channel, HealthcheckCapable):
                try:
                    healthy = channel.healthcheck()
                except Exception:
                    healthy = False
            status[channel.name] = healthy
        return status
