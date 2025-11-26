# Data Directory

Place your historical OHLCV CSV files here. The training pipeline expects a file named `historical_ohlcv.csv` with at least the following columns:

- `time` (ISO timestamp or `YYYY-MM-DD HH:MM:SS`)
- `open`
- `high`
- `low`
- `close`
- `volume`

You can export this data directly from MetaTrader 5 (`File -> Save As`) or from your broker's history center. Larger datasets provide better signal fidelity.
