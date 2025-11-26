"""
Backtesting and optimization toolkit for MetaTrader 5 strategies.
"""

from .config import BacktestConfig
from .engine import BacktestEngine, BacktestResult
from .metrics import PerformanceReport, compute_performance_report
from .optimizer import StrategyOptimizer
from .walkforward import WalkForwardAnalyzer, WalkForwardRun, WalkForwardSlice

__all__ = [
    "BacktestConfig",
    "BacktestEngine",
    "BacktestResult",
    "PerformanceReport",
    "compute_performance_report",
    "StrategyOptimizer",
    "WalkForwardAnalyzer",
    "WalkForwardRun",
    "WalkForwardSlice",
]
