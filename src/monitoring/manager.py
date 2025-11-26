from __future__ import annotations

import queue
import threading
from collections import deque
from datetime import datetime
from typing import Deque, Dict, Iterable, List, Optional, Tuple

from .alerting import AlertChannel, AlertRouter, EmailChannel, SMSChannel, TelegramChannel
from .config import MonitoringConfig
from .dashboard.server import MonitoringDashboard
from .events import (
    AlertEvent,
    EventType,
    HeartbeatEvent,
    MetricPoint,
    Severity,
    TradeEvent,
)
from .logger import build_logger
from .metrics import MetricStore
from .rules import RuleEngine
from .trade_logger import TradeLogWriter


class MonitoringManager:
    """Coordinates logging, metrics, dashboards, and alert routing."""

    def __init__(self, config: MonitoringConfig) -> None:
        self.config = config
        self.logger = build_logger("monitoring", config.log, config.metadata)
        self.metric_store = MetricStore()
        self.trade_logger = TradeLogWriter(config.log.directory / "trades")
        self.rule_engine = RuleEngine(config.thresholds)
        self.alert_router = AlertRouter(self._build_channels(), config.log)
        self.dashboard = MonitoringDashboard(
            self, config.dashboard_host, config.dashboard_port
        )
        self._queue: "queue.Queue[Tuple[EventType, object]]" = queue.Queue(maxsize=10000)
        self._recent_alerts: Deque[AlertEvent] = deque(maxlen=200)
        self._stop_event = threading.Event()
        self._worker = threading.Thread(target=self._worker_loop, daemon=True)
        self._started = False

    def _build_channels(self) -> Iterable[AlertChannel]:
        channels: List[AlertChannel] = []
        notifications = self.config.notifications
        if notifications.email.recipients and notifications.email.smtp_host:
            channels.append(EmailChannel(notifications.email))
        if notifications.sms.recipients and notifications.sms.account_sid:
            channels.append(SMSChannel(notifications.sms))
        if notifications.telegram.chat_ids and notifications.telegram.bot_token:
            channels.append(TelegramChannel(notifications.telegram))
        return channels

    def start(self) -> None:
        if self._started:
            return
        self._started = True
        self._worker.start()
        self.dashboard.start()
        self.logger.info("Monitoring manager started", extra={"dashboard": f"{self.config.dashboard_host}:{self.config.dashboard_port}"})

    def stop(self) -> None:
        if not self._started:
            return
        self._stop_event.set()
        self._worker.join(timeout=2)
        self.dashboard.stop()
        self._started = False

    def track_trade(self, trade: TradeEvent) -> None:
        self._queue.put((EventType.TRADE, trade))

    def track_metric(self, metric: MetricPoint) -> None:
        self._queue.put((EventType.METRIC, metric))

    def track_alert(self, alert: AlertEvent) -> None:
        self._queue.put((EventType.ALERT, alert))

    def heartbeat(self, heartbeat: HeartbeatEvent) -> None:
        self._queue.put((EventType.HEARTBEAT, heartbeat))

    def track_error(self, error: Exception, context: Optional[Dict[str, str]] = None) -> None:
        self.logger.error("Runtime error", exc_info=error, extra=context or {})
        alert = AlertEvent(
            code="system.error",
            message=str(error),
            severity=Severity.CRITICAL,
            context=context or {},
        )
        self.track_alert(alert)

    def raise_performance_alert(
        self,
        *,
        name: str,
        elapsed_ms: float,
        threshold_ms: float,
    ) -> None:
        alert = AlertEvent(
            code="performance.latency",
            message=f"{name} took {elapsed_ms:.1f}ms (limit {threshold_ms}ms)",
            severity=Severity.WARNING,
            context={"elapsed_ms": elapsed_ms, "threshold_ms": threshold_ms},
        )
        self.track_alert(alert)

    def metrics_snapshot(self) -> Dict[str, List[Dict[str, float]]]:
        return self.metric_store.snapshot()

    def recent_alerts(self) -> List[Dict[str, str]]:
        return [
            {
                "code": alert.code,
                "message": alert.message,
                "severity": alert.severity.value,
                "timestamp": alert.timestamp.isoformat(),
            }
            for alert in list(self._recent_alerts)
        ]

    def healthcheck(self) -> Dict[str, object]:
        return {
            "environment": self.config.environment,
            "alert_channels": self.alert_router.healthcheck(),
            "queue_depth": self._queue.qsize(),
            "timestamp": datetime.utcnow().isoformat(),
        }

    def _worker_loop(self) -> None:
        while not self._stop_event.is_set():
            try:
                event_type, payload = self._queue.get(timeout=0.5)
            except queue.Empty:
                continue
            try:
                self._dispatch(event_type, payload)
            except Exception as exc:  # pragma: no cover - defensive
                self.logger.exception("Failed to dispatch monitoring event", exc_info=exc)

    def _dispatch(self, event_type: EventType, payload: object) -> None:
        if event_type is EventType.TRADE and isinstance(payload, TradeEvent):
            self._handle_trade(payload)
        elif event_type is EventType.METRIC and isinstance(payload, MetricPoint):
            self.metric_store.add(payload)
        elif event_type is EventType.ALERT and isinstance(payload, AlertEvent):
            self._handle_alert(payload)
        elif event_type is EventType.HEARTBEAT and isinstance(payload, HeartbeatEvent):
            self._handle_heartbeat(payload)

    def _handle_trade(self, trade: TradeEvent) -> None:
        self.trade_logger.append(trade)
        self.metric_store.add(MetricPoint(name="trade.pnl", value=trade.pnl))
        self.metric_store.add(MetricPoint(name="trade.slippage", value=trade.slippage_pips, unit="pips"))
        self.metric_store.add(MetricPoint(name="trade.latency", value=trade.latency_ms, unit="ms"))
        self.metric_store.add(MetricPoint(name="account.balance", value=trade.account_balance))

        alerts = self.rule_engine.process_trade(trade)
        for alert in alerts:
            self._handle_alert(alert)

    def _handle_alert(self, alert: AlertEvent) -> None:
        self.logger.warning(
            alert.message,
            extra={
                "code": alert.code,
                "severity": alert.severity.value,
                **alert.context,
            },
        )
        self._recent_alerts.append(alert)
        self.alert_router.dispatch(alert)

    def _handle_heartbeat(self, heartbeat: HeartbeatEvent) -> None:
        alert = self.rule_engine.heartbeat(heartbeat)
        if alert:
            self._handle_alert(alert)
