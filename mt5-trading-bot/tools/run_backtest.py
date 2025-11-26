#!/usr/bin/env python3
"""Command line helper for launching MT5 Strategy Tester runs."""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List

from src.backtesting.config import StrategyTesterConfig, SymbolConfig
from src.backtesting.engine import StrategyTesterError, StrategyTesterIntegration


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
    parser.add_argument("--dry-run", action="store_true", help="Generate configuration without launching MT5.")
    return parser


def main() -> int:
    parser = create_parser()
    args = parser.parse_args()

    config = StrategyTesterConfig(
        expert_path=Path(args.ea).expanduser().resolve(),
        terminal_path=Path(args.terminal).expanduser().resolve(),
        reports_dir=Path(args.reports_dir).expanduser().resolve(),
        start=args.start,
        end=args.end,
        symbols=build_symbols(args.symbols, args.timeframe),
        custom_inputs=parse_inputs(args.input),
    )

    tester = StrategyTesterIntegration(config)

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
