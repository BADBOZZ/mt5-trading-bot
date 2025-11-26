from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Dict, Iterable

from .events import TradeEvent


class TradeLogWriter:
    """Persists trade events for post-trade analysis."""

    def __init__(self, log_dir: Path) -> None:
        self.log_dir = log_dir
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.csv_path = self.log_dir / "trades.csv"
        self.jsonl_path = self.log_dir / "trades.jsonl"
        self._ensure_csv_header()

    def _ensure_csv_header(self) -> None:
        if not self.csv_path.exists():
            with self.csv_path.open("w", newline="") as fh:
                writer = csv.DictWriter(fh, fieldnames=self._csv_fields())
                writer.writeheader()

    def _csv_fields(self) -> Iterable[str]:
        return [
            "timestamp",
            "trade_id",
            "symbol",
            "side",
            "volume",
            "price",
            "pnl",
            "slippage_pips",
            "latency_ms",
            "account_balance",
            "order_rejections",
        ]

    def append(self, event: TradeEvent) -> None:
        row: Dict[str, str] = {
            "timestamp": event.timestamp.isoformat(),
            "trade_id": event.trade_id,
            "symbol": event.symbol,
            "side": event.side,
            "volume": f"{event.volume}",
            "price": f"{event.price}",
            "pnl": f"{event.pnl}",
            "slippage_pips": f"{event.slippage_pips}",
            "latency_ms": f"{event.latency_ms}",
            "account_balance": f"{event.account_balance}",
            "order_rejections": f"{event.order_rejections}",
        }
        with self.csv_path.open("a", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=self._csv_fields())
            writer.writerow(row)

        data = {
            **row,
            "metadata": event.metadata,
        }
        with self.jsonl_path.open("a") as fh:
            fh.write(json.dumps(data) + "\n")
