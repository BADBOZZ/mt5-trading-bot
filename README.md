# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multi-targeting trading strategies
- AI-powered with Neural Networks
- Comprehensive risk management
- Real-time monitoring, dashboards, and multi-channel alerting
- Backtesting and optimization
- MT5 integration

## MT5 Configuration

- Server: FBS-Demo
- Login: 105261321

## Monitoring & Alerting

The `src/monitoring` package provides end-to-end observability for the trading bot:

- Structured logging with rotating files (`logs/monitoring.log`) and JSON output for ingestion.
- Trade journal writer that records every fill to CSV/JSONL for post-trade analysis.
- Real-time metrics pipeline with in-memory retention, percentile summaries, and performance timers.
- Rule engine enforcing drawdown, latency, slippage, heartbeat, and rejection thresholds.
- Alert fan-out covering Email (SMTP), SMS (Twilio), and Telegram Bot integrations.
- Lightweight dashboard (`http://0.0.0.0:8060`) exposing `/metrics`, `/alerts`, and `/health`.

### Configuration

All settings are sourced from environment variables or defaults via `MonitoringConfig.from_env()`:

| Variable | Description |
| --- | --- |
| `APP_ENV` | Environment label for health checks |
| `MONITORING_LOG_DIR` | Directory for structured logs/trade journals |
| `MONITORING_LOG_LEVEL` | Logging verbosity (default `INFO`) |
| `MONITORING_LOG_JSON` | Emit JSON logs (`1`/`0`) |
| `MONITORING_DASHBOARD_HOST` / `PORT` | Dashboard bind address |
| `MAX_SLIPPAGE_PIPS`, `MAX_DRAWDOWN_PCT`, `MAX_CONSECUTIVE_LOSSES`, `MAX_LATENCY_MS`, `HEARTBEAT_SECONDS`, `MIN_BALANCE`, `MAX_ORDER_REJECTIONS` | Risk & health thresholds |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_SENDER`, `ALERT_EMAIL_RECIPIENTS` | Email alerts |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER`, `ALERT_SMS_RECIPIENTS` | SMS alerts |
| `TELEGRAM_BOT_TOKEN`, `ALERT_TELEGRAM_CHAT_IDS` | Telegram bot alerts |

### Running the monitoring stack

```bash
python -m monitoring.example
```

The example producer emits mock trades, metrics, and heartbeats so you can validate logs, dashboards, and notification channels end-to-end before wiring the real trading bot.

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
