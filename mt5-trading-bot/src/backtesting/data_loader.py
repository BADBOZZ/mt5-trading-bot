"""Data loading utilities that rely on MetaTrader5 history center."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, Optional

import logging
from pathlib import Path

import pandas as pd

try:
    import MetaTrader5 as mt5
except Exception:  # pragma: no cover - optional dependency during CI
    mt5 = None  # type: ignore


LOGGER = logging.getLogger(__name__)


TIMEFRAME_MAP: Dict[str, int] = {}
if mt5:
    TIMEFRAME_MAP = {
        "M1": mt5.TIMEFRAME_M1,
        "M5": mt5.TIMEFRAME_M5,
        "M15": mt5.TIMEFRAME_M15,
        "M30": mt5.TIMEFRAME_M30,
        "H1": mt5.TIMEFRAME_H1,
        "H4": mt5.TIMEFRAME_H4,
        "D1": mt5.TIMEFRAME_D1,
    }


@dataclass(slots=True)
class MT5Credentials:
    login: int
    server: str
    password: str


class HistoricalDataLoader:
    """Thin wrapper around MT5 API for fetching bars while logging diagnostics."""

    def __init__(self, credentials: MT5Credentials, storage_dir: Optional[Path] = None) -> None:
        self.credentials = credentials
        self.storage_dir = storage_dir or Path(".cache/mt5")
        self.storage_dir.mkdir(parents=True, exist_ok=True)

    def initialize(self) -> None:
        if mt5 is None:
            raise RuntimeError("MetaTrader5 module is not installed")
        if mt5.initialize():
            LOGGER.info("MT5 terminal initialized")
        else:
            raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")

        authorized = mt5.login(
            login=self.credentials.login,
            password=self.credentials.password,
            server=self.credentials.server,
        )
        if not authorized:
            raise RuntimeError(f"MT5 login failed: {mt5.last_error()}")
        LOGGER.info("MT5 login succeeded for %s", self.credentials.login)

    def _cached_file(self, symbol: str, timeframe: str, start: datetime, end: datetime) -> Path:
        file_name = f"{symbol}_{timeframe}_{start:%Y%m%d}_{end:%Y%m%d}.csv"
        return self.storage_dir / file_name

    def fetch_bars(
        self,
        symbol: str,
        timeframe: str,
        start: datetime,
        end: datetime,
        use_cache: bool = True,
    ) -> pd.DataFrame:
        timeframe_code = TIMEFRAME_MAP.get(timeframe.upper())
        if timeframe_code is None:
            raise ValueError(f"Unsupported timeframe: {timeframe}")

        cache_file = self._cached_file(symbol, timeframe, start, end)
        if use_cache and cache_file.exists():
            LOGGER.debug("Loading cached history %s", cache_file)
            return pd.read_csv(cache_file, parse_dates=["time"], index_col="time")

        utc_from = start.astimezone(timezone.utc)
        utc_to = end.astimezone(timezone.utc)

        LOGGER.info("Downloading %s %s bars from MT5", symbol, timeframe)
        if mt5 is None:
            raise RuntimeError("MetaTrader5 module is not installed")
        rates = mt5.copy_rates_range(symbol, timeframe_code, utc_from, utc_to)
        if rates is None or len(rates) == 0:
            raise RuntimeError(f"No rates returned for {symbol} {timeframe}")

        frame = pd.DataFrame(rates)
        frame["time"] = pd.to_datetime(frame["time"], unit="s", utc=True)
        frame.set_index("time", inplace=True)

        cache_file.parent.mkdir(parents=True, exist_ok=True)
        frame.to_csv(cache_file)
        LOGGER.debug("Cached history to %s", cache_file)
        return frame


__all__ = ["HistoricalDataLoader", "MT5Credentials", "TIMEFRAME_MAP"]
