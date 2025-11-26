# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multiple trading strategies (Trend Following, Mean Reversion, Breakout)
- AI/ML signal generation
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting framework

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure MT5 connection in `config.py`

3. Run the bot:
```bash
python main.py
```

## Configuration

- MT5 Server: FBS-Demo
- Login: 105261321
- Password: (configured in environment)

## Strategy Tester Integration

- `src/backtesting/PerformanceAnalyzer.mq5` plugs into the EA's `OnTester` cycle to calculate Sharpe ratio, win rate, profit factor, recovery factor, and maximum drawdown while exporting CSV trade history, equity curves, and optimization snapshots.
- `src/backtesting/OptimizationParams.mqh` centralizes the `sinput` ranges used for parameter sweeps, defines multi-currency symbol sets, and emits walk-forward schedules/parameter manifests that the Strategy Tester can load.
- `tests/BacktestConfig.mq5` is a helper script that applies consistent Strategy Tester settings (tick model, optimization mode, forward-testing windows, and deposit configuration) before generating manifest files under `tester/files`.

### Running a Walk-Forward Optimization

1. Copy `src/backtesting/PerformanceAnalyzer.mq5` into your EA folder (e.g. `MQL5/Experts/MetaTraderBot/`) or `#include` it from your EA.
2. Copy/import `src/backtesting/OptimizationParams.mqh` to keep the EA inputs, optimization ranges, and symbol universe synchronized across the bot and Strategy Tester.
3. Place `tests/BacktestConfig.mq5` inside `MQL5/Scripts/` and run it once from the terminal to push tester settings, export parameter manifests, and pre-generate walk-forward CSVs.
4. In Strategy Tester, select `Optimization -> Custom max` so that the return value from `PerformanceAnalyzer` drives pass ranking (recovery, Sharpe, profit factor, or win rate).
5. Launch an optimization run; the analyzer writes trade history (`*_trades.csv`), equity curve (`*_equity.csv`), strategy comparison sheets (`*_strategies.csv`), optimization parameters, symbol universes, and walk-forward plans into the common tester files folder for downstream reporting.

These steps enable multi-currency, parameter-optimized, walk-forward aware backtests using only built-in MT5 Strategy Tester capabilities.
