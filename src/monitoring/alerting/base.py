from __future__ import annotations

import abc
from typing import Protocol

from ..events import AlertEvent


class AlertChannel(abc.ABC):
    """Abstract base class for alert channels."""

    name: str = "abstract"

    @abc.abstractmethod
    def send(self, alert: AlertEvent) -> None:
        """Deliver the alert via the concrete transport."""


class HealthcheckCapable(Protocol):
    def healthcheck(self) -> bool:
        ...
