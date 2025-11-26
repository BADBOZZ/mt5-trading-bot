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

## MT5 Strategy Tester Workflow

1. **Generate tester jobs & parameter ranges**
   ```bash
   python tools/run_backtest.py \
     --expert PerformanceAnalyzer \
     --symbols EURUSD GBPUSD USDJPY \
     --timeframe H1 \
     --start 2023-01-01 --end 2024-01-01 \
     --optimize \
     --walkforward 120/30/30 \
     --basket tools/multicurrency.json \
     --export-plan reports/optimization_plan.json
   ```
   - Creates `.ini`/`.set` files per symbol basket for the MT5 Strategy Tester
   - Walk-forward plans are embedded in the generated configs
   - Optimization ranges mirror `src/backtesting/OptimizationParams.mqh` and can be inspected in the exported JSON blueprint

2. **Run optimization / walk-forward passes in MT5**
   - Attach `PerformanceAnalyzer.mq5` to the Strategy Tester to compute Sharpe, win rate, profit factor, recovery factor, and drawdown during `OnTester`
   - Use the generated `.set` file to load the curated parameter ranges (risk, stop/target, trailing, volatility multiplier, and signal mode)

3. **Leverage the regression config for trade exports & strategy comparison**
   - Load `tests/BacktestConfig.mq5` into the Strategy Tester when you need deterministic regression runs
   - `TesterSymbols` input accepts comma-separated instruments for on-screen comparison
   - Trade history CSVs land under `reports/<prefix>_trades.csv` and include timestamp, symbol, direction, volume, profit, and rolling balance values suitable for downstream dashboards

4. **Summarize or visualize performance**
   ```bash
   # Summarize an MT5 CSV report on the CLI
   python tools/run_backtest.py --trade-history reports/regression_trades.csv

   # Quick equity / profit chart (requires pandas/matplotlib)
   python - <<'PY'
   import pandas as pd
   df = pd.read_csv("reports/regression_trades.csv")
   df["balance"].plot(title="Equity Curve")
   df["profit"].cumsum().plot(title="Cumulative Profit")
   PY
   ```
   - `PerformanceAnalyzer.mq5` automatically produces `reports/<EA>_<symbol>_performance.csv` with Sharpe, drawdown, win rate, profit factor, and recovery factor
   - Use the exported CSV files in any BI/plotting tool to overlay multiple strategies or symbol baskets
