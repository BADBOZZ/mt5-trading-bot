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

## MT5 Strategy Tester Integration

1. Copy the following files into your `MQL5/Experts/` workspace (or link the repo inside `MQL5/Projects/`):
   - `src/backtesting/PerformanceAnalyzer.mq5`
   - `src/backtesting/OptimizationParams.mqh`
   - `tests/BacktestConfig.mq5`
2. Attach `BacktestConfig.mq5` to the MT5 Strategy Tester. It automatically:
   - Loads parameter ranges defined in `OptimizationParams.mqh`
   - Enables multi-currency optimization by parsing the `InpSymbols` input (default `EURUSD,GBPUSD,USDJPY,XAUUSD`)
   - Configures walk-forward windows with controllable train/test months
   - Routes all passes through `PerformanceAnalyzer` so you get Sharpe, max drawdown, win rate, profit factor, and recovery factor on every optimization run
3. Select **Optimization → Custom** and choose the metric to maximize via the `InpOptimizationGoal` input (Sharpe, recovery factor, profit factor, or expectancy).
4. Enable MT5’s **Open prices only** or **1 minute OHLC** modes for faster walk-forward sweeps. Each window is exported to `tester_walkforward_windows.csv` and the measured results are written to `tester_walkforward_results.csv`.

## Backtest Reports & Outputs

- `tester_trade_history.csv` – closed-deal export containing tickets, symbols, volumes, and P/L for audit trails.
- `tester_equity_curve.csv` – equity time series for charting custom performance curves.
- `tester_summary.csv` – compact table with Sharpe ratio, max drawdown %, win rate, profit factor, and recovery factor.
- `tester_strategy_comparison.csv` – appended after every Strategy Tester pass (including walk-forward slices) so you can line up different parameter sets or symbols.
- `tester_optimization_report.csv` – captures the optimization criterion score plus the full metric bundle for each pass.

These CSVs live inside the MT5 `MQL5/Files` directory and can be fed directly into the existing Python backtesting dashboard or plotted in notebooks.

## Configuration

- MT5 Server: FBS-Demo
- Login: 105261321
- Password: (configured in environment)
