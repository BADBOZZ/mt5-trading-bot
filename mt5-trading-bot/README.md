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

## Backtesting & Optimisation

Run the pure-Python Strategy Tester against CSV exports (one file per symbol):

```bash
python tools/run_backtest.py \
  --data-dir data/history \
  --symbols EURUSD GBPUSD \
  --timeframe M15
```

To grid-search strategy inputs (mirrors MT5 Strategy Tester optimisation) provide a JSON payload where keys follow `<strategy>.<parameter>` naming:

```bash
python tools/run_backtest.py \
  --data-dir data/history \
  --symbols EURUSD GBPUSD \
  --timeframe M15 \
  --optimize grids/trend.json \
  --objective sharpe \
  --top-n 3
```

The CLI will print aggregated performance metrics and, when `--output-json` is supplied, persist the equity curve plus trade log for downstream dashboards.
