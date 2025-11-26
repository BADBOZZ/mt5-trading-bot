"""High-level integration helpers for the MT5 Strategy Tester."""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import datetime
from pathlib import Path
from typing import Iterable, List, Sequence

from .metrics import BacktestSummary, summarize_trades
from .optimizer import ParameterSpace
from .walkforward import WalkForwardPlan, build_walk_forward_plan


@dataclass
class StrategyTesterJob:
    """Holds configuration for a single MT5 Strategy Tester run."""

    expert_name: str
    symbols: Sequence[str]
    timeframe: str
    start_date: datetime
    end_date: datetime
    deposit: float = 10000
    currency: str = "USD"
    spread: int = 10
    optimization_mode: str = "complete"
    optimization_criterion: str = "Custom max"
    parameter_space: ParameterSpace | None = None
    walk_forward: WalkForwardPlan | None = None
    comment: str | None = None

    def to_ini(self) -> str:
        """Render the job as a Strategy Tester .ini template."""

        lines = [
            "[Tester]",
            f"Expert={self.expert_name}",
            f"Symbol={self.symbols[0]}",
            f"Period={self.timeframe}",
            f"Deposit={self.deposit}",
            f"Currency={self.currency}",
            f"Optimization={self.optimization_mode}",
            f"OptimizationCriterion={self.optimization_criterion}",
            f"Spread={self.spread}",
            f"FromDate={self.start_date:%Y.%m.%d}",
            f"ToDate={self.end_date:%Y.%m.%d}",
            f"ForwardMode={(1 if self.walk_forward else 0)}",
        ]

        if self.comment:
            lines.append(f"ExpertParametersComment={self.comment}")

        if len(self.symbols) > 1:
            lines.append(f"; Multi-currency basket: {','.join(self.symbols)}")

        if self.walk_forward:
            lines.append(f"; Walk-forward: {self.walk_forward.to_mt5_forward_mode()}")

        return "\n".join(lines)


class StrategyTesterIntegration:
    """Owns file export + reporting for Strategy Tester automation."""

    def __init__(self, workspace: str | Path = "tester_jobs") -> None:
        self.workspace = Path(workspace)
        self.workspace.mkdir(parents=True, exist_ok=True)

    def export_job(self, job: StrategyTesterJob) -> Path:
        """Write a tester .ini (and .set if required) to disk."""

        job_path = self.workspace / f"{job.expert_name}_{job.timeframe}.ini"
        job_path.write_text(job.to_ini())

        if job.parameter_space:
            set_path = job_path.with_suffix(".set")
            set_path.write_text(job.parameter_space.to_mt5_set())

        return job_path

    def export_batch(self, jobs: Iterable[StrategyTesterJob]) -> List[Path]:
        """Export multiple jobs, one per symbol basket."""

        return [self.export_job(job) for job in jobs]

    def build_multicurrency_jobs(
        self,
        base_job: StrategyTesterJob,
        baskets: dict[str, Sequence[str]],
    ) -> List[StrategyTesterJob]:
        """Clone the base configuration for each symbol basket."""

        jobs: List[StrategyTesterJob] = []
        for name, symbols in baskets.items():
            jobs.append(
                replace(
                    base_job,
                    expert_name=f"{base_job.expert_name}_{name}",
                    symbols=tuple(symbols),
                )
            )
        return jobs

    def create_walk_forward_job(
        self,
        base_job: StrategyTesterJob,
        insample_days: int,
        outsample_days: int,
        step_days: int | None = None,
    ) -> StrategyTesterJob:
        """Attach a walk-forward plan to an existing job."""

        plan = build_walk_forward_plan(
            base_job.start_date,
            base_job.end_date,
            insample_days,
            outsample_days,
            step_days,
        )

        return replace(
            base_job,
            walk_forward=plan,
            comment=plan.to_mt5_forward_mode(),
        )

    def summarize(self, trade_history: Sequence[dict]) -> BacktestSummary:
        """Return a BacktestSummary for a Strategy Tester trade export."""

        return summarize_trades(trade_history)
