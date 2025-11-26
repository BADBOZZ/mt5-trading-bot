# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multiple trading strategies (Trend Following, Mean Reversion, Breakout)
- AI/ML signal generation
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting framework with MT5 Strategy Tester integration
- Automated walk-forward and multi-currency optimization pipelines

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

The repository now includes a round-trip workflow between Python helpers
and native MQL5 scripts:

- `src/backtesting/PerformanceAnalyzer.mq5` – custom tester metrics
  (Sharpe, max drawdown, win rate, profit & recovery factors) plus CSV
  export support for trade history, equity curves, and strategy comparison.
- `src/backtesting/OptimizationParams.mqh` – canonical optimizer ranges,
  multi-symbol parsing, walk-forward slice helpers, and report writers.
- `tests/BacktestConfig.mq5` – Strategy Tester harness that performs
  walk-forward validation, runs multi-currency passes, and emits
  human-readable CSVs under `Tester/Files/`.

To generate matching Python artifacts (INI, walk-forward plan, summaries)
run:

```bash
python tools/run_backtest.py \
  --terminal /path/to/terminal64.exe \
  --expert /path/to/Experts/MyBot.ex5 \
  --start 2021-01-01 \
  --end 2022-01-01 \
  --execute
```

Set `MT5_*` environment variables (see `src/backtesting/config.py`) to
control defaults for CI/CD jobs.
