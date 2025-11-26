"""Executable entry point for the MT5 trading bot core."""

from __future__ import annotations

import logging
import signal
import sys
import time
from contextlib import suppress

from .account import MT5AccountManager
from .config import MT5Config
from .connection import MT5ConnectionManager
from .market_data import MarketDataStreamer
from .orders import OrderExecutor

try:  # optional, avoid hard dependency
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover
    load_dotenv = lambda: None  # type: ignore


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    )


def main() -> int:
    load_dotenv()
    configure_logging()

    config = MT5Config.from_env()
    connection = MT5ConnectionManager(config)
    account = MT5AccountManager(connection)
    orders = OrderExecutor(connection)
    market_data = MarketDataStreamer(connection, poll_interval=config.check_interval)

    connection.connect(auto_select_symbols=["EURUSD"])
    summary = account.summary()
    logging.info(
        "Connected account %s balance %.2f equity %.2f",
        summary.login,
        summary.balance,
        summary.equity,
    )
    current_positions = orders.positions() or []
    logging.info("Open positions at startup: %s", len(current_positions))

    def handle_tick(tick):  # pragma: no cover - runtime example
        logging.info("Tick %s bid=%s ask=%s", tick.symbol, tick.bid, tick.ask)

    market_data.subscribe_ticks("EURUSD", handle_tick)

    stop_signal = False

    def stop(*args):  # pragma: no cover - signal handler
        nonlocal stop_signal
        stop_signal = True

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    logging.info("Streaming market data... Press Ctrl+C to exit")
    while not stop_signal:
        if hasattr(signal, "pause"):
            signal.pause()
        else:  # pragma: no cover - platform fallback
            time.sleep(config.check_interval)

    market_data.stop()
    connection.shutdown()
    return 0


if __name__ == "__main__":  # pragma: no cover - manual execution
    with suppress(KeyboardInterrupt):
        sys.exit(main())
