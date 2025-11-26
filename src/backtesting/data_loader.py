from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, Optional

import pandas as pd


@dataclass
class DataLoaderConfig:
    datetime_column: str = "time"
    price_columns: Iterable[str] = ("open", "high", "low", "close")
    volume_column: Optional[str] = "tick_volume"
    tz: Optional[str] = None
    dropna: bool = True


@dataclass
class HistoricalDataLoader:
    config: DataLoaderConfig = field(default_factory=DataLoaderConfig)

    def load_csv(self, path: str | Path, timeframe: Optional[str] = None) -> pd.DataFrame:
        """Load historical candles exported from MT5."""

        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(path)

        df = pd.read_csv(path)
        if self.config.datetime_column not in df.columns:
            raise ValueError(
                f"CSV missing datetime column '{self.config.datetime_column}'."
            )

        df[self.config.datetime_column] = pd.to_datetime(
            df[self.config.datetime_column], utc=True
        )
        if self.config.tz:
            df[self.config.datetime_column] = df[self.config.datetime_column].dt.tz_convert(
                self.config.tz
            )

        df = df.set_index(self.config.datetime_column).sort_index()
        df = self._ensure_numeric(df)

        if timeframe:
            df = self._resample(df, timeframe)

        if self.config.dropna:
            df = df.dropna()

        return df

    # ------------------------------------------------------------------ #
    def _ensure_numeric(self, df: pd.DataFrame) -> pd.DataFrame:
        numeric_cols = list(self.config.price_columns)
        if self.config.volume_column:
            numeric_cols.append(self.config.volume_column)
        df[numeric_cols] = df[numeric_cols].apply(pd.to_numeric, errors="coerce")
        return df

    def _resample(self, df: pd.DataFrame, timeframe: str) -> pd.DataFrame:
        agg: Dict[str, str] = {
            "open": "first",
            "high": "max",
            "low": "min",
            "close": "last",
        }
        if self.config.volume_column and self.config.volume_column in df.columns:
            agg[self.config.volume_column] = "sum"
        return df.resample(timeframe).agg(agg)
