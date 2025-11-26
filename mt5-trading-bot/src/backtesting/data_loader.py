"""Market data loader utilities for CSV dumps or the MetaTrader5 bridge."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterable, Optional

import pandas as pd

from .config import BacktestSettings

try:
    import MetaTrader5 as mt5
except ImportError:  # pragma: no cover - optional dependency
    mt5 = None


MT5_TIMEFRAME_MAP = {
    "M1": "TIMEFRAME_M1",
    "M5": "TIMEFRAME_M5",
    "M15": "TIMEFRAME_M15",
    "M30": "TIMEFRAME_M30",
    "H1": "TIMEFRAME_H1",
    "H4": "TIMEFRAME_H4",
    "D1": "TIMEFRAME_D1",
}


def _resolve_timeframe(timeframe: str):
    """Resolve textual timeframe into MetaTrader5 constant."""
    if mt5 is None:
        raise RuntimeError(
            "MetaTrader5 package not available. Install MetaTrader5>=5.0.45 to "
            "download quotes directly from a terminal."
        )
    key = MT5_TIMEFRAME_MAP.get(timeframe.upper())
    if not key or not hasattr(mt5, key):
        raise ValueError(f"Unsupported timeframe {timeframe}")
    return getattr(mt5, key)


def _standardize_dataframe(df: pd.DataFrame, timezone: str) -> pd.DataFrame:
    """Ensure mandatory columns exist and the index is time-aware."""
    required = {"time", "open", "high", "low", "close"}
    missing = required.difference(df.columns)
    if missing:
        raise ValueError(f"Dataset is missing required columns: {', '.join(sorted(missing))}")

    df = df.copy()
    df["time"] = pd.to_datetime(df["time"], utc=True)
    if timezone:
        df["time"] = df["time"].dt.tz_convert(timezone)
    df = df.sort_values("time")
    df = df.set_index("time")
    df[["open", "high", "low", "close"]] = df[["open", "high", "low", "close"]].astype(float)
    if "spread" in df.columns:
        df["spread"] = df["spread"].astype(float)
    if "tick_volume" in df.columns:
        df["tick_volume"] = df["tick_volume"].astype(float)
    return df


@dataclass(slots=True)
class MarketDataSet:
    """Represents synchronized OHLCV data for a single symbol."""

    symbol: str
    timeframe: str
    frame: pd.DataFrame

    def to_records(self) -> list[dict]:
        """Return list of dicts (compatible with strategy generators)."""
        return self.frame.reset_index().to_dict("records")


class MarketDataLoader:
    """Hydrates pandas DataFrames from CSV dumps or live MT5 terminals."""

    def __init__(
        self,
        cache_dir: str | Path = "data/cache",
        terminal_path: Optional[str] = None,
    ):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.terminal_path = terminal_path

    # --------------------------------------------------------------------- CSV
    def load_csv(
        self,
        path: str | Path,
        symbol: str,
        timeframe: str,
        timezone: str = "UTC",
    ) -> MarketDataSet:
        """Load a CSV file exported from MT5."""
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(path)

        df = pd.read_csv(path)
        df = _standardize_dataframe(df, timezone)
        df.attrs["source"] = str(path)
        return MarketDataSet(symbol=symbol, timeframe=timeframe, frame=df)

    def load_csv_directory(
        self,
        directory: str | Path,
        symbols: Iterable[str],
        timeframe: str,
        timezone: str = "UTC",
    ) -> Dict[str, MarketDataSet]:
        """Load multiple CSVs from a directory following `<symbol>.csv` pattern."""
        directory = Path(directory)
        datasets: Dict[str, MarketDataSet] = {}
        for symbol in symbols:
            candidate = directory / f"{symbol}.csv"
            if not candidate.exists():
                # allow `SYMBOL_TIMEFRAME.csv`
                candidate = directory / f"{symbol}_{timeframe}.csv"
            datasets[symbol] = self.load_csv(candidate, symbol, timeframe, timezone)
        return datasets

    # ---------------------------------------------------------------------- MT5
    def load_from_mt5(
        self,
        symbol: str,
        timeframe: str,
        start: datetime,
        end: datetime,
        timezone: str = "UTC",
    ) -> MarketDataSet:
        """Pull candles directly from a running MetaTrader terminal."""
        if mt5 is None:
            raise RuntimeError(
                "MetaTrader5 package not available so live downloads are disabled."
            )

        if not mt5.initialize(path=self.terminal_path):
            raise RuntimeError(f"Failed to initialize MetaTrader5: {mt5.last_error()}")

        rates = mt5.copy_rates_range(
            symbol,
            _resolve_timeframe(timeframe),
            start,
            end,
        )
        if rates is None or len(rates) == 0:
            raise RuntimeError(f"No rates returned for {symbol} {timeframe}")

        df = pd.DataFrame(rates)
        df["time"] = pd.to_datetime(df["time"], unit="s", utc=True)
        if timezone:
            df["time"] = df["time"].dt.tz_convert(timezone)
        df.rename(
            columns={
                "real_volume": "real_volume",
                "tick_volume": "tick_volume",
            },
            inplace=True,
        )
        df = df[["time", "open", "high", "low", "close", "tick_volume", "spread", "real_volume"]]
        df = df.sort_values("time")

        cache_file = self.cache_dir / f"{symbol}_{timeframe}_{start:%Y%m%d}_{end:%Y%m%d}.parquet"
        df.to_parquet(cache_file, index=False)

        mt5.shutdown()
        return MarketDataSet(symbol=symbol, timeframe=timeframe, frame=df.set_index("time"))

    # --------------------------------------------------------------- Synchrony
    @staticmethod
    def synchronize(
        datasets: Dict[str, MarketDataSet],
        settings: Optional[BacktestSettings] = None,
    ) -> Dict[str, pd.DataFrame]:
        """Align symbols to a shared timeline for the backtesting engine."""
        if not datasets:
            return {}

        frames = {}
        master_index = None
        for symbol, dataset in datasets.items():
            frame = dataset.frame.copy()
            if master_index is None:
                master_index = frame.index
            else:
                master_index = master_index.union(frame.index)
            frames[symbol] = frame

        master_index = master_index.sort_values()
        for symbol, frame in frames.items():
            aligned = frame.reindex(master_index)
            if settings and settings.fill_gaps:
                aligned = aligned.ffill().bfill()
            frames[symbol] = aligned
        return frames

    # ------------------------------------------------------------- Persistency
    def save_snapshot(self, datasets: Dict[str, MarketDataSet], destination: Path) -> None:
        """Persist aligned data to disk for reproducibility."""
        destination.parent.mkdir(parents=True, exist_ok=True)
        payload = {}
        for symbol, dataset in datasets.items():
            file_path = destination.with_suffix(f".{symbol}.parquet")
            dataset.frame.to_parquet(file_path)
            payload[symbol] = {"file": file_path.name, "timeframe": dataset.timeframe}

        destination.write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
