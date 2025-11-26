#!/usr/bin/env python3
"""Command line helper for launching MT5 Strategy Tester runs."""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from src.backtesting.config import (
    OptimizationInputRange,
    StrategyTesterConfig,
    SymbolConfig,
)
from src.backtesting.engine import StrategyTesterError, StrategyTesterIntegration
from src.backtesting.optimizer import GridSearchOptimizer
from src.backtesting.walkforward import SlidingWindowWalkForward


def parse_date(value: str) -> datetime:
    try:
        return datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc


def parse_inputs(pairs: List[str]) -> Dict[str, float]:
    values: Dict[str, float] = {}
    for pair in pairs:
        if "=" not in pair:
            raise argparse.ArgumentTypeError(f"Invalid input override: {pair}")
        key, raw_value = pair.split("=", maxsplit=1)
        values[key] = float(raw_value)
    return values


def build_symbols(symbols: List[str], timeframe: str) -> List[SymbolConfig]:
    if not symbols:
        return [SymbolConfig(name="EURUSD", timeframe=timeframe)]
    return [SymbolConfig(name=symbol.strip().upper(), timeframe=timeframe) for symbol in symbols]


def parse_optimization_ranges(definitions: List[str]) -> Dict[str, OptimizationInputRange]:
    ranges: Dict[str, OptimizationInputRange] = {}
    for definition in definitions:
        try:
            name, start, step, stop = definition.split(":")
        except ValueError as exc:
            raise argparse.ArgumentTypeError(
                f"Invalid optimization definition '{definition}'. Use name:start:step:stop."
            ) from exc
        ranges[name] = OptimizationInputRange(
            name=name,
            start=float(start),
            step=float(step),
            stop=float(stop),
        )
    return ranges


def parse_walkforward(value: str) -> Tuple[int, int, Optional[int]]:
    parts = value.split(":")
    if len(parts) not in (2, 3):
        raise argparse.ArgumentTypeError("Walk-forward format must be train:test[:step] in days.")
    train_days = int(parts[0])
    test_days = int(parts[1])
    step_days = int(parts[2]) if len(parts) == 3 else None
    return train_days, test_days, step_days


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ea", required=True, help="Path to the compiled Expert Advisor (ex5).")
    parser.add_argument(
        "--terminal",
        required=True,
        help="Path to MetaTrader terminal binary (MetaTester64.exe).",
    )
    parser.add_argument(
        "--reports-dir",
        default="reports",
        help="Directory where Strategy Tester reports will be written.",
    )
    parser.add_argument("--start", type=parse_date, required=True, help="Backtest start date (YYYY-MM-DD).")
    parser.add_argument("--end", type=parse_date, required=True, help="Backtest end date (YYYY-MM-DD).")
    parser.add_argument(
        "--symbol",
        action="append",
        dest="symbols",
        default=[],
        help="Symbol to include. Repeat for multi-currency optimization.",
    )
    parser.add_argument("--timeframe", default="H1", help="MT5 timeframe (e.g. M15, H1).")
    parser.add_argument(
        "--input",
        action="append",
        default=[],
        help="Override EA input in key=value form. Repeat for multiple overrides.",
    )
    parser.add_argument(
        "--optimize",
        action="append",
        default=[],
        help="Enable parameter optimization in name:start:step:stop format.",
    )
    parser.add_argument(
        "--walkforward",
        type=parse_walkforward,
        help="Enable walk-forward analysis with train:test[:step] day lengths.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Generate configuration without launching MT5.")
    return parser


def main() -> int:
    parser = create_parser()
    args = parser.parse_args()

    optimization_inputs = parse_optimization_ranges(args.optimize)

    config = StrategyTesterConfig(
        expert_path=Path(args.ea).expanduser().resolve(),
        terminal_path=Path(args.terminal).expanduser().resolve(),
        reports_dir=Path(args.reports_dir).expanduser().resolve(),
        start=args.start,
        end=args.end,
        symbols=build_symbols(args.symbols, args.timeframe),
        custom_inputs=parse_inputs(args.input),
        optimization_inputs=optimization_inputs,
    )

    optimizer = (
        GridSearchOptimizer.from_ranges(optimization_inputs.values())
        if optimization_inputs
        else None
    )
    walkforward_runner = (
        SlidingWindowWalkForward(
            config=config,
            train_days=args.walkforward[0],
            test_days=args.walkforward[1],
            step_days=args.walkforward[2],
        )
        if args.walkforward
        else None
    )

    tester = StrategyTesterIntegration(config, optimizer=optimizer, walkforward=walkforward_runner)

    if args.dry_run:
        symbol = config.primary_symbol
        print(config.build_ini_block(symbol, config.custom_inputs))
        return 0

    try:
        results = tester.run()
    except StrategyTesterError as exc:
        parser.error(str(exc))
        return 1

    for result in results:
        status = "OK" if result.success else "FAILED"
        print(f"[{status}] {result.symbol} -> {result.report_file}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
