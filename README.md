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

Set the password as an environment variable (`MT5_PASSWORD`) or inside a local `.env` file (excluded from git).

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

Key MT5 integration modules live under `src/mt5/`:

- `config.py` – configuration loader with sane defaults for the FBS-Demo server.
- `connection.py` – resilient connection manager with retries, symbol selection, and health checks.
- `account.py` – account summary, exposure, and safety validations.
- `orders.py` – order preparation, execution, and position lifecycle helpers.
- `market_data.py` – real-time tick/rates streaming with callback dispatching.
- `app.py` – optional CLI entry point (`python -m mt5.app`) showcasing how to wire everything together.

## Getting Started

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
```

Create a `.env` file (or export vars) with at least:

```
MT5_PASSWORD=your_demo_password
MT5_SERVER=FBS-Demo        # optional override
MT5_LOGIN=105261321        # optional override
```

Run the sample streaming loop:

```bash
python -m mt5.app
```

Stop with `Ctrl+C`. The script logs connection status, account summary, open positions, and EURUSD ticks.

## Testing

```bash
pytest
```

Unit tests rely on a fake MT5 API stub, so no live terminal is required for validation.

## Development

This project is being built by specialized AI agents working in parallel.

## License

Private
