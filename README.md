# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multi-targeting trading strategies
- AI-powered with Neural Networks
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting and optimization
- MT5 integration

## Backtesting & Optimization Toolkit

The `src/backtesting` package delivers:

- Event-driven backtest engine with trade accounting, slippage and commission modeling.
- Strategy optimizer supporting grid and random search for any strategy derived from `BaseStrategy`.
- Walk-forward analyzer that re-optimizes across rolling windows to validate out-of-sample robustness.
- Rich performance reports (Sharpe, Sortino, CAGR, drawdowns, win-rate, exposure, profit factor, etc.).

### Quick start

```bash
pip install -r requirements.txt
python tools/run_backtest.py --data path/to/eurusd.csv --timeframe 1H --optimize
```

Enable walk-forward validation with:

```bash
python tools/run_backtest.py \
  --data path/to/eurusd.csv \
  --walk-forward \
  --train-size 2000 \
  --test-size 500
```

Strategy parameters can be overridden via `--strategy-params '{"fast_period":15,"slow_period":80}'`.

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

## License

Private
