"""
Standalone example showing how to wire the MonitoringManager into a bot.
Run: `python -m monitoring.example`
"""

from __future__ import annotations

import random
import time
from uuid import uuid4

from . import (
    HeartbeatEvent,
    MetricPoint,
    MonitoringConfig,
    MonitoringManager,
    PerformanceTimer,
    TradeEvent,
)


def main() -> None:
    config = MonitoringConfig.from_env()
    manager = MonitoringManager(config)
    manager.start()

    try:
        while True:
            manager.heartbeat(HeartbeatEvent(source="example"))
            emit_fake_trade(manager)
            with PerformanceTimer(manager, "order_cycle", threshold_ms=600):
                time.sleep(random.uniform(0.05, 0.2))
            manager.track_metric(
                MetricPoint(
                    name="system.cpu",
                    value=random.uniform(20, 60),
                    unit="percent",
                )
            )
            time.sleep(2)
    except KeyboardInterrupt:
        print("Stopping monitoring example...")
    finally:
        manager.stop()


def emit_fake_trade(manager: MonitoringManager) -> None:
    price = random.uniform(1.10, 1.30)
    volume = random.uniform(0.1, 1.0)
    pnl = random.uniform(-5, 5)
    trade = TradeEvent(
        trade_id=str(uuid4()),
        symbol="EURUSD",
        side=random.choice(["buy", "sell"]),
        volume=volume,
        price=price,
        pnl=pnl,
        slippage_pips=random.uniform(0, 3),
        latency_ms=random.uniform(100, 800),
        account_balance=1000 + random.uniform(-50, 50),
        order_rejections=random.choice([0, 0, 1]),
        metadata={"source": "example"},
    )
    manager.track_trade(trade)


if __name__ == "__main__":
    main()
