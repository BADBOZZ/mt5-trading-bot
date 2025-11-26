"""
Python level helpers that mirror the Strategy Tester configuration.
They are primarily used to produce reproducible `.ini` files, `.set`
parameter ranges, and walk-forward plans which are then consumed inside
MetaTrader by the MQL5 layer.
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import List, Sequence

import json

from . import config, walkforward
from .engine import StrategyTesterEngine, TesterRunConfig


@dataclass(frozen=True)
class OptimizationParam:
    name: str
    start: float
    stop: float
    step: float


DEFAULT_PARAMS: Sequence[OptimizationParam] = (
    OptimizationParam("InpLots", 0.05, 1.0, 0.05),
    OptimizationParam("InpRiskPct", 0.25, 3.0, 0.25),
    OptimizationParam("InpStopLoss", 150, 600, 25),
    OptimizationParam("InpTakeProfit", 200, 1200, 25),
    OptimizationParam("InpTrail", 50, 400, 25),
    OptimizationParam("InpATRPeriod", 7, 28, 1),
    OptimizationParam("InpSessionFilter", 0, 1, 1),
)


class OptimizationScript:
    def __init__(self, params: Sequence[OptimizationParam] | None = None) -> None:
        self.params: List[OptimizationParam] = list(params or DEFAULT_PARAMS)

    def export_ranges(self, target: Path) -> Path:
        payload = [asdict(param) for param in self.params]
        target.write_text(json.dumps(payload, indent=2))
        return target

    def build_tester_configs(
        self,
        paths: config.StrategyTesterPaths,
        optimization: config.OptimizationSettings,
        start_date: str,
        end_date: str,
    ) -> List[TesterRunConfig]:
        planner = walkforward.WalkForwardPlanner(
            optimization.in_sample_days, optimization.out_sample_days
        )
        start_dt = datetime.fromisoformat(start_date)
        end_dt = datetime.fromisoformat(end_date)
        windows = planner.generate(start_dt, end_dt)
        configs: List[TesterRunConfig] = []
        for index, window in enumerate(windows):
            results_dir = paths.results / f"wf_{index:02d}"
            results_dir.mkdir(parents=True, exist_ok=True)
            (results_dir / "window.json").write_text(
                json.dumps(
                    {
                        "in_start": window.in_start.isoformat(),
                        "in_end": window.in_end.isoformat(),
                        "out_start": window.out_start.isoformat(),
                        "out_end": window.out_end.isoformat(),
                    },
                    indent=2,
                )
            )
            config_path = paths.config.with_name(f"{paths.config.stem}_wf{index:02d}.ini")
            tester_config = TesterRunConfig(
                terminal_path=paths.terminal,
                expert_path=paths.expert,
                config_path=config_path,
                results_dir=results_dir,
                symbols=optimization.symbols,
                timeframe=optimization.timeframe,
            )
            configs.append(tester_config)
        return configs

    def run(self, start_date: str, end_date: str, execute: bool = False) -> None:
        paths, optimization = config.load_from_env()
        configs = self.build_tester_configs(paths, optimization, start_date, end_date)
        for tester_config in configs:
            engine = StrategyTesterEngine(tester_config)
            ini_path = engine.build_ini()
            print(f"[WF] Wrote config -> {ini_path}")
            if execute:
                engine.run()
            summary = engine.summarize()
            (tester_config.results_dir / "summary.csv").write_text("\n".join(summary))
