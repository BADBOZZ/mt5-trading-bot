# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multi-targeting trading strategies
- AI-powered with Neural Networks
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting and optimization
- MT5 integration

## MT5 Configuration

- Server: FBS-Demo
- Login: 105261321

## Project Structure

```
src/
  risk/          # Risk management modules
  strategies/    # Trading strategies
  ai/           # Neural network and AI
  mt5/          # MT5 integration
  backtesting/  # Backtesting framework
  monitoring/   # Monitoring and alerts
  security/     # Security and safety checks
```

## Risk Management System

The `src/risk` package now provides end-to-end risk controls that cover:

- **Config**: strongly validated dataclasses for position sizing, stop logic, drawdown/daily loss rules, and portfolio exposure caps.
- **State tracking**: live equity/drawdown statistics plus symbol, asset-class, and correlation bucket exposures.
- **Position sizing**: fractional risk sizing with broker-aware lot rounding and volatility-based sizing helpers.
- **Stop logic**: ATR and fixed-pip stop builders, take-profit projection, and trailing-stop triggers.
- **Limit enforcement**: max drawdown, daily loss (percent and absolute), cooling-off windows, and per-symbol/portfolio exposure guards.
- **Risk engine**: orchestration layer (`RiskEngine`) that ties everything together for trade planning, exposure commits, and realized PnL updates.

### Quick start

```python
from risk import (
    AccountState,
    RiskConfig,
    RiskEngine,
    TradeIntent,
)

config = RiskConfig.from_dict({...})
engine = RiskEngine(config)
intent = TradeIntent(
    symbol="EURUSD",
    direction="long",
    entry_price=1.0835,
    volatility=0.0009,   # ATR in price units
    pip_value=10.0,
    correlation_bucket="EUR",
)
account = AccountState(balance=25_000, equity=25_000)
plan = engine.plan_trade(account=account, intent=intent)

engine.commit_plan(intent=intent, account=account, plan=plan)
```

Any violation (max drawdown, daily loss, exposure, invalid stops, etc.) raises a descriptive exception so higher-level strategy code can halt trading before risk limits are breached.

## Development

This project is being built by specialized AI agents working in parallel.

## License

Private
