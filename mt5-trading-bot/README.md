# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multiple trading strategies (Trend Following, Mean Reversion, Breakout)
- AI/ML signal generation
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting framework

## MQL5 Risk Toolkit

The EA risk controls live inside the `src` tree and can be included directly in MetaEditor:

- `src/config/risk-config.mqh` exposes every guardrail as an `input` so lot sizing, drawdown thresholds, and cooldowns are tuneable without recompiling.
- `src/risk/RiskManager.mq5` calculates compliant lot sizes per trade while respecting account type and exposure caps.
- `src/risk/RiskLimits.mq5` tracks daily loss, drawdown, per-symbol limits, and cooldown windows using platform global variables.
- `src/risk/SafetyChecks.mq5` orchestrates the pre-trade checklist (balance, margin, cooldown, emergency stop) and should be called before any order request.

Include the config header plus whichever modules you need inside your EA, e.g.:

```
#include "src\\config\\risk-config.mqh"
#include "src\\risk\\RiskManager.mq5"
#include "src\\risk\\RiskLimits.mq5"
#include "src\\risk\\SafetyChecks.mq5"
```

All inputs appear in the EA properties window, giving traders the ability to adjust risk without touching source code.

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
