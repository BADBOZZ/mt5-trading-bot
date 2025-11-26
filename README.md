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

## AI/NN Pipeline Overview

- `src/ai/features.py` builds technical factor stacks (EMA, RSI, ATR, BB width, returns)
- `src/ai/datasets.py` prepares sliding windows suitable for sequence models
- `src/ai/models.py` hosts the HybridSignalNet (dilated TCN + LSTM + attention pooling)
- `src/ai/train.py` trains classification/regression heads jointly with consistency losses
- `src/ai/inference.py` exports the latest signal vector into CSV/JSON format for MT5
- `src/mt5/experts/AIHybridTrader.mq5` consumes CSV signals via `AISignalBridge.mqh`

## Usage

1. **Install dependencies**
   ```bash
   python -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   ```
2. **Drop market data** into `data/historical_ohlcv.csv` (time, open, high, low, close, volume).
3. **(Optional) Customize config** by copying `config.example.yaml` to `config.yaml` and editing hyper-parameters.
4. **Train the model**
   ```bash
   python -m src.ai.train --config config.yaml   # optional config
   ```
   A checkpoint is written to `artifacts/models/hybrid_signal_net.pt` and metrics to JSON.
5. **Generate signals + ONNX export**
   ```bash
   python -m src.ai.inference
   python -m src.ai.export
   ```
   This writes `artifacts/signals/ai_signals.csv`/`.json` and `artifacts/models/hybrid_signal_net.onnx`.
6. **Move the signal file** into the MT5 `MQL5/Files` directory (or symlink) so the EA can read it.
7. **Compile the Expert Advisor** (`src/mt5/experts/AIHybridTrader.mq5`) inside MetaEditor and attach it to the desired chart.

## MQL5 Integration Notes

- The EA only opens trades when `confidence >= 0.55` and spread is acceptable.
- Position sizing is risk-based (InpRiskPerTrade) using volatility-derived stops.
- `AIHybridTrader` reacts to CSV updates; each new timestamp triggers trade management.
- `AISignalBridge.mqh` parses ISO timestamps and probabilities, ensuring only fresh signals are executed.
- Use `python -m src.ai.inference` on a schedule (cron/task) to keep the CSV in sync with live data.

## Development

This project is being built by specialized AI agents working in parallel.

## License

Private
