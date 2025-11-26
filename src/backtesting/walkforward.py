from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Sequence, Type

import pandas as pd

from .engine import BacktestEngine, BacktestResult
from .metrics import PerformanceReport, compute_performance_report
from .optimizer import StrategyOptimizer


@dataclass
class WalkForwardSlice:
    index: int
    train_range: tuple[pd.Timestamp, pd.Timestamp]
    test_range: tuple[pd.Timestamp, pd.Timestamp]
    best_params: Dict[str, Any]
    optimization_score: float
    train_performance: PerformanceReport
    test_result: BacktestResult


@dataclass
class WalkForwardRun:
    slices: List[WalkForwardSlice]
    combined_performance: PerformanceReport


class WalkForwardAnalyzer:
    def __init__(self, engine: BacktestEngine, data: pd.DataFrame) -> None:
        self.engine = engine
        self.data = data

    def run(
        self,
        strategy_cls: Type,
        param_grid: Dict[str, Sequence[Any]],
        train_size: int,
        test_size: int,
        step: int | None = None,
        metric: str = "sharpe",
    ) -> WalkForwardRun:
        step = step or test_size
        slices: List[WalkForwardSlice] = []
        combined_equity: List[pd.Series] = []
        combined_trades = []

        end = len(self.data) - train_size - test_size
        if end < 0:
            raise ValueError("Not enough data for the requested walk-forward windows.")

        for i, start in enumerate(range(0, len(self.data) - train_size - test_size + 1, step)):
            train = self.data.iloc[start : start + train_size]
            test = self.data.iloc[start + train_size : start + train_size + test_size]

            train_optimizer = StrategyOptimizer(self.engine, train)
            best = train_optimizer.grid_search(
                strategy_cls, param_grid, metric=metric, maximize=True, top_n=1
            )[0]

            train_performance = best.backtest.performance
            best_params = best.params
            test_strategy = strategy_cls(**best_params)
            test_result = self.engine.run(test, test_strategy)

            slices.append(
                WalkForwardSlice(
                    index=i,
                    train_range=(train.index[0], train.index[-1]),
                    test_range=(test.index[0], test.index[-1]),
                    best_params=best_params,
                    optimization_score=best.score,
                    train_performance=train_performance,
                    test_result=test_result,
                )
            )
            combined_equity.append(test_result.equity_curve)
            combined_trades.extend(test_result.trades)

        merged_equity = pd.concat(combined_equity).sort_index()
        exposure = sum(len(s.test_result.positions[s.test_result.positions != 0]) for s in slices)
        exposure /= max(len(merged_equity), 1)
        combined_perf = compute_performance_report(
            merged_equity,
            combined_trades,
            risk_free_rate=self.engine.config.risk_free_rate,
            exposure=exposure,
        )

        return WalkForwardRun(slices=slices, combined_performance=combined_perf)
