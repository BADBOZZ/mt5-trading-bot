"""MetaTrader 5 connection management layer."""

from __future__ import annotations

import threading
import time
from contextlib import contextmanager
import logging
from typing import Iterable, Iterator, Optional

from .config import MT5Config
from .exceptions import (
    MT5ConnectionError,
    MT5DependencyError,
    MT5ErrorDetail,
    build_error_detail,
)

logger = logging.getLogger(__name__)

try:  # pragma: no cover - exercised indirectly
    import MetaTrader5 as _mt5
except ImportError:  # pragma: no cover - handled by raising MT5DependencyError
    _mt5 = None


class MT5ConnectionManager:
    """Wraps the MetaTrader5 API with retry-aware connection management."""

    def __init__(self, config: MT5Config, *, api=None):
        self.config = config
        self._api = api or _mt5
        if self._api is None:
            raise MT5DependencyError(
                "MetaTrader5 package is not installed. Run `pip install MetaTrader5`."
            )
        self._lock = threading.RLock()
        self._connected = False

    @property
    def api(self):  # pragma: no cover - trivial
        return self._api

    @property
    def is_connected(self) -> bool:
        return self._connected

    def connect(self, *, auto_select_symbols: Optional[Iterable[str]] = None, force: bool = False) -> None:
        with self._lock:
            if self._connected and not force:
                return

            last_detail: Optional[MT5ErrorDetail] = None
            for attempt in range(1, self.config.retries + 1):
                logger.debug("Attempting MT5 initialize (attempt %s/%s)", attempt, self.config.retries)
                if self._initialize():
                    self._connected = True
                    logger.info("Connected to MT5 server %s as %s", self.config.server, self.config.login)
                    if auto_select_symbols:
                        for symbol in auto_select_symbols:
                            self.select_symbol(symbol)
                    return

                last_detail = build_error_detail(self._api.last_error())
                logger.warning("MT5 initialize failed (attempt %s): %s", attempt, last_detail)
                time.sleep(self.config.retry_delay)

            raise MT5ConnectionError(last_detail, reason="Unable to initialize MT5 terminal")

    def _initialize(self) -> bool:
        params = {
            "server": self.config.server,
            "login": self.config.login,
            "timeout": self.config.timeout,
        }
        if self.config.password:
            params["password"] = self.config.password
        if self.config.path:
            params["path"] = self.config.path
        if self.config.portable:
            params["portable"] = self.config.portable

        initialized = self._api.initialize(**params)
        if not initialized:
            self._connected = False
        return initialized

    def reconnect(self) -> None:
        self.shutdown()
        self.connect(force=True)

    def shutdown(self) -> None:
        with self._lock:
            if self._connected:
                logger.info("Shutting down MT5 terminal connection")
                self._api.shutdown()
                self._connected = False

    def ensure_connected(self) -> None:
        if not self._connected:
            logger.debug("MT5 not connected, attempting to reconnect")
            self.connect()

    def select_symbol(self, symbol: str, enable: bool = True) -> None:
        self.ensure_connected()
        if not self._api.symbol_select(symbol, enable):
            raise MT5ConnectionError(reason=f"Unable to {'enable' if enable else 'disable'} symbol {symbol}")
        logger.debug("Symbol %s %s", symbol, "enabled" if enable else "disabled")

    def ensure_symbol(self, symbol: str) -> None:
        self.ensure_connected()
        self.select_symbol(symbol, True)

    @contextmanager
    def session(self) -> Iterator[None]:
        self.ensure_connected()
        try:
            yield
        except Exception:
            self._connected = False
            raise

    def terminal_status(self):  # pragma: no cover - passthrough helper
        self.ensure_connected()
        return self._api.terminal_info()

    def ping(self) -> float:
        self.ensure_connected()
        start = time.perf_counter()
        if not self._api.terminal_info():
            self._connected = False
            raise MT5ConnectionError(reason="MT5 terminal unreachable")
        return time.perf_counter() - start
