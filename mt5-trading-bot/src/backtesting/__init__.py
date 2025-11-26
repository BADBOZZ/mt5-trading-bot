"""High-level exports for the MT5 backtesting toolkit."""
from .config import (
    BacktestConfig,
    OptimizationConfig,
    OptimizationObjective,
    ParameterRange,
    ReportConfig,
    SymbolConfig,
    WalkForwardConfig,
    WalkForwardWindow,
)
from .data_loader import HistoricalDataLoader, MT5Credentials
from .engine import StrategyResult, StrategyTesterEngine
from .metrics import PerformanceStats
from .optimizer import OptimizationSummary, StrategyOptimizer
from .walkforward import WalkForwardReport, WalkForwardRunner

__all__ = [
    "BacktestConfig",
    "HistoricalDataLoader",
    "MT5Credentials",
    "OptimizationConfig",
    "OptimizationObjective",
    "OptimizationSummary",
    "ParameterRange",
    "PerformanceStats",
    "ReportConfig",
    "StrategyOptimizer",
    "StrategyResult",
    "StrategyTesterEngine",
    "SymbolConfig",
    "WalkForwardConfig",
    "WalkForwardReport",
    "WalkForwardRunner",
    "WalkForwardWindow",
]
