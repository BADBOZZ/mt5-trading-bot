"""Walk-forward testing orchestration that reuses the Strategy Tester engine."""
from __future__ import annotations

from dataclasses import dataclass
from typing import List

import logging

from .config import BacktestConfig
from .engine import StrategyResult, StrategyTesterEngine

LOGGER = logging.getLogger(__name__)


@dataclass(slots=True)
class WalkForwardReport:
    results: List[StrategyResult]
    average_sharpe: float
    failing_windows: List[str]


class WalkForwardRunner:
    """Executes each walk-forward window and aggregates the results."""

    def __init__(self, config: BacktestConfig, engine: StrategyTesterEngine) -> None:
        if not config.walk_forward.enabled:
            raise RuntimeError("Walk-forward configuration must be enabled")
        self.config = config
        self.engine = engine

    def run(self) -> WalkForwardReport:
        labels = [f"WF_{idx}" for idx, _ in enumerate(self.config.walk_forward.windows)]
        results = self.engine.run_walk_forward(labels)
        average_sharpe = sum(result.stats.sharpe_ratio for result in results) / max(len(results), 1)
        failing = [
            result.walk_forward_window or ""
            for result in results
            if result.stats.sharpe_ratio < self.config.optimization.criteria_thresholds.get("min_sharpe", 0.5)
        ]
        if failing:
            LOGGER.warning("Walk-forward failing windows: %s", failing)
        return WalkForwardReport(results=results, average_sharpe=average_sharpe, failing_windows=failing)


__all__ = ["WalkForwardRunner", "WalkForwardReport"]
