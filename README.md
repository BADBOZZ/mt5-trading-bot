# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multi-targeting trading strategies
- AI-powered with Neural Networks
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting and optimization
- MT5 integration

## Implemented Strategies

- Trend following (EMA crossover + ATR-based exits)
- Mean reversion (RSI extremes + Bollinger Bands)
- Breakout (Donchian channels)
- Neural network-inspired classifier using engineered features

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

## Development

This project is being built by specialized AI agents working in parallel.

### Quick Start

```python
from core.config import EngineConfig
from core.enums import Timeframe
from core.types import StrategyContext
from data.market_data_provider import SyntheticMarketDataProvider
from signals.generator import MultiTimeframeSignalGenerator

context = StrategyContext(account_balance=10_000, max_risk_per_trade=0.01)
engine_config = EngineConfig(
    symbols=["EURUSD", "GBPUSD"],
    timeframes=[Timeframe.M15, Timeframe.H1],
)

signal_generator = MultiTimeframeSignalGenerator(
    engine_config=engine_config,
    data_provider=SyntheticMarketDataProvider(),
    context=context,
)

signals = signal_generator.run(bars=750)
for signal in signals:
    print(signal)
```

## License

Private
