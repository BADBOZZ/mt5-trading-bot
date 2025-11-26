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

## AI Strategy Workflow

- `src/ai/PatternRecognition.mqh` – regime detection, breakout sensing, and volatility compression logic exposed to the EA.
- `src/ai/SignalScoring.mqh` – confidence aggregation and trade filtering that blends historical stats with live context.
- `src/ai/MLStrategy.mq5` – deployable Expert Advisor that fuses the statistical layer with an optional neural predictor (weights loaded from `models/HybridSignalNet.nn`) and streams training rows to `data/ml_training_buffer.csv`.
- `src/ai/models.py`, `train.py`, `inference.py` – Python utilities for training the HybridSignalNet, exporting weights for MT5, and running offline inference/validation.

### Training Pipeline

1. Attach `MLStrategy.mq5` to a chart with `InpCollectTraining=true` to accumulate rows in `MQL5/Files/data/ml_training_buffer.csv`.
2. Copy the CSV back to this repo (e.g., `data/ml_training_buffer.csv`) and install dependencies: `pip install -r requirements.txt`.
3. Train and export weights:
   ```
   python -m src.ai.train data/ml_training_buffer.csv --output artifacts/hybrid_model.json --weights artifacts/hybrid_model.weights
   ```
4. Copy the exported `.weights` file into the MT5 `MQL5/Files/models/HybridSignalNet.nn` path referenced by the EA.

### Real-time Inference

- Use `src/ai/inference.py` to score symbols from Python:
  ```python
  from pathlib import Path
  from src.ai.inference import batch_score

  print(batch_score([\"EURUSD\", \"GBPUSD\"], timeframe=mt5.TIMEFRAME_H1, model_path=Path(\"artifacts/hybrid_model.json\")))
  ```
- Inside MT5, `MLStrategy.mq5` combines neural confidence with pattern scores, applies risk filters, and opens/closes positions accordingly.

## Development

This project is being built by specialized AI agents working in parallel.

## License

Private
