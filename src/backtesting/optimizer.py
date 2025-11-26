from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from typing import Any, Dict, List, Sequence, Type

import numpy as np

from .engine import BacktestEngine, BacktestResult


@dataclass
class OptimizationResult:
    params: Dict[str, Any]
    score: float
    metric: str
    backtest: BacktestResult


class StrategyOptimizer:
    def __init__(self, engine: BacktestEngine, data) -> None:
        self.engine = engine
        self.data = data

    def grid_search(
        self,
        strategy_cls: Type,
        param_grid: Dict[str, Sequence[Any]],
        metric: str = "sharpe",
        maximize: bool = True,
        top_n: int = 5,
    ) -> List[OptimizationResult]:
        combos = list(product(*param_grid.values()))
        keys = list(param_grid.keys())

        results: List[OptimizationResult] = []
        for combo in combos:
            params = dict(zip(keys, combo))
            result = self._evaluate(strategy_cls, params, metric)
            results.append(result)

        return self._sorted(results, maximize)[:top_n]

    def random_search(
        self,
        strategy_cls: Type,
        param_ranges: Dict[str, Sequence[Any]],
        iterations: int = 20,
        metric: str = "sharpe",
        maximize: bool = True,
        seed: int | None = None,
    ) -> List[OptimizationResult]:
        rng = np.random.default_rng(seed)
        results: List[OptimizationResult] = []
        for _ in range(iterations):
            params = {
                key: rng.choice(values) if isinstance(values, Sequence) else values
                for key, values in param_ranges.items()
            }
            result = self._evaluate(strategy_cls, params, metric)
            results.append(result)
        return self._sorted(results, maximize)

    # ------------------------------------------------------------------ #
    def _evaluate(self, strategy_cls: Type, params: Dict[str, Any], metric: str) -> OptimizationResult:
        strategy = strategy_cls(**params)
        backtest = self.engine.run(self.data, strategy)
        score = backtest.performance.summary.get(metric)
        if score is None:
            raise ValueError(f"Metric '{metric}' not found in performance summary.")
        return OptimizationResult(params=params, score=score, metric=metric, backtest=backtest)

    @staticmethod
    def _sorted(results: List[OptimizationResult], maximize: bool) -> List[OptimizationResult]:
        return sorted(results, key=lambda r: r.score, reverse=maximize)
