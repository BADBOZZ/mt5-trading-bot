"""Market data streaming helpers."""

from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable, Dict, List, Optional, Tuple

from .connection import MT5ConnectionManager
from .exceptions import MT5MarketDataError

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class Tick:
    symbol: str
    time: datetime
    bid: float
    ask: float
    last: float
    volume: float


@dataclass(slots=True)
class RateBar:
    symbol: str
    timeframe: int
    time: datetime
    open: float
    high: float
    low: float
    close: float
    tick_volume: float


class MarketDataStreamer:
    def __init__(self, connection: MT5ConnectionManager, poll_interval: float = 1.0):
        self.connection = connection
        self.poll_interval = poll_interval
        self._tick_subscriptions: Dict[str, List[Callable[[Tick], None]]] = {}
        self._rate_subscriptions: Dict[Tuple[str, int], List[Callable[[RateBar], None]]] = {}
        self._thread: Optional[threading.Thread] = None
        self._stop = threading.Event()
        self._lock = threading.RLock()

    def subscribe_ticks(self, symbol: str, callback: Callable[[Tick], None]) -> None:
        with self._lock:
            self.connection.ensure_symbol(symbol)
            self._tick_subscriptions.setdefault(symbol, []).append(callback)
        self._ensure_running()

    def subscribe_rates(
        self,
        symbol: str,
        timeframe,
        callback: Callable[[RateBar], None],
    ) -> None:
        tf_value = self._resolve_timeframe(timeframe)
        key = (symbol, tf_value)
        with self._lock:
            self.connection.ensure_symbol(symbol)
            self._rate_subscriptions.setdefault(key, []).append(callback)
        self._ensure_running()

    def unsubscribe_all(self) -> None:
        with self._lock:
            self._tick_subscriptions.clear()
            self._rate_subscriptions.clear()
        self.stop()

    def stop(self) -> None:
        self._stop.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2 * self.poll_interval)
        self._thread = None
        self._stop.clear()

    def _ensure_running(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _run(self) -> None:
        logger.info("Starting market data loop with interval %.2fs", self.poll_interval)
        while not self._stop.is_set():
            self._emit_ticks()
            self._emit_rates()
            time.sleep(self.poll_interval)
        logger.info("Market data loop stopped")

    def _emit_ticks(self) -> None:
        with self._lock:
            subscriptions = dict(self._tick_subscriptions)
        for symbol, callbacks in subscriptions.items():
            tick = self.connection.api.symbol_info_tick(symbol)
            if not tick:
                continue
            tick_model = Tick(
                symbol=symbol,
                time=datetime.fromtimestamp(tick.time_msc / 1000, tz=timezone.utc),
                bid=tick.bid,
                ask=tick.ask,
                last=tick.last,
                volume=tick.volume,
            )
            for callback in callbacks:
                self._safe_callback(callback, tick_model)

    def _emit_rates(self) -> None:
        with self._lock:
            subscriptions = dict(self._rate_subscriptions)
        for (symbol, timeframe), callbacks in subscriptions.items():
            rates = self.connection.api.copy_rates_from_pos(symbol, timeframe, 0, 1)
            if rates is None or len(rates) == 0:
                continue
            rate = rates[0]
            rate_bar = RateBar(
                symbol=symbol,
                timeframe=timeframe,
                time=datetime.fromtimestamp(rate.time, tz=timezone.utc),
                open=rate.open,
                high=rate.high,
                low=rate.low,
                close=rate.close,
                tick_volume=rate.tick_volume,
            )
            for callback in callbacks:
                self._safe_callback(callback, rate_bar)

    def _safe_callback(self, callback, payload) -> None:
        try:
            callback(payload)
        except Exception as exc:  # pragma: no cover - callbacks are user space
            logger.exception("Market data callback %s failed: %s", callback, exc)

    def _resolve_timeframe(self, timeframe) -> int:
        api = self.connection.api
        if isinstance(timeframe, int):
            return timeframe
        attr_name = timeframe if timeframe.startswith("TIMEFRAME_") else f"TIMEFRAME_{timeframe.upper()}"
        if not hasattr(api, attr_name):
            raise MT5MarketDataError(f"Unknown timeframe {timeframe}")
        return getattr(api, attr_name)

    def __enter__(self):  # pragma: no cover - context helper
        return self

    def __exit__(self, exc_type, exc, tb):  # pragma: no cover
        self.stop()
        return False
