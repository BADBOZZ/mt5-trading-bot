from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import List, Optional

from .config import AlertThresholds
from .events import AlertEvent, HeartbeatEvent, Severity, TradeEvent


@dataclass
class RuleState:
    consecutive_losses: int = 0
    high_watermark: Optional[float] = None
    last_heartbeat: datetime = field(default_factory=datetime.utcnow)
    order_rejections: int = 0


class RuleEngine:
    """Evaluates trades and heartbeats against safety thresholds."""

    def __init__(self, thresholds: AlertThresholds) -> None:
        self.thresholds = thresholds
        self.state = RuleState()

    def process_trade(self, trade: TradeEvent) -> List[AlertEvent]:
        alerts: List[AlertEvent] = []

        if trade.pnl < 0:
            self.state.consecutive_losses += 1
        else:
            self.state.consecutive_losses = 0

        self.state.order_rejections = trade.order_rejections

        self.state.high_watermark = self._update_high_watermark(trade.account_balance)
        drawdown_pct = self._compute_drawdown(trade.account_balance)

        if drawdown_pct and drawdown_pct >= self.thresholds.max_drawdown_pct:
            alerts.append(
                AlertEvent(
                    code="risk.drawdown",
                    message=f"Drawdown hit {drawdown_pct:.2f}% (> {self.thresholds.max_drawdown_pct}%)",
                    severity=Severity.CRITICAL,
                    context={
                        "balance": trade.account_balance,
                        "drawdown_pct": drawdown_pct,
                    },
                )
            )

        if self.state.consecutive_losses >= self.thresholds.max_consecutive_losses:
            alerts.append(
                AlertEvent(
                    code="risk.consecutive-losses",
                    message=(
                        f"{self.state.consecutive_losses} losing trades in a row "
                        f"(limit {self.thresholds.max_consecutive_losses})"
                    ),
                    severity=Severity.WARNING,
                    context={
                        "pnl": trade.pnl,
                        "symbol": trade.symbol,
                    },
                )
            )

        if trade.slippage_pips >= self.thresholds.max_slippage_pips:
            alerts.append(
                AlertEvent(
                    code="execution.slippage",
                    message=(
                        f"Slippage {trade.slippage_pips} pips "
                        f"(limit {self.thresholds.max_slippage_pips})"
                    ),
                    severity=Severity.WARNING,
                    context={
                        "trade_id": trade.trade_id,
                        "symbol": trade.symbol,
                    },
                )
            )

        if trade.latency_ms >= self.thresholds.max_latency_ms:
            alerts.append(
                AlertEvent(
                    code="execution.latency",
                    message=(
                        f"Latency {trade.latency_ms:.1f}ms "
                        f"(limit {self.thresholds.max_latency_ms}ms)"
                    ),
                    severity=Severity.WARNING,
                    context={
                        "trade_id": trade.trade_id,
                        "symbol": trade.symbol,
                    },
                )
            )

        if (
            trade.order_rejections >= self.thresholds.max_order_rejections
            and trade.order_rejections > 0
        ):
            alerts.append(
                AlertEvent(
                    code="execution.rejections",
                    message=(
                        f"Order rejections {trade.order_rejections} "
                        f"(limit {self.thresholds.max_order_rejections})"
                    ),
                    severity=Severity.CRITICAL,
                    context={
                        "trade_id": trade.trade_id,
                        "symbol": trade.symbol,
                    },
                )
            )

        if trade.account_balance <= self.thresholds.min_balance:
            alerts.append(
                AlertEvent(
                    code="risk.low-balance",
                    message=(
                        f"Balance {trade.account_balance} "
                        f"(limit {self.thresholds.min_balance})"
                    ),
                    severity=Severity.CRITICAL,
                    context={
                        "symbol": trade.symbol,
                        "pnl": trade.pnl,
                    },
                )
            )

        return alerts

    def heartbeat(self, heartbeat: HeartbeatEvent) -> Optional[AlertEvent]:
        now = heartbeat.timestamp
        elapsed = now - self.state.last_heartbeat
        self.state.last_heartbeat = now
        if elapsed > timedelta(seconds=self.thresholds.heartbeat_seconds):
            return AlertEvent(
                code="system.missed-heartbeat",
                message=(
                    f"No heartbeat in {elapsed.total_seconds():.0f}s "
                    f"(limit {self.thresholds.heartbeat_seconds}s)"
                ),
                severity=Severity.CRITICAL,
                context={"source": heartbeat.source},
            )
        return None

    def _update_high_watermark(self, balance: float) -> float:
        if self.state.high_watermark is None:
            self.state.high_watermark = balance
        else:
            self.state.high_watermark = max(self.state.high_watermark, balance)
        return self.state.high_watermark

    def _compute_drawdown(self, balance: float) -> Optional[float]:
        if not self.state.high_watermark:
            return None
        drop = self.state.high_watermark - balance
        if self.state.high_watermark == 0:
            return None
        return (drop / self.state.high_watermark) * 100
