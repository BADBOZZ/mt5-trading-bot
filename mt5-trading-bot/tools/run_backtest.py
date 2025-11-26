#!/usr/bin/env python3
"""
Convenience CLI around the MT5 Strategy Tester integration.  It writes
an `.ini` configuration file, optionally executes the terminal, and
summarises exported reports.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List

from src.backtesting.engine import StrategyTesterEngine, TesterRunConfig, plan_walkforward
from src.backtesting import walkforward


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run MetaTrader backtests via Strategy Tester.")
    parser.add_argument("--terminal", type=Path, required=True, help="Path to terminal64.exe")
    parser.add_argument("--expert", type=Path, required=True, help="Path to compiled EA file.")
    parser.add_argument("--config", type=Path, default=Path("tester.ini"), help="Output ini file.")
    parser.add_argument("--results", type=Path, default=Path("tester_results"), help="Directory for CSV exports.")
    parser.add_argument("--symbols", type=str, default="EURUSD,GBPUSD", help="Comma separated list of symbols.")
    parser.add_argument("--timeframe", type=str, default="H1")
    parser.add_argument("--deposit", type=float, default=10000.0)
    parser.add_argument("--leverage", type=int, default=100)
    parser.add_argument("--start", type=str, required=True, help="Backtest start date YYYY-MM-DD")
    parser.add_argument("--end", type=str, required=True, help="Backtest end date YYYY-MM-DD")
    parser.add_argument("--in-sample", type=int, default=90)
    parser.add_argument("--out-sample", type=int, default=30)
    parser.add_argument("--execute", action="store_true", help="Execute MT5 terminal after writing config.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    symbols: List[str] = [symbol.strip().upper() for symbol in args.symbols.split(",") if symbol.strip()]
    config = TesterRunConfig(
        terminal_path=args.terminal,
        expert_path=args.expert,
        config_path=args.config,
        results_dir=args.results,
        symbols=symbols,
        timeframe=args.timeframe,
        deposit=args.deposit,
        leverage=args.leverage,
    )
    engine = StrategyTesterEngine(config)
    ini_path = engine.build_ini()
    print(f"Wrote tester config -> {ini_path}")

    windows = plan_walkforward(args.start, args.end, args.in_sample, args.out_sample)
    walkforward_path = args.config.with_suffix(".walkforward.json")
    walkforward.serialize_plan(windows, walkforward_path)
    print(f"Saved walk-forward plan -> {walkforward_path}")

    if args.execute:
        print("Executing Strategy Tester run...")
        engine.run()

    summary_lines = engine.summarize()
    summary_path = args.results / "host_summary.csv"
    summary_path.write_text("\n".join(summary_lines))
    print(f"Aggregated performance -> {summary_path}")


if __name__ == "__main__":
    main()
