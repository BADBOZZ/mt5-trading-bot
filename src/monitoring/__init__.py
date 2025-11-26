"""
Monitoring package for the MetaTrader 5 trading bot.
Provides real-time metrics, logging, dashboards, and alerting integrations.
"""

from .config import MonitoringConfig
from .events import AlertEvent, HeartbeatEvent, MetricPoint, TradeEvent
from .manager import MonitoringManager
from .performance import PerformanceTimer

__all__ = [
    "MonitoringConfig",
    "MonitoringManager",
    "PerformanceTimer",
    "TradeEvent",
    "MetricPoint",
    "AlertEvent",
    "HeartbeatEvent",
]
