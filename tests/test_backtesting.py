from __future__ import annotations

import numpy as np
import pandas as pd

from src.backtesting.config import BacktestConfig
from src.backtesting.engine import BacktestEngine
from src.backtesting.optimizer import StrategyOptimizer
from src.backtesting.walkforward import WalkForwardAnalyzer
from src.strategies.moving_average import MovingAverageCrossoverStrategy


def synthetic_data(rows: int = 300) -> pd.DataFrame:
    index = pd.date_range("2022-01-01", periods=rows, freq="h")
    trend = np.linspace(1.0, 1.2, rows)
    noise = np.sin(np.linspace(0, 10, rows)) * 0.001
    close = trend + noise
    df = pd.DataFrame(
        {
            "open": close,
            "high": close + 0.0005,
            "low": close - 0.0005,
            "close": close,
            "tick_volume": np.random.randint(100, 1000, size=rows),
        },
        index=index,
    )
    return df


def test_backtest_engine_runs():
    data = synthetic_data()
    config = BacktestConfig(initial_capital=10000, max_position=1.0)
    engine = BacktestEngine(config)
    strategy = MovingAverageCrossoverStrategy(fast_period=5, slow_period=20)

    result = engine.run(data, strategy)

    assert not result.equity_curve.empty
    assert result.equity_curve.index.equals(data.index)
    assert result.performance.summary["total_return"] is not None


def test_optimizer_selects_parameters():
    data = synthetic_data()
    engine = BacktestEngine(BacktestConfig())
    optimizer = StrategyOptimizer(engine, data)

    leaderboard = optimizer.grid_search(
        MovingAverageCrossoverStrategy,
        param_grid={"fast_period": [5, 10], "slow_period": [20, 30]},
        metric="total_return",
    )

    assert leaderboard
    assert leaderboard[0].params["slow_period"] in (20, 30)


def test_walkforward_analysis_combines_slices():
    data = synthetic_data(240)
    engine = BacktestEngine(BacktestConfig())
    analyzer = WalkForwardAnalyzer(engine, data)

    result = analyzer.run(
        MovingAverageCrossoverStrategy,
        param_grid={"fast_period": [5], "slow_period": [20]},
        train_size=120,
        test_size=60,
    )

    assert len(result.slices) == 2
    assert "total_return" in result.combined_performance.summary
