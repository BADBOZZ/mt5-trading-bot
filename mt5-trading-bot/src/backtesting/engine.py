from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

from .data_loader import TradeHistoryExporter
from .walkforward import WalkForwardWindow, generate_walk_forward_windows


@dataclass
class StrategyTesterJob:
    """Encapsulates a single MT5 Strategy Tester run."""

    expert: str
    symbol: str
    timeframe: str
    start_date: datetime
    end_date: datetime
    spread: int = 10
    forward_mode: int = 0
    forward_date: datetime | None = None
    deposit: float = 10000.0
    leverage: int = 100
    genetic_optimization: bool = True
    enable_optimization: bool = False
    report_name: str = "strategy_report"
    optimization_criterion: str = "Balance max"
    custom_inputs: Dict[str, float | int | str] = field(default_factory=dict)

    def to_ini_lines(self) -> List[str]:
        """Render the tester job into `.ini` lines that MT5 understands."""
        tester_block = [
            "[Tester]",
            f"Expert={self.expert}",
            f"Symbol={self.symbol}",
            f"Period={self.timeframe}",
            f"Model=2",  # every tick based on real ticks
            f"Spread={self.spread}",
            f"FromDate={self.start_date.strftime('%Y.%m.%d')}",
            f"ToDate={self.end_date.strftime('%Y.%m.%d')}",
            f"ForwardMode={self.forward_mode}",
            f"ForwardDate={self.forward_date.strftime('%Y.%m.%d') if self.forward_date else ''}",
            f"Deposit={self.deposit}",
            f"Leverage={self.leverage}",
            f"Optimization={'true' if self.enable_optimization else 'false'}",
            f"GeneticOptimization={'true' if self.genetic_optimization else 'false'}",
            f"OptimizationCriterion={self.optimization_criterion}",
            f"Report={self.report_name}",
        ]
        if self.custom_inputs:
            tester_block.append("Inputs=" + ";".join(f"{k}={v}" for k, v in self.custom_inputs.items()))
        return tester_block


class StrategyTesterIntegration:
    """
    Produces MT5 Strategy Tester configuration files, executes jobs, and
    exports trade logs for downstream analytics.
    """

    def __init__(self, terminal_path: Path, workspace: Path | None = None) -> None:
        self.terminal_path = Path(terminal_path)
        self.workspace = Path(workspace or Path.cwd())
        self.config_dir = self.workspace / "build" / "strategy_tester"
        self.report_dir = self.workspace / "reports" / "backtests"
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.report_dir.mkdir(parents=True, exist_ok=True)

    def build_job(self, **kwargs) -> StrategyTesterJob:
        """Convenience factory to create tester jobs with sane defaults."""
        return StrategyTesterJob(**kwargs)

    def write_ini(self, job: StrategyTesterJob) -> Path:
        """Persist the tester configuration to disk."""
        ini_path = self.config_dir / f"{job.report_name}.ini"
        lines = [
            "[Common]",
            "Login=",
            "Password=",
            "Server=",
            "",
        ] + job.to_ini_lines()
        ini_path.write_text("\n".join(lines), encoding="utf-8")
        return ini_path

    def run_job(self, job: StrategyTesterJob, timeout: int = 900) -> Path:
        """
        Execute the tester job via the MT5 terminal.
        The method returns the expected HTML report location.
        """
        ini_path = self.write_ini(job)
        report_path = self.report_dir / f"{job.report_name}.html"
        if not self.terminal_path.exists():
            raise FileNotFoundError(f"MT5 terminal not found at {self.terminal_path}")
        cmd = [
            str(self.terminal_path),
            "/portable",
            f"/config:{ini_path}",
        ]
        subprocess.run(cmd, check=True, timeout=timeout)
        return report_path

    def plan_walk_forward(
        self,
        start: datetime,
        end: datetime,
        train_months: int,
        test_months: int,
    ) -> List[WalkForwardWindow]:
        """Generate walk-forward windows used for sequential optimizations."""
        return list(generate_walk_forward_windows(start, end, train_months, test_months))

    def schedule_walk_forward_jobs(
        self,
        expert: str,
        symbol: str,
        timeframe: str,
        windows: Sequence[WalkForwardWindow],
        **job_kwargs,
    ) -> List[StrategyTesterJob]:
        """Create tester jobs for each walk-forward segment."""
        jobs: List[StrategyTesterJob] = []
        for idx, window in enumerate(windows, start=1):
            job = StrategyTesterJob(
                expert=expert,
                symbol=symbol,
                timeframe=timeframe,
                start_date=window.train_start,
                end_date=window.test_end,
                forward_mode=1,
                forward_date=window.test_start,
                report_name=f"{symbol}_{timeframe}_wf_{idx}",
                enable_optimization=True,
                **job_kwargs,
            )
            jobs.append(job)
        return jobs

    def schedule_multi_currency(
        self,
        expert: str,
        symbols: Iterable[str],
        timeframe: str,
        start_date: datetime,
        end_date: datetime,
        **job_kwargs,
    ) -> List[StrategyTesterJob]:
        """Generate one tester job per symbol for multi-currency evaluation."""
        jobs: List[StrategyTesterJob] = []
        for symbol in symbols:
            jobs.append(
                StrategyTesterJob(
                    expert=expert,
                    symbol=symbol,
                    timeframe=timeframe,
                    start_date=start_date,
                    end_date=end_date,
                    report_name=f"{symbol}_{timeframe}",
                    **job_kwargs,
                )
            )
        return jobs

    def export_trade_history(self, report_html: Path, output_csv: Path) -> Path:
        """
        Use the common MT5 HTML report as the source for CSV trade history.
        The exporter focuses on the Deals table so the performance scripts can
        calculate custom statistics downstream.
        """
        exporter = TradeHistoryExporter(report_html)
        trades = exporter.extract_trades()
        output_csv.write_text("\n".join(trades), encoding="utf-8")
        return output_csv

    def summarize_job_plan(self, jobs: Sequence[StrategyTesterJob]) -> str:
        """Return a JSON summary describing the planned Strategy Tester jobs."""
        payload = [
            {
                "expert": job.expert,
                "symbol": job.symbol,
                "timeframe": job.timeframe,
                "start": job.start_date.isoformat(),
                "end": job.end_date.isoformat(),
                "optimization": job.enable_optimization,
                "forward_mode": job.forward_mode,
                "report": job.report_name,
            }
            for job in jobs
        ]
        return json.dumps(payload, indent=2)
