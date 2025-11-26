"""
High-level orchestration around the MT5 Strategy Tester integration
implemented in MQL5.  The engine is responsible for generating
configuration files, triggering terminal runs, and post-processing the
CSV reports exported by `PerformanceAnalyzer.mq5`.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Sequence

import subprocess

from . import metrics, walkforward


@dataclass
class TesterRunConfig:
    terminal_path: Path
    expert_path: Path
    config_path: Path
    results_dir: Path
    symbols: Sequence[str]
    timeframe: str = "H1"
    deposit: float = 10000.0
    leverage: int = 100
    optimization: bool = True
    genetic: bool = True


class StrategyTesterEngine:
    def __init__(self, config: TesterRunConfig) -> None:
        self.config = config
        self.config.results_dir.mkdir(parents=True, exist_ok=True)

    def build_ini(self, ini_path: Path | None = None) -> Path:
        ini_path = ini_path or self.config.config_path
        lines = [
            "[Tester]",
            f"Expert={self.config.expert_path}",
            f"Symbol={','.join(self.config.symbols)}",
            f"Period={self.config.timeframe}",
            f"Deposit={self.config.deposit}",
            f"Leverage={self.config.leverage}",
            f"Optimization={'true' if self.config.optimization else 'false'}",
            f"GeneticOptimization={'true' if self.config.genetic else 'false'}",
            f"Report={self.config.results_dir / 'summary'}",
            "UseCloud=0",
            "",
            "[TesterInputs]",
            "tests/BacktestConfig.mq5=true",
        ]
        ini_path.write_text("\n".join(lines))
        return ini_path

    def run(self, timeout: int = 600) -> None:
        ini_path = self.build_ini()
        cmd = [
            str(self.config.terminal_path),
            f"/config:{ini_path}",
        ]
        subprocess.run(cmd, check=True, timeout=timeout)

    def collect_reports(self) -> Dict[str, metrics.PerformanceSummary]:
        summaries: Dict[str, metrics.PerformanceSummary] = {}
        for csv_path in self.config.results_dir.glob("*_history.csv"):
            _, summary = metrics.load_trade_history(csv_path)
            summaries[csv_path.stem] = summary
        return summaries

    def summarize(self) -> List[str]:
        reports = self.collect_reports()
        lines = [
            "label,sharpe,max_drawdown,win_rate,profit_factor,recovery_factor,total_trades,total_profit"
        ]
        for label, summary in reports.items():
            lines.append(
                ",".join(
                    [
                        label,
                        f"{summary.sharpe_ratio:.3f}",
                        f"{summary.max_drawdown:.2f}",
                        f"{summary.win_rate:.2%}",
                        f"{summary.profit_factor:.2f}",
                        f"{summary.recovery_factor:.2f}",
                        str(summary.total_trades),
                        f"{summary.total_profit:.2f}",
                    ]
                )
            )
        return lines


def plan_walkforward(
    start: str,
    end: str,
    in_sample: int,
    out_sample: int,
) -> List[walkforward.WalkForwardWindow]:
    planner = walkforward.WalkForwardPlanner(in_sample, out_sample)
    start_dt = datetime.fromisoformat(start)
    end_dt = datetime.fromisoformat(end)
    return planner.generate(start_dt, end_dt)
