# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multiple trading strategies (Trend Following, Mean Reversion, Breakout)
- AI/ML signal generation
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting framework with MT5 Strategy Tester automation
- Rich performance analytics (Sharpe, drawdown, win rate, profit factor, recovery)

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

## Backtesting & Reporting

- Generate Strategy Tester jobs and optional optimization `.set` files:
  ```bash
  python tools/run_backtest.py \
    --terminal /path/to/terminal64.exe \
    --expert MyExpert.ex5 \
    --symbol EURUSD \
    --start 2024-01-01 --end 2024-06-30 \
    --optimization \
    --set-file ./build/params.set
  ```
- `src/backtesting/PerformanceAnalyzer.mq5` plugs into `OnTester` for MT5-native metrics.
- `src/backtesting/OptimizationParams.mqh` centralizes parameter ranges and tester criteria.
- Strategy Tester HTML reports can be converted into JSON (metrics, charts, comparisons) via `StrategyTesterIntegration.build_report`.

## Configuration

- MT5 Server: FBS-Demo
- Login: 105261321
- Password: (configured in environment)
