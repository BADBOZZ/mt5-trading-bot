"""High-level MetaTrader 5 integration helpers."""

from .config import MT5Config
from .connection import MT5ConnectionManager
from .account import MT5AccountManager
from .orders import OrderRequest, OrderExecutor
from .market_data import MarketDataStreamer
from .exceptions import (
    MT5Error,
    MT5DependencyError,
    MT5ConnectionError,
    MT5OrderError,
    MT5MarketDataError,
    MT5AccountError,
)

__all__ = [
    "MT5Config",
    "MT5ConnectionManager",
    "MT5AccountManager",
    "OrderRequest",
    "OrderExecutor",
    "MarketDataStreamer",
    "MT5Error",
    "MT5DependencyError",
    "MT5ConnectionError",
    "MT5OrderError",
    "MT5MarketDataError",
    "MT5AccountError",
]
