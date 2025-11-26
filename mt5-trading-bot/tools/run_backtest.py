#!/usr/bin/env python3
"""Utility CLI to prepare MT5 Strategy Tester jobs."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from src.backtesting.engine import StrategyTesterIntegration, StrategyTesterJob
from src.backtesting.optimizer import ParameterSpace, default_space


def _parse_date(value: str) -> datetime:
    return datetime.strptime(value, "%Y-%m-%d")


def _parse_walk_forward(value: str) -> tuple[int, int, int | None]:
    """Return (in, out, step) in days."""

    parts = value.split("/")
    if len(parts) not in (2, 3):
        raise argparse.ArgumentTypeError("use INSAMPLE/OUTSAMPLE[/STEP]")
    insample, outsample = (int(parts[0]), int(parts[1]))
    step = int(parts[2]) if len(parts) == 3 else None
    return insample, outsample, step


def _load_trade_history(path: Path) -> List[dict]:
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        return [
            {
                "profit": float(row.get("profit", 0)),
                "balance": float(row.get("balance", row.get("equity", 0))),
                "equity": float(row.get("equity", row.get("balance", 0))),
            }
            for row in reader
        ]


def _build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expert", required=True, help="Name of the EA/Expert file.")
    parser.add_argument("--symbols", nargs="+", default=["EURUSD"], help="Symbols to test.")
    parser.add_argument("--timeframe", default="H1", help="MT5 timeframe (e.g. H1, M15).")
    parser.add_argument("--start", required=True, help="Backtest start date YYYY-MM-DD.")
    parser.add_argument("--end", required=True, help="Backtest end date YYYY-MM-DD.")
    parser.add_argument("--deposit", type=float, default=10000.0, help="Initial deposit.")
    parser.add_argument("--currency", default="USD", help="Deposit currency.")
    parser.add_argument("--spread", type=int, default=10, help="Simulated spread points.")
    parser.add_argument("--workspace", default="tester_jobs", help="Output folder for .ini/.set.")
    parser.add_argument(
        "--optimization-mode",
        default="complete",
        help="MT5 optimization algorithm (complete, fastgenetic, etc.).",
    )
    parser.add_argument(
        "--optimization-criterion",
        default="Custom max",
        help="Tester criterion (Balance max, Sharpe ratio, Custom max...).",
    )
    parser.add_argument(
        "--walkforward",
        type=_parse_walk_forward,
        help="Walk-forward definition INSAMPLE/OUTSAMPLE[/STEP] (days).",
    )
    parser.add_argument(
        "--basket",
        type=Path,
        help="Optional JSON mapping {\"name\": [\"EURUSD\",\"GBPUSD\"]} for multi-currency jobs.",
    )
    parser.add_argument(
        "--trade-history",
        type=Path,
        help="CSV export from Strategy Tester report for metric summary.",
    )
    parser.add_argument(
        "--optimize",
        action="store_true",
        help="Include default parameter ranges (.set file generation).",
    )
    return parser


def main() -> None:
    parser = _build_argument_parser()
    args = parser.parse_args()

    start = _parse_date(args.start)
    end = _parse_date(args.end)
    param_space: ParameterSpace | None = default_space() if args.optimize else None

    integration = StrategyTesterIntegration(args.workspace)
    base_job = StrategyTesterJob(
        expert_name=args.expert,
        symbols=tuple(args.symbols),
        timeframe=args.timeframe,
        start_date=start,
        end_date=end,
        deposit=args.deposit,
        currency=args.currency,
        spread=args.spread,
        optimization_mode=args.optimization_mode,
        optimization_criterion=args.optimization_criterion,
        parameter_space=param_space,
    )

    if args.walkforward:
        insample, outsample, step = args.walkforward
        base_job = integration.create_walk_forward_job(base_job, insample, outsample, step)

    jobs = [base_job]
    if args.basket:
        data = json.loads(args.basket.read_text())
        jobs = integration.build_multicurrency_jobs(base_job, data)

    paths = integration.export_batch(jobs)
    print(f"Generated {len(paths)} tester job(s) in {args.workspace}")
    for path in paths:
        print(f" - {path.name}")

    if args.trade_history:
        trades = _load_trade_history(args.trade_history)
        summary = integration.summarize(trades)
        print("Summary:")
        print(f"  Trades: {summary.trades}")
        print(f"  Sharpe: {summary.sharpe_ratio:.2f}")
        print(f"  Win rate: {summary.win_rate:.2%}")
        print(f"  Profit factor: {summary.profit_factor:.2f}")
        print(f"  Recovery factor: {summary.recovery_factor:.2f}")
        print(f"  Max drawdown: {summary.max_drawdown:.2%}")
        print(f"  Net profit: {summary.net_profit:.2f}")


if __name__ == "__main__":
    main()
