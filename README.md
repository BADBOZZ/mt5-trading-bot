# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multi-targeting trading strategies
- AI-powered with Neural Networks
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting and optimization
- MT5 integration

## Repository Layout

```
src/
  ai/                # Python package with data, models, training, inference
    data/            # Sequence datasets for time-series inputs
    features/        # Technical indicator and regime detection features
    models/          # Dual-stream temporal networks + pattern nets
    pipelines/       # Training, evaluation, and signal generation flows
    inference/       # Runtime + ONNX/quantized export helpers
    utils/           # Logging helpers
    evaluation/      # Custom financial metrics
  mt5/               # Expert Advisor + bridge to the AI signal files
    include/         # Reusable MQL5 include files
```

## Data Requirements

The training stack expects a CSV with (at minimum) the columns:

- `timestamp` (UTC)
- `open`, `high`, `low`, `close`
- `tick_volume`
- `spread`

Additional columns are kept if present. The training pipeline automatically derives advanced indicators (multi-window EMAs, ATR, MACD, RSI, MFI, spread z-scores, volatility, and Hurst-based regime labels) plus the `future_return` prediction target.

## Python Training Workflow

1. Install dependencies
   ```bash
   python -m venv .venv && source .venv/bin/activate
   pip install -e .  # Uses pyproject.toml / src layout
   ```
2. Train (optionally overriding hyper-parameters with a YAML config)
   ```bash
   PYTHONPATH=src python -m ai.train --data-csv data/market.csv --generate-signals
   ```
   - Uses a dual-stream temporal net (stacked LSTMs + temporal CNN + multi-head attention + Monte Carlo dropout) for price direction probability, trend magnitude, and volatility estimates.
   - Saves checkpoints in `artifacts/model_checkpoint.pt` by default.
3. Export signals for MT5
   - `ai.inference.runtime.InferenceEngine` converts the latest predictions into `ai_signals.json` and `ai_signals.csv`.
   - `ai.inference.export` can create ONNX or quantized Torch weights for lightweight deployment.

## MT5 Integration

- The Expert Advisor `src/mt5/NeuralSignalGenerator.mq5` reads the CSV exported by the Python runtime (copy it into `<terminal>/MQL5/Files/ai_signals.csv`).
- `AiSignalBridge.mqh` parses the most recent row (timestamp, buy/sell scores, trend, volatility, action) and exposes it to the EA.
- Inputs such as lot size, spread guard, cooldown, and trend bias gate the orders opened through `CTrade`.

## Development Notes

- Signals are only acted upon when the exported timestamp is not older than one hour and the spread is within tolerance.
- Training uses AdamW, mixed precision, gradient clipping, and direction-aware losses that couple regression, volatility estimation, and classification for more stable behaviour under regime shifts.
- Extend `Config` (see `src/ai/config.py`) or provide a YAML override to tune lookbacks, horizons, thresholds, or hardware targets.

## License

Private
