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

## Monitoring Toolkit

The repository now includes native MT5 libraries for runtime monitoring:

- `src/monitoring/Logger.mq5` – leveled logging with rotation and console mirroring.
- `src/monitoring/Alerts.mq5` – channel-aware alert router (terminal, push, email) with throttling.
- `src/monitoring/PerformanceTracker.mq5` – aggregates balance/equity, drawdown, win-rate, and emits alerts through the logger/alert stack.

Use `src/monitoring/manager.py` to build the bootstrap payload for these libraries. The `MonitoringManager.bootstrap_payload()` helper provides the dictionary you can pass to your MT5 bridge script so the bot and MQL runtime stay in sync regarding alert prefixes, drawdown thresholds, and log file locations.
