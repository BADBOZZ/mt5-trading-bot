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

## Monitoring EA Components

The MetaTrader terminal ships with three native `.mq5` helpers under `src/monitoring`:

- `Logger.mq5` – file-based trade, error, performance, and signal logging.
- `Alerts.mq5` – consolidates MT5 alerts (popup, email, push) plus optional Telegram routing.
- `PerformanceTracker.mq5` – tracks real-time equity/balance metrics and stores historical snapshots.

Compile these files inside MetaEditor and attach them to the monitoring Expert Advisor or include them from your strategy `.mq5` source. To enable Telegram notifications, add `https://api.telegram.org` to *Tools → Options → Expert Advisors → Allow WebRequest for listed URL*, then call `ConfigureTelegram(token, chatId)` at start-up.
