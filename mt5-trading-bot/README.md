# MetaTrader 5 Trading Bot

Multi-targeting, super smart, safe and profitable auto trading bot for MetaTrader 5.

## Features

- Multiple trading strategies (Trend Following, Mean Reversion, Breakout)
- AI/ML signal generation
- Comprehensive risk management
- Real-time monitoring and alerting
- Backtesting framework

## Monitoring Toolkit (MQL5)

The MT5 Expert Advisor side now ships dedicated monitoring utilities under `src/monitoring`:

- `Logger.mq5` writes trade, error, performance, and signal logs with automatic rotation.
- `Alerts.mq5` centralizes popup, email, push, and Telegram notifications for trades, signals, and risk limits.
- `PerformanceTracker.mq5` tracks strategy metrics in real time and persists equity history for comparison.

### Example usage (EA code)

```cpp
#include <monitoring/Logger.mq5>
#include <monitoring/Alerts.mq5>
#include <monitoring/PerformanceTracker.mq5>

int OnInit()
  {
   InitMonitoringLogger();
   ConfigureDefaultAlerts();
   InitPerformanceTracker();
   return(INIT_SUCCEEDED);
  }

void OnTrade()
  {
   // Log execution
   g_MonitorLogger.LogTrade(ticket,symbol,order_type,volume,price,sl,tp,comment);

   // Alert desks
   g_AlertManager.NotifyTradeExecution(ticket,symbol,order_type,volume,price,sl,tp,comment);
  }

void OnTimer()
  {
   g_PerformanceTracker.RecordEquity(strategy,TimeCurrent(),AccountInfoDouble(ACCOUNT_EQUITY));
  }
```

### Telegram setup

1. Create a bot with [@BotFather](https://t.me/BotFather) and grab the token.
2. Retrieve the chat ID (e.g., via [`getUpdates`](https://core.telegram.org/bots/api#getupdates)).
3. Add `https://api.telegram.org` to the MT5 **Tools → Options → Expert Advisors → Allow WebRequest** list.
4. Call `g_AlertManager.ConfigureTelegram(botToken, chatId, true);`.

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
