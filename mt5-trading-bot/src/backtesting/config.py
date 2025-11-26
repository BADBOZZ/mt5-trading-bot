"""
Shared configuration structures for Python tooling so tests, optimizers,
and walk-forward planners stay aligned with the MT5 inputs.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import os


@dataclass(frozen=True)
class StrategyTesterPaths:
    terminal: Path
    expert: Path
    config: Path
    results: Path


@dataclass(frozen=True)
class OptimizationSettings:
    symbols: Sequence[str]
    timeframe: str
    in_sample_days: int
    out_sample_days: int
    target: str


def load_from_env() -> tuple[StrategyTesterPaths, OptimizationSettings]:
    symbols = [sym.strip().upper() for sym in os.getenv("MT5_SYMBOLS", "EURUSD").split(",") if sym.strip()]
    paths = StrategyTesterPaths(
        terminal=Path(os.getenv("MT5_TERMINAL", "terminal64.exe")),
        expert=Path(os.getenv("MT5_EXPERT", "Experts/TradingBot.ex5")),
        config=Path(os.getenv("MT5_CONFIG", "tester.ini")),
        results=Path(os.getenv("MT5_RESULTS", "tester_results")),
    )
    optimization = OptimizationSettings(
        symbols=symbols,
        timeframe=os.getenv("MT5_TIMEFRAME", "H1"),
        in_sample_days=int(os.getenv("MT5_IN_SAMPLE", "90")),
        out_sample_days=int(os.getenv("MT5_OUT_SAMPLE", "30")),
        target=os.getenv("MT5_TARGET", "balanced"),
    )
    return paths, optimization
