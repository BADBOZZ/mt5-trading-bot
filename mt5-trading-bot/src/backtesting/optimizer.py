"""Parameter optimization routines built on top of the Strategy Tester."""
from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

import logging

import pandas as pd

from .config import BacktestConfig, ParameterRange
from .engine import StrategyResult, StrategyTesterEngine

LOGGER = logging.getLogger(__name__)


@dataclass(slots=True)
class OptimizationSummary:
    best_result: StrategyResult
    leaderboard: List[StrategyResult]


class StrategyOptimizer:
    """Executes parameter sweeps and produces Strategy Tester leaderboards."""

    def __init__(self, config: BacktestConfig, engine: StrategyTesterEngine) -> None:
        self.config = config
        self.engine = engine

    def _expand_ranges(self, ranges: Sequence[ParameterRange]) -> Iterable[Dict[str, float]]:
        if not ranges:
            yield {}
            return
        names = [r.name for r in ranges]
        value_sets: List[List[float]] = []
        for rng in ranges:
            steps = int(((rng.stop - rng.start) / rng.step)) + 1
            values = [rng.start + idx * rng.step for idx in range(steps)]
            if rng.is_integer:
                values = [round(value) for value in values]
            value_sets.append(values)
        for combo in product(*value_sets):
            yield dict(zip(names, combo))

    def run_grid_search(self) -> OptimizationSummary:
        if not self.config.optimization.enabled:
            raise RuntimeError("Optimization flag must be enabled in config")
        ranges = self.config.optimization.parameter_ranges
        best_result: StrategyResult | None = None
        leaderboard: List[StrategyResult] = []
        for index, overrides in enumerate(self._expand_ranges(ranges)):
            if index >= self.config.optimization.max_runs:
                LOGGER.info("Reached max optimization runs: %s", self.config.optimization.max_runs)
                break
            LOGGER.info("Optimization run %s with overrides %s", index + 1, overrides)
            parameters = self.config.parameters | overrides
            result = self.engine.run(parameter_overrides=parameters)
            leaderboard.append(result)
            if best_result is None or result.stats.sharpe_ratio > best_result.stats.sharpe_ratio:
                best_result = result
        if best_result is None:
            raise RuntimeError("No optimization runs produced a result")
        leaderboard.sort(key=lambda res: res.stats.sharpe_ratio, reverse=True)
        return OptimizationSummary(best_result=best_result, leaderboard=leaderboard)

    def generate_report(self, summary: OptimizationSummary, destination: Path) -> None:
        rows = []
        for rank, result in enumerate(summary.leaderboard, start=1):
            rows.append({
                "rank": rank,
                "sharpe": result.stats.sharpe_ratio,
                "max_drawdown": result.stats.max_drawdown,
                "win_rate": result.stats.win_rate,
                "profit_factor": result.stats.profit_factor,
                "recovery_factor": result.stats.recovery_factor,
                "parameters": result.parameters,
            })
        df = pd.DataFrame(rows)
        destination.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(destination, index=False)
        LOGGER.info("Optimization leaderboard saved to %s", destination)


__all__ = ["StrategyOptimizer", "OptimizationSummary"]
