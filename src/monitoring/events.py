from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional


class Severity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


class EventType(str, Enum):
    HEARTBEAT = "heartbeat"
    TRADE = "trade"
    METRIC = "metric"
    ALERT = "alert"
    PERFORMANCE = "performance"
    SYSTEM = "system"


@dataclass
class MonitoringEvent:
    """Base monitoring event flowing through the monitoring pipeline."""

    type: EventType
    timestamp: datetime = field(default_factory=datetime.utcnow)
    data: Dict[str, Any] = field(default_factory=dict)


@dataclass
class TradeEvent:
    trade_id: str
    symbol: str
    side: str
    volume: float
    price: float
    pnl: float
    slippage_pips: float
    latency_ms: float
    account_balance: float
    order_rejections: int = 0
    metadata: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def to_event(self) -> MonitoringEvent:
        return MonitoringEvent(
            type=EventType.TRADE,
            timestamp=self.timestamp,
            data={
                "trade_id": self.trade_id,
                "symbol": self.symbol,
                "side": self.side,
                "volume": self.volume,
                "price": self.price,
                "pnl": self.pnl,
                "slippage_pips": self.slippage_pips,
                "latency_ms": self.latency_ms,
                "account_balance": self.account_balance,
                "order_rejections": self.order_rejections,
                "metadata": self.metadata,
            },
        )


@dataclass
class MetricPoint:
    name: str
    value: float
    unit: str = ""
    tags: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def to_event(self) -> MonitoringEvent:
        return MonitoringEvent(
            type=EventType.METRIC,
            timestamp=self.timestamp,
            data={
                "name": self.name,
                "value": self.value,
                "unit": self.unit,
                "tags": self.tags,
            },
        )


@dataclass
class AlertEvent:
    code: str
    message: str
    severity: Severity = Severity.WARNING
    context: Dict[str, Any] = field(default_factory=dict)
    acknowledged: bool = False
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def to_event(self) -> MonitoringEvent:
        return MonitoringEvent(
            type=EventType.ALERT,
            timestamp=self.timestamp,
            data={
                "code": self.code,
                "message": self.message,
                "severity": self.severity.value,
                "context": self.context,
                "acknowledged": self.acknowledged,
            },
        )


@dataclass
class HeartbeatEvent:
    source: str = "trading-bot"
    latency_ms: Optional[float] = None
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def to_event(self) -> MonitoringEvent:
        return MonitoringEvent(
            type=EventType.HEARTBEAT,
            timestamp=self.timestamp,
            data={"source": self.source, "latency_ms": self.latency_ms},
        )
