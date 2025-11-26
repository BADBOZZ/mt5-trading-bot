"""Grid-search helper to guide MT5 Strategy Tester parameter sweeps."""

from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from typing import Callable, Dict, List, Sequence

from .engine import BacktestResult, StrategyTesterEngine
from .metrics import PerformanceReport


@dataclass(slots=True)
class OptimizationResult:
    """Stores the outcome of a single optimisation run."""

    parameters: Dict[str, float]
    result: BacktestResult

    @property
    def performance(self) -> PerformanceReport:
        return self.result.performance


class ParameterGrid:
    """Cartesian product helper similar to scikit-learn's implementation."""

    def __init__(self, grid: Dict[str, Sequence]):
        self.grid = {key: list(values) for key, values in grid.items()}

    def __iter__(self):
        if not self.grid:
            yield {}
            return
        keys = list(self.grid.keys())
        for combo in product(*(self.grid[key] for key in keys)):
            yield dict(zip(keys, combo))

    def __len__(self) -> int:
        if not self.grid:
            return 1
        total = 1
        for values in self.grid.values():
            total *= len(values)
        return total


class StrategyTesterOptimizer:
    """Optimises strategy parameters against an objective metric."""

    def __init__(
        self,
        engine_factory: Callable[[Dict[str, float]], StrategyTesterEngine],
        objective: str = "sharpe",
    ):
        self.engine_factory = engine_factory
        self.objective = objective

    def run(
        self,
        market_frames,
        grid: ParameterGrid,
        top_n: int | None = None,
    ) -> List[OptimizationResult]:
        """Execute the optimisation and return sorted results."""
        results: List[OptimizationResult] = []
        for params in grid:
            engine = self.engine_factory(params)
            backtest_result = engine.run(market_frames)
            results.append(OptimizationResult(parameters=params, result=backtest_result))

        results.sort(
            key=lambda res: getattr(res.performance, self.objective, 0.0),
            reverse=True,
        )

        if top_n:
            return results[:top_n]
        return results
