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

## Chart Overlay (MQL5)

The `src/ui/ChartOverlay.mq5` expert advisor renders an on-chart dashboard directly inside MetaTrader 5. Copy the file (and the companion headers in `src/ui`) into your `MQL5/Experts` directory, compile inside MetaEditor, then attach the EA to any chart.

### Data Feeds

- **Strategy status:** Publish enabled/disabled flags via global variables named `MT5BOT_STRATEGY|<strategy>|<symbol>` and set the value to `1` (enabled) or `0` (disabled).
- **Signals:** Publish signals via global variables named `MT5BOT_SIGNAL|<strategy>|<symbol>`. Use a positive value for buy signals, negative value for sell signals, and the magnitude (0–100) to indicate confidence.
- The overlay automatically inspects open positions, active orders, and daily deal history to populate position tables, risk metrics, and performance dashboards.

### Visual Elements

- Info panel: account balance, equity, daily P&L, drawdown, margin, and per-strategy status.
- Position table: live summary (symbol, side, volume, P&L, SL, TP).
- Signal panel: active signals with direction, confidence, and age.
- Performance dashboard: per-strategy win rate, average P/L, total trades today, best/worst trades.
- Chart markers: entry arrows, SL/TP levels, exit markers, and projected signal arrows plotted in real time.

### Configuration Panel

A dedicated control panel (top-left corner) lets you:

- Show/Hide the overlay.
- Cycle through chart corners.
- Switch between dark/light themes and change font size.
- Speed up or slow down the refresh interval (1–60 seconds).
- Toggle visibility for the positions, signals, and performance panels.

All controls respond immediately and the EA still updates on every tick/timer event even while the overlay is hidden.
