#!/usr/bin/env python3
"""Command-line helper to run the Python Strategy Tester/optimizer."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path
from typing import Dict, Iterable

from src.backtesting.config import BacktestSettings
from src.backtesting.data_loader import MarketDataLoader
from src.backtesting.engine import StrategyTesterEngine
from src.backtesting.optimizer import ParameterGrid, StrategyTesterOptimizer
from src.core.engine import StrategyEngine
from src.core.types import StrategyConfig
from src.risk.config import RiskConfig
from src.risk.risk_engine import RiskEngine
from src.signals.generators import (
    BreakoutGenerator,
    MeanReversionGenerator,
    TrendFollowingGenerator,
)


def build_strategy_engine() -> StrategyEngine:
    """Instantiate the same strategies the live bot uses."""
    engine = StrategyEngine()
    engine.register_strategy(
        "trend",
        TrendFollowingGenerator("TrendFollowing"),
        StrategyConfig(
            name="Trend Following",
            symbols=["EURUSD", "GBPUSD"],
            timeframes=["M15", "H1"],
            enabled=True,
            parameters={"trend_fast_period": 10, "trend_slow_period": 20},
        ),
    )
    engine.register_strategy(
        "mean_reversion",
        MeanReversionGenerator("MeanReversion"),
        StrategyConfig(
            name="Mean Reversion",
            symbols=["EURUSD", "GBPUSD"],
            timeframes=["M15"],
            enabled=True,
            parameters={"mean_lookback": 20, "mean_std_dev": 1.0},
        ),
    )
    engine.register_strategy(
        "breakout",
        BreakoutGenerator("Breakout"),
        StrategyConfig(
            name="Breakout",
            symbols=["EURUSD", "GBPUSD"],
            timeframes=["H1"],
            enabled=True,
            parameters={"breakout_lookback": 20, "breakout_buffer": 0.01},
        ),
    )
    return engine


def apply_parameters(engine: StrategyEngine, overrides: Dict[str, float]) -> None:
    """Map flat `<strategy>.<parameter>` overrides into registered configs."""
    grouped: Dict[str, Dict[str, float]] = {}
    for key, value in overrides.items():
        if "." not in key:
            continue
        strategy_key, param = key.split(".", 1)
        grouped.setdefault(strategy_key, {})[param] = value

    for strategy_key, params in grouped.items():
        if strategy_key not in engine.configs:
            continue
        config = engine.configs[strategy_key]
        config.parameters = dict(config.parameters or {})
        config.parameters.update(params)


def build_engine_pair(parameters: Dict[str, float] | None, settings: BacktestSettings) -> StrategyTesterEngine:
    """Build a StrategyTesterEngine wired with strategy + risk components."""
    strategy_engine = build_strategy_engine()
    if parameters:
        apply_parameters(strategy_engine, parameters)
    risk_engine = RiskEngine(RiskConfig())
    return StrategyTesterEngine(strategy_engine, risk_engine, settings)


def parse_grid_definition(raw: str) -> Dict[str, Iterable]:
    """Load JSON either inline or from a file path."""
    path = Path(raw)
    if path.exists():
        return json.loads(path.read_text())
    return json.loads(raw)


def export_report(result, destination: Path) -> None:
    payload = {
        "performance": result.performance.to_dict(),
        "equity_curve": [
            {"time": ts.isoformat(), "equity": float(value)}
            for ts, value in zip(result.equity_curve.index, result.equity_curve.values)
        ],
        "trades": [],
    }
    for trade in result.trades:
        record = asdict(trade)
        record["entry_time"] = trade.entry_time.isoformat()
        record["exit_time"] = trade.exit_time.isoformat()
        payload["trades"].append(record)

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def print_report(result) -> None:
    perf = result.performance
    print("=== Backtest summary ===")
    print(f"Trades:        {perf.trades}")
    print(f"Total return:  {perf.total_return:.2%}")
    print(f"Annual return: {perf.annual_return:.2%}")
    print(f"Sharpe ratio:  {perf.sharpe:.2f}")
    print(f"Sortino:       {perf.sortino:.2f}")
    print(f"Max drawdown:  {perf.max_drawdown:.2%}")
    print(f"Profit factor: {perf.profit_factor:.2f}")
    print(f"Win rate:      {perf.win_rate:.2%}")
    print("")


def run_optimizer(args, market_frames, settings: BacktestSettings) -> None:
    grid_payload = parse_grid_definition(args.optimize)
    grid = ParameterGrid(grid_payload)
    print(f"Running optimisation over {len(grid)} combinations...")

    optimizer = StrategyTesterOptimizer(
        engine_factory=lambda params: build_engine_pair(params, settings),
        objective=args.objective,
    )
    results = optimizer.run(market_frames, grid, top_n=args.top_n)

    for idx, optimisation in enumerate(results, start=1):
        perf = optimisation.performance
        score = getattr(perf, args.objective, 0.0)
        print(
            f"[{idx}] {args.objective}={score:.4f} "
            f"return={perf.total_return:.2%} dd={perf.max_drawdown:.2%} params={optimisation.parameters}"
        )


def run_single(args, market_frames, settings: BacktestSettings) -> None:
    engine = build_engine_pair(None, settings)
    result = engine.run(market_frames)
    print_report(result)
    if args.output_json:
        export_report(result, Path(args.output_json))


def main():
    parser = argparse.ArgumentParser(description="Python MT5 Strategy Tester helper")
    parser.add_argument("--data-dir", required=True, help="Directory with CSV exports (one per symbol).")
    parser.add_argument("--symbols", nargs="+", required=True, help="Symbols to load (match CSV filenames).")
    parser.add_argument("--timeframe", default="M15", help="Timeframe suffix used in CSV exports.")
    parser.add_argument("--timezone", default="UTC", help="Timezone of CSV timestamps.")
    parser.add_argument("--initial-deposit", type=float, default=10_000.0, help="Starting equity for the run.")
    parser.add_argument("--max-holding", type=int, default=12, help="Maximum bars to keep a trade open.")
    parser.add_argument("--risk-free-rate", type=float, default=0.02, help="Annualised risk-free rate.")
    parser.add_argument("--optimize", help="JSON payload or path describing parameter grid.")
    parser.add_argument("--objective", default="sharpe", help="Performance attribute to maximise.")
    parser.add_argument("--top-n", type=int, default=5, help="Number of optimisation rows to display.")
    parser.add_argument("--output-json", help="Optional path to persist performance/trade data.")

    args = parser.parse_args()

    settings = BacktestSettings(
        initial_deposit=args.initial_deposit,
        max_holding_bars=args.max_holding,
        risk_free_rate=args.risk_free_rate,
    )

    loader = MarketDataLoader()
    datasets = loader.load_csv_directory(args.data_dir, args.symbols, args.timeframe, args.timezone)
    market_frames = loader.synchronize(datasets, settings)

    if args.optimize:
        run_optimizer(args, market_frames, settings)
    else:
        run_single(args, market_frames, settings)


if __name__ == "__main__":
    main()
