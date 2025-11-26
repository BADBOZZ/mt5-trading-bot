#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.append(str(PROJECT_ROOT))

from src.backtesting.config import BacktestConfig
from src.backtesting.data_loader import HistoricalDataLoader
from src.backtesting.engine import BacktestEngine
from src.backtesting.optimizer import StrategyOptimizer
from src.backtesting.walkforward import WalkForwardAnalyzer
from src.strategies.moving_average import MovingAverageCrossoverStrategy


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run MT5 backtests and optimizations.")
    parser.add_argument("--data", required=True, help="Path to historical CSV exported from MT5.")
    parser.add_argument("--timeframe", default=None, help="Pandas-style resample rule (e.g. '1H').")
    parser.add_argument("--capital", type=float, default=10000, help="Initial capital in quote currency.")
    parser.add_argument("--lot-size", type=float, default=0.1, help="Per-trade lot size.")
    parser.add_argument("--max-position", type=float, default=5.0, help="Maximum lots held.")
    parser.add_argument("--optimize", action="store_true", help="Run grid search before the backtest.")
    parser.add_argument(
        "--walk-forward",
        action="store_true",
        help="Enable walk-forward analysis (requires --train-size/--test-size).",
    )
    parser.add_argument("--train-size", type=int, default=None, help="Training window length in bars.")
    parser.add_argument("--test-size", type=int, default=None, help="Testing window length in bars.")
    parser.add_argument(
        "--fast-periods",
        type=str,
        default="10,20,30",
        help="Comma-separated fast MA windows for optimization.",
    )
    parser.add_argument(
        "--slow-periods",
        type=str,
        default="50,100,150",
        help="Comma-separated slow MA windows for optimization.",
    )
    parser.add_argument("--volatility-filter", type=str, default="",
                        help="Comma-separated rolling windows for volatility filter; empty disables optimization of this parameter.")
    parser.add_argument("--strategy-params", type=str, default="{}", help="JSON string of manual parameters.")
    return parser.parse_args()


def parse_int_list(csv: str) -> List[int]:
    if not csv:
        return []
    return [int(item) for item in csv.split(",") if item.strip()]


def main() -> None:
    args = parse_args()

    loader = HistoricalDataLoader()
    data = loader.load_csv(args.data, timeframe=args.timeframe)

    config = BacktestConfig(
        initial_capital=args.capital,
        lot_size=args.lot_size,
        max_position=args.max_position,
    )
    engine = BacktestEngine(config)

    params = json.loads(args.strategy_params)
    strategy_cls = MovingAverageCrossoverStrategy

    if args.optimize:
        fast_values = parse_int_list(args.fast_periods)
        slow_values = parse_int_list(args.slow_periods)
        vol_values = parse_int_list(args.volatility_filter)
        param_grid: Dict[str, List[int | None]] = {
            "fast_period": fast_values or [20],
            "slow_period": slow_values or [50],
        }
        if vol_values:
            param_grid["volatility_filter"] = vol_values + [None]

        optimizer = StrategyOptimizer(engine, data)
        leaderboard = optimizer.grid_search(strategy_cls, param_grid, metric="sharpe")
        best = leaderboard[0]
        params.update(best.params)
        print("Top optimization results:")
        for result in leaderboard:
            print(f"{result.params} -> {result.metric}: {result.score:.3f}")

    if args.walk_forward:
        if not args.train_size or not args.test_size:
            raise SystemExit("--walk-forward requires --train-size and --test-size.")
        analyzer = WalkForwardAnalyzer(engine, data)
        wf_result = analyzer.run(
            strategy_cls,
            param_grid={
                "fast_period": parse_int_list(args.fast_periods) or [20],
                "slow_period": parse_int_list(args.slow_periods) or [50],
            },
            train_size=args.train_size,
            test_size=args.test_size,
        )
        print("\nWalk-forward slices:")
        for slice_ in wf_result.slices:
            sharpe = slice_.test_result.performance.summary["sharpe"]
            total_return = slice_.test_result.performance.summary["total_return"]
            print(
                f"Slice {slice_.index}: "
                f"train {slice_.train_range[0]} -> {slice_.train_range[1]}, "
                f"test {slice_.test_range[0]} -> {slice_.test_range[1]}, "
                f"params={slice_.best_params}, "
                f"sharpe={sharpe:.2f}, return={total_return:.2%}"
            )
        print("\nCombined walk-forward performance:")
        for key, value in wf_result.combined_performance.summary.items():
            print(f"{key}: {value:.4f}")
        return

    strategy = strategy_cls(**params)
    backtest = engine.run(data, strategy)

    print(f"\nStrategy: {strategy}")
    print("Performance summary:")
    for key, value in backtest.performance.summary.items():
        print(f"{key}: {value:.4f}")
    print(f"\nTrades: {len(backtest.trades)}")


if __name__ == "__main__":
    main()
