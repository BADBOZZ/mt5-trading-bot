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

## Monitoring Modules (MQL5)

The EA-side monitoring stack now ships with dedicated MQL5 components under `src/monitoring`:

| File | Responsibility | Highlights |
| --- | --- | --- |
| `Logger.mq5` | Structured trade, error, performance, and signal logging | CSV output in `MQL5/Files/monitoring`, journal mirroring, millisecond timestamps |
| `Alerts.mq5` | Native MT5 + Telegram alert routing | Popup, email, push, Telegram WebRequest helper with throttling and per-alert helpers |
| `PerformanceTracker.mq5` | Real-time & historical performance tracking | Per-strategy stats, sharpe/profit-factor calculations, CSV history + snapshots, daily Telegram reports |

### Integrating in an Expert Advisor

1. Copy the `.mq5` files into your `MQL5\\Include` or EA folder and add:
   ```mq5
   #include <src/monitoring/Logger.mq5>
   #include <src/monitoring/Alerts.mq5>
   #include <src/monitoring/PerformanceTracker.mq5>
   ```
2. Instantiate the services in `OnInit()`:
   ```mq5
   LoggerSettings loggerCfg;
   loggerCfg.FilePrefix = "live";
   MonitoringLogger logger;
   logger.Configure(loggerCfg);

   AlertServiceConfig alertCfg;
   alertCfg.EnableEmail = true;
   alertCfg.EnableTelegram = true;
   alertCfg.TelegramBotToken = "<bot-token>";
   alertCfg.TelegramChatId = "<chat-id>";
   AlertService alerts;
   alerts.Configure(alertCfg);

   PerformanceTracker perf;
   perf.Init(AccountInfoDouble(ACCOUNT_BALANCE));
   perf.AttachLogger(&logger);
   perf.AttachAlerts(&alerts);
   ```
3. Call `alerts.NotifyTradeExecution(...)` and `perf.RecordTrade(...)` whenever trades are executed, and periodically invoke `perf.UpdateEquity()` plus `perf.SendDailyReport()` (e.g., on timer).
4. For Telegram alerts, add `https://api.telegram.org` to **Tools → Options → Expert Advisors → Allow WebRequest for listed URL** inside MetaTrader.

These modules are self-contained and require only standard MT5 APIs, making them safe to include in any EA or script.
