"""Strategy Tester orchestration utilities to drive MT5 from Python."""
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence

import json
import logging
import subprocess
import textwrap
import time

import pandas as pd

from .config import BacktestConfig
from .metrics import PerformanceStats, summarize_performance

try:  # Optional plotting dependency
    import matplotlib.pyplot as plt
except Exception:  # pragma: no cover - optional dependency
    plt = None

LOGGER = logging.getLogger(__name__)


@dataclass(slots=True)
class StrategyResult:
    """Represents the outcome of a single Strategy Tester run."""

    parameters: Dict[str, float]
    trades: pd.DataFrame
    stats: PerformanceStats
    equity_curve: pd.Series
    walk_forward_window: Optional[str] = None

    def to_dict(self) -> Dict:
        payload = {
            "parameters": self.parameters,
            "stats": asdict(self.stats),
            "walk_forward_window": self.walk_forward_window,
        }
        payload["trades"] = self.trades.to_dict(orient="records")
        return payload


class StrategyTesterEngine:
    """Creates MT5 .ini configs, runs the Strategy Tester, and aggregates reports."""

    def __init__(self, config: BacktestConfig) -> None:
        self.config = config
        self.results: List[StrategyResult] = []

    # ------------------------------------------------------------------
    # Strategy Tester lifecycle helpers
    # ------------------------------------------------------------------
    def _build_run_dir(self) -> Path:
        timestamp = int(time.time())
        run_dir = self.config.report.output_dir / f"run_{timestamp}"
        run_dir.mkdir(parents=True, exist_ok=True)
        return run_dir

    def _write_tester_ini(self, run_dir: Path, parameters: Dict[str, float]) -> Path:
        ini_text = self.config.to_ini(parameters)
        ini_path = run_dir / "tester.ini"
        ini_path.write_text(ini_text, encoding="utf-8")
        LOGGER.debug("Tester INI written to %s", ini_path)
        return ini_path

    def _invoke_terminal(self, ini_path: Path) -> None:
        if not self.config.terminal_path:
            LOGGER.warning("MT5 terminal path is not set; skipping actual Strategy Tester invocation")
            return
        cmd = [
            str(self.config.terminal_path),
            f"/config:{ini_path}",
        ]
        LOGGER.info("Launching MT5 Strategy Tester: %s", " ".join(cmd))
        subprocess.run(cmd, check=True)

    def _load_trade_history(self, run_dir: Path) -> pd.DataFrame:
        trade_path = run_dir / "trades.csv"
        if not trade_path.exists():
            LOGGER.warning("Trade history %s not found; returning empty frame", trade_path)
            return pd.DataFrame(columns=["ticket", "time", "symbol", "profit", "balance"])
        frame = pd.read_csv(trade_path)
        if "time" in frame.columns:
            frame["time"] = pd.to_datetime(frame["time"], utc=True)
        return frame

    def _equity_curve(self, trades: pd.DataFrame) -> pd.Series:
        if trades.empty or "profit" not in trades:
            return pd.Series(dtype=float)
        balance = trades["profit"].cumsum() + self.config.deposit
        balance.index = trades.get("time", pd.RangeIndex(len(balance)))
        return balance

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def run(self, parameter_overrides: Optional[Dict[str, float]] = None, walk_forward_window: Optional[str] = None) -> StrategyResult:
        run_dir = self._build_run_dir()
        merged_parameters = self.config.parameters | (parameter_overrides or {})
        tester_ini = self._write_tester_ini(run_dir, merged_parameters)
        self._invoke_terminal(tester_ini)

        trades = self._load_trade_history(run_dir)
        stats = summarize_performance(trades)
        equity = self._equity_curve(trades)
        result = StrategyResult(
            parameters=merged_parameters,
            trades=trades,
            stats=stats,
            equity_curve=equity,
            walk_forward_window=walk_forward_window,
        )
        self.results.append(result)

        if self.config.report.export_json:
            json_path = run_dir / "result.json"
            json_path.write_text(json.dumps(result.to_dict(), indent=2, default=str), encoding="utf-8")
        if self.config.report.export_trades:
            trades.to_csv(run_dir / "trades.csv", index=False)
        if self.config.report.export_equity:
            equity.to_csv(run_dir / "equity.csv", header=["equity"])
        if self.config.report.generate_charts:
            self._generate_charts(run_dir, result)
        return result

    def run_multi_currency(self) -> List[StrategyResult]:
        results: List[StrategyResult] = []
        for symbol_cfg in self.config.symbols:
            overrides = {"Symbol": symbol_cfg.symbol, **self.config.parameters}
            result = self.run(parameter_overrides=overrides)
            results.append(result)
        return results

    def run_walk_forward(self, windows: Sequence[str] | None = None) -> List[StrategyResult]:
        if not self.config.walk_forward.enabled:
            raise RuntimeError("Walk-forward configuration is disabled")
        windows = windows or [f"window_{idx}" for idx, _ in enumerate(self.config.walk_forward.windows)]
        results: List[StrategyResult] = []
        for label, wf_window in zip(windows, self.config.walk_forward.windows):
            overrides = self.config.parameters | {
                "WFInSampleStart": wf_window.in_sample_start.timestamp(),
                "WFInSampleEnd": wf_window.in_sample_end.timestamp(),
                "WFOutSampleStart": wf_window.out_sample_start.timestamp(),
                "WFOutSampleEnd": wf_window.out_sample_end.timestamp(),
            }
            LOGGER.info("Running walk-forward window %s", label)
            result = self.run(parameter_overrides=overrides, walk_forward_window=label)
            results.append(result)
        return results

    def export_trade_history(self, destination: Path) -> None:
        if not self.results:
            raise RuntimeError("No results to export yet")
        combined = pd.concat([result.trades.assign(run=index) for index, result in enumerate(self.results)], ignore_index=True)
        destination.parent.mkdir(parents=True, exist_ok=True)
        combined.to_csv(destination, index=False)
        LOGGER.info("Trade history exported to %s", destination)

    def strategy_leaderboard(self) -> pd.DataFrame:
        if not self.results:
            raise RuntimeError("No Strategy Tester results available")
        rows = []
        for result in self.results:
            row = asdict(result.stats)
            row["parameters"] = result.parameters
            row["window"] = result.walk_forward_window
            rows.append(row)
        leaderboard = pd.DataFrame(rows).sort_values(by="sharpe_ratio", ascending=False)
        return leaderboard

    def _generate_charts(self, run_dir: Path, result: StrategyResult) -> None:
        if plt is None or result.equity_curve.empty:
            LOGGER.debug("Skipping chart generation (matplotlib not available or equity empty)")
            return
        fig, ax = plt.subplots(figsize=(10, 4))
        ax.plot(result.equity_curve.index, result.equity_curve.values, label="Equity Curve")
        ax.set_title("Strategy Tester Equity")
        ax.set_ylabel(self.config.deposit_currency)
        ax.legend()
        fig.autofmt_xdate()
        chart_path = run_dir / "equity.png"
        fig.savefig(chart_path, dpi=150)
        plt.close(fig)
        LOGGER.info("Equity chart saved to %s", chart_path)

    def generate_strategy_comparison(self, destinations: Sequence[Path]) -> None:
        leaderboard = self.strategy_leaderboard()
        if leaderboard.empty:
            LOGGER.warning("No data available for strategy comparison")
            return
        for path in destinations:
            path.parent.mkdir(parents=True, exist_ok=True)
            leaderboard.to_csv(path, index=False)
            LOGGER.info("Strategy comparison exported to %s", path)

    def render_summary(self) -> str:
        if not self.results:
            return "No runs executed"
        lines = ["Strategy Tester Summary:"]
        for idx, result in enumerate(self.results, start=1):
            stats = result.stats
            lines.append(
                textwrap.dedent(
                    f"""
                    Run #{idx}
                      Parameters: {result.parameters}
                      Sharpe: {stats.sharpe_ratio} | MDD: {stats.max_drawdown} | Win%: {stats.win_rate}
                      Profit Factor: {stats.profit_factor} | Recovery: {stats.recovery_factor}
                    """
                ).strip()
            )
        return "\n".join(lines)


__all__ = ["StrategyTesterEngine", "StrategyResult"]
