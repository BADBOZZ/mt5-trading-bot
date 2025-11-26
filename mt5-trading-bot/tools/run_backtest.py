#!/usr/bin/env python3

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

from src.backtesting.engine import StrategyTesterIntegration
from src.backtesting.optimizer import OptimizationScriptBuilder


def _parse_date(value: str) -> datetime:
    try:
        return datetime.fromisoformat(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"Invalid date '{value}'") from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MT5 Strategy Tester helper CLI")
    parser.add_argument("--terminal", required=True, help="Path to terminal64.exe")
    parser.add_argument("--expert", required=True, help="Expert file name, e.g. MyEA.ex5")
    parser.add_argument("--symbol", help="Primary symbol for single runs")
    parser.add_argument("--symbols", nargs="+", help="Symbol list for multi-currency batches")
    parser.add_argument("--timeframe", default="M15", help="Tester timeframe, e.g. H1")
    parser.add_argument("--start", type=_parse_date, required=True, help="Backtest start date (ISO)")
    parser.add_argument("--end", type=_parse_date, required=True, help="Backtest end date (ISO)")
    parser.add_argument("--spread", type=int, default=10, help="Synthetic spread in points")
    parser.add_argument("--deposit", type=float, default=10000.0, help="Initial deposit")
    parser.add_argument("--leverage", type=int, default=100, help="Account leverage")
    parser.add_argument("--optimization", action="store_true", help="Enable parameter optimization")
    parser.add_argument("--walk-forward", action="store_true", help="Use walk-forward segmentation")
    parser.add_argument("--train-months", type=int, default=3, help="Walk-forward train window size")
    parser.add_argument("--test-months", type=int, default=1, help="Walk-forward test window size")
    parser.add_argument("--execute", action="store_true", help="Execute the generated jobs immediately")
    parser.add_argument("--set-file", help="Optional path for generated .set optimization file")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    integration = StrategyTesterIntegration(Path(args.terminal).expanduser())

    if args.walk_forward:
        windows = integration.plan_walk_forward(args.start, args.end, args.train_months, args.test_months)
        jobs = integration.schedule_walk_forward_jobs(
            expert=args.expert,
            symbol=args.symbol or (args.symbols[0] if args.symbols else ""),
            timeframe=args.timeframe,
            windows=windows,
            spread=args.spread,
            deposit=args.deposit,
            leverage=args.leverage,
        )
    elif args.symbols:
        jobs = integration.schedule_multi_currency(
            expert=args.expert,
            symbols=args.symbols,
            timeframe=args.timeframe,
            start_date=args.start,
            end_date=args.end,
            spread=args.spread,
            deposit=args.deposit,
            leverage=args.leverage,
            enable_optimization=args.optimization,
        )
    else:
        if not args.symbol:
            raise SystemExit("Either --symbol or --symbols is required when not using walk-forward mode")
        jobs = [
            integration.build_job(
                expert=args.expert,
                symbol=args.symbol,
                timeframe=args.timeframe,
                start_date=args.start,
                end_date=args.end,
                spread=args.spread,
                deposit=args.deposit,
                leverage=args.leverage,
                enable_optimization=args.optimization,
            )
        ]

    if args.set_file:
        builder = OptimizationScriptBuilder()
        set_path = Path(args.set_file).expanduser()
        builder.write_set_file(set_path)
        print(f"Optimization parameter description:\n{builder.describe()}")
        print(f"Wrote MT5 .set file to {set_path}")

    print(integration.summarize_job_plan(jobs))

    if args.execute:
        for job in jobs:
            integration.run_job(job)


if __name__ == "__main__":
    main()
