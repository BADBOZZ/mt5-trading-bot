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

## Backtesting & Strategy Tester

- Define Strategy Tester inputs in JSON/YAML and run them through `tools/run_backtest.py`:

```bash
python tools/run_backtest.py --config backtest.json            # single run
python tools/run_backtest.py --config backtest.json --optimize # parameter grid search
python tools/run_backtest.py --config backtest.json --walk-forward
python tools/run_backtest.py --config backtest.json --multi-currency
```

- MT5-facing helper files live under `src/backtesting/`:
  - `config.py`: typed models for Strategy Tester sessions
  - `engine.py`: creates `.ini` files, launches MT5, exports reports/charts
  - `optimizer.py`: parameter sweeps using Strategy Tester statistics
  - `metrics.py`: Sharpe, drawdown, win rate, profit/recovery factors
  - `walkforward.py`: rolling walk-forward windows aligned with tester forward mode

- Required MQL files:
  - `src/backtesting/PerformanceAnalyzer.mq5` – on-chart analyzer with Sharpe, MDD, win rate, profit/recovery factor tracking
  - `src/backtesting/OptimizationParams.mqh` – shared parameter declarations and optimization ranges
  - `tests/BacktestConfig.mq5` – Strategy Tester template for regression tests

- Reports (CSV/JSON/PNG) are written to `reports/` by default. Override via the `report.output_dir` field inside the backtest config payload.
