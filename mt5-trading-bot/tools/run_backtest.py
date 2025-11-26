#!/usr/bin/env python3
"""Command line helper around the MT5 Strategy Tester integration layer."""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT / "src") not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT / "src"))

from backtesting.config import BacktestConfig  # type: ignore  # noqa: E402
from backtesting.engine import StrategyTesterEngine  # type: ignore  # noqa: E402
from backtesting.optimizer import StrategyOptimizer  # type: ignore  # noqa: E402
from backtesting.walkforward import WalkForwardRunner  # type: ignore  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MT5 Strategy Tester runner")
    parser.add_argument("--config", type=Path, required=True, help="Path to JSON/YAML backtest config")
    parser.add_argument("--optimize", action="store_true", help="Run grid search optimization")
    parser.add_argument("--walk-forward", action="store_true", help="Run configured walk-forward windows")
    parser.add_argument("--multi-currency", action="store_true", help="Run sequential tests for each listed symbol")
    parser.add_argument("--export", type=Path, default=None, help="Optional path for combined trade export")
    return parser.parse_args()


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] %(levelname)s - %(message)s")
    args = parse_args()
    config = BacktestConfig.from_file(args.config)
    config.ensure_report_dir()
    engine = StrategyTesterEngine(config)

    if args.optimize:
        optimizer = StrategyOptimizer(config, engine)
        summary = optimizer.run_grid_search()
        leaderboard_path = config.report.output_dir / "optimization_leaderboard.csv"
        optimizer.generate_report(summary, leaderboard_path)
        print(engine.render_summary())
    elif args.walk_forward:
        runner = WalkForwardRunner(config, engine)
        report = runner.run()
        print(engine.render_summary())
        if report.failing_windows:
            print(f"Failing windows: {report.failing_windows}")
    elif args.multi_currency:
        engine.run_multi_currency()
        print(engine.render_summary())
    else:
        engine.run()
        print(engine.render_summary())

    if args.export:
        engine.export_trade_history(args.export)


if __name__ == "__main__":
    main()
