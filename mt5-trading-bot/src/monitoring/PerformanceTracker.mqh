#ifndef __PERFORMANCE_TRACKER_MQH__
#define __PERFORMANCE_TRACKER_MQH__

#include "Logger.mqh"
#include "Alerts.mqh"

struct PerformanceSnapshot
  {
   datetime timestamp;
   double   balance;
   double   equity;
   double   dailyPnL;
   double   maxDrawdown;
   int      trades;
   double   winRate;
   double   profitFactor;
  };

class PerformanceTracker
  {
private:
   Logger       m_logger;
   AlertManager m_alerts;

   double       m_peakEquity;
   double       m_troughEquity;
   double       m_balance;
   double       m_equity;
   double       m_dailyPnL;
   double       m_maxDrawdown;
   double       m_totalProfit;
   double       m_totalLoss;
   int          m_tradeCount;
   int          m_winCount;
   int          m_lossCount;
   double       m_warnDrawdown;
   double       m_critDrawdown;
   datetime     m_dayAnchor;
   bool         m_ready;

public:
                  PerformanceTracker(void);
   bool           Init(const string logFile            = "logs/performance.log",
                      const double warnDrawdownPercent = 2.0,
                      const double critDrawdownPercent = 4.0);
   void           ConfigureAlerts(const int channels = ALERT_CHANNEL_TERMINAL,
                                  const int throttleSeconds = 30,
                                  const string prefix = "MT5Bot");
   void           ResetDaily(void);
   void           OnEquityTick(const double balance, const double equity);
   void           OnTradeClosed(const double profit);
   PerformanceSnapshot Snapshot(void) const;

   double         DailyPnL(void) const { return m_dailyPnL; }
   double         MaxDrawdown(void) const { return m_maxDrawdown; }
   double         WinRate(void) const;
   double         ProfitFactor(void) const;
   int            Trades(void) const { return m_tradeCount; }

private:
   void           EnsureDayAnchor(void);
   void           UpdateDrawdown(void);
   void           MaybeAlertDrawdown(void);
   void           LogTrade(const double profit);
  };

PerformanceTracker::PerformanceTracker(void)
  {
   m_peakEquity     = 0.0;
   m_troughEquity   = 0.0;
   m_balance        = 0.0;
   m_equity         = 0.0;
   m_dailyPnL       = 0.0;
   m_maxDrawdown    = 0.0;
   m_totalProfit    = 0.0;
   m_totalLoss      = 0.0;
   m_tradeCount     = 0;
   m_winCount       = 0;
   m_lossCount      = 0;
   m_warnDrawdown   = 2.0;
   m_critDrawdown   = 4.0;
   m_dayAnchor      = 0;
   m_ready          = false;
  }

bool PerformanceTracker::Init(const string logFile,
                              const double warnDrawdownPercent,
                              const double critDrawdownPercent)
  {
   m_logger.Configure(logFile, LOG_LEVEL_INFO, true, true, 1024 * 1024);
   m_warnDrawdown = warnDrawdownPercent;
   m_critDrawdown = critDrawdownPercent;
   m_alerts.Configure(ALERT_CHANNEL_TERMINAL, 30, "MT5Bot", 64);
   ResetDaily();
   m_ready = true;
   m_logger.Info("Performance tracker initialized");
   return true;
  }

void PerformanceTracker::ConfigureAlerts(const int channels,
                                         const int throttleSeconds,
                                         const string prefix)
  {
   m_alerts.Configure(channels, throttleSeconds, prefix, 64);
  }

void PerformanceTracker::ResetDaily(void)
  {
   m_dailyPnL    = 0.0;
   m_tradeCount  = 0;
   m_winCount    = 0;
   m_lossCount   = 0;
   m_totalProfit = 0.0;
   m_totalLoss   = 0.0;
   m_dayAnchor   = Date();
   m_logger.Info("Performance tracker daily metrics reset");
  }

void PerformanceTracker::EnsureDayAnchor(void)
  {
   datetime today = Date();
   if(m_dayAnchor != today)
      ResetDaily();
  }

void PerformanceTracker::OnEquityTick(const double balance, const double equity)
  {
   if(!m_ready)
      return;

   EnsureDayAnchor();

   m_balance = balance;
   m_equity  = equity;
   if(m_peakEquity == 0.0 || equity > m_peakEquity)
      m_peakEquity = equity;
   if(m_troughEquity == 0.0 || equity < m_troughEquity)
      m_troughEquity = equity;

   UpdateDrawdown();
   MaybeAlertDrawdown();
  }

void PerformanceTracker::OnTradeClosed(const double profit)
  {
   if(!m_ready)
      return;

   EnsureDayAnchor();

   m_tradeCount++;
   m_dailyPnL += profit;
   LogTrade(profit);

   if(profit >= 0.0)
     {
      m_totalProfit += profit;
      m_winCount++;
     }
   else
     {
      m_totalLoss += MathAbs(profit);
      m_lossCount++;
     }

   string direction = (profit >= 0.0 ? "WIN" : "LOSS");
   string message = StringFormat("Trade %s profit=%.2f dailyPnL=%.2f trades=%d",
                                 direction, profit, m_dailyPnL, m_tradeCount);
   m_logger.Info(message);
  }

void PerformanceTracker::UpdateDrawdown(void)
  {
   if(m_peakEquity <= 0.0)
      return;

   double drawdownPercent = 100.0 * (m_peakEquity - m_equity) / m_peakEquity;
   drawdownPercent = MathMax(drawdownPercent, 0.0);

   if(drawdownPercent > m_maxDrawdown)
     {
      m_maxDrawdown = drawdownPercent;
      m_logger.Warn(StringFormat("New max drawdown %.2f%% (equity %.2f)", m_maxDrawdown, m_equity));
     }
  }

void PerformanceTracker::MaybeAlertDrawdown(void)
  {
   if(m_maxDrawdown < m_warnDrawdown)
      return;

   AlertSeverity severity = ALERT_SEVERITY_WARNING;
   if(m_maxDrawdown >= m_critDrawdown)
      severity = ALERT_SEVERITY_CRITICAL;

   string msg = StringFormat("Drawdown %.2f%% (warn %.2f / crit %.2f)", m_maxDrawdown, m_warnDrawdown, m_critDrawdown);
   m_alerts.Raise("DRAW_DOWN", msg, severity);
  }

void PerformanceTracker::LogTrade(const double profit)
  {
   string severity = (profit >= 0.0 ? "INFO" : "WARN");
   string message = StringFormat("[%s] Trade closed profit=%.2f totalPnL=%.2f",
                                 severity, profit, m_dailyPnL);
   if(profit >= 0.0)
      m_logger.Debug(message);
   else
      m_logger.Warn(message);
  }

PerformanceSnapshot PerformanceTracker::Snapshot(void) const
  {
   PerformanceSnapshot snap;
   snap.timestamp    = TimeCurrent();
   snap.balance      = m_balance;
   snap.equity       = m_equity;
   snap.dailyPnL     = m_dailyPnL;
   snap.maxDrawdown  = m_maxDrawdown;
   snap.trades       = m_tradeCount;
   snap.winRate      = WinRate();
   snap.profitFactor = ProfitFactor();
   return snap;
  }

double PerformanceTracker::WinRate(void) const
  {
   if(m_tradeCount == 0)
      return 0.0;
   return 100.0 * (double)m_winCount / (double)m_tradeCount;
  }

double PerformanceTracker::ProfitFactor(void) const
  {
   if(m_totalLoss == 0.0)
      return (m_totalProfit == 0.0 ? 0.0 : 999.0);
   return m_totalProfit / m_totalLoss;
  }

#endif // __PERFORMANCE_TRACKER_MQH__
