#property strict

struct PerformancePoint
  {
   datetime          timestamp;
   double            balance;
   double            equity;
   double            exposure;
   double            netProfit;
   double            drawdownPct;
   int               openPositions;
  };

struct StrategyStats
  {
   string            name;
   double            grossProfit;
   double            grossLoss;
   int               wins;
   int               losses;
   double            bestTrade;
   double            worstTrade;

   double            WinRate(void) const
     {
      const int total = wins + losses;
      return (total == 0) ? 0.0 : (100.0 * wins / total);
     }

   double            ProfitFactor(void) const
     {
      if(grossLoss == 0.0)
         return grossProfit <= 0 ? 0.0 : DBL_MAX;
      return MathAbs(grossProfit / grossLoss);
     }
  };

class CPerformanceTracker
  {
private:
   string            m_strategy;
   double            m_startBalance;
   double            m_peakEquity;
   double            m_latestBalance;
   double            m_latestEquity;
   PerformancePoint  m_points[];
   StrategyStats     m_strategies[];

public:
                     CPerformanceTracker(void)
     {
      m_strategy      = "Strategy";
      m_startBalance  = 0.0;
      m_peakEquity    = 0.0;
      m_latestBalance = 0.0;
      m_latestEquity  = 0.0;
     }

   void              Init(const string strategyName, const double startingBalance)
     {
      m_strategy      = strategyName;
      m_startBalance  = startingBalance;
      m_latestBalance = startingBalance;
      m_latestEquity  = startingBalance;
      m_peakEquity    = startingBalance;
      ArrayResize(m_points, 0);
      ArrayResize(m_strategies, 0);
     }

   void              UpdateRealtimeMetrics(const double balance,
                                           const double equity,
                                           const double exposure,
                                           const int openPositions)
     {
      m_latestBalance = balance;
      m_latestEquity  = equity;
      if(equity > m_peakEquity)
         m_peakEquity = equity;

      PerformancePoint point;
      point.timestamp     = TimeCurrent();
      point.balance       = balance;
      point.equity        = equity;
      point.exposure      = exposure;
      point.netProfit     = balance - m_startBalance;
      point.drawdownPct   = CalculateDrawdownPercent(equity);
      point.openPositions = openPositions;

      const int next = ArraySize(m_points) + 1;
      ArrayResize(m_points, next);
      m_points[next - 1] = point;
     }

   void              RecordStrategyTrade(const string strategyName,
                                         const double profit,
                                         const bool isWin)
     {
      const int index = EnsureStrategy(strategyName);
      StrategyStats stats = m_strategies[index];

      if(profit >= 0)
        {
         stats.grossProfit += profit;
        }
      else
        {
         stats.grossLoss += profit; // negative value
        }

      if(isWin)
         stats.wins++;
      else
         stats.losses++;

      if(stats.bestTrade < profit)
         stats.bestTrade = profit;

      if(stats.worstTrade > profit)
         stats.worstTrade = profit;

      m_strategies[index] = stats;
     }

   double            CurrentDrawdown(void) const
     {
      return CalculateDrawdownPercent(m_latestEquity);
     }

   double            NetProfit(void) const
     {
      return m_latestBalance - m_startBalance;
     }

   double            CAGR(const double yearsRunning) const
     {
      if(yearsRunning <= 0.0 || m_startBalance <= 0.0 || m_latestBalance <= 0.0)
         return 0.0;
      return 100.0 * (MathPow(m_latestBalance / m_startBalance, 1.0 / yearsRunning) - 1.0);
     }

   string            StrategyLeaderboard(void) const
     {
      string leaderboard = "Strategy,WinRate,ProfitFactor,Best,Worst\n";
      for(int i = 0; i < ArraySize(m_strategies); i++)
        {
         const StrategyStats stats = m_strategies[i];
         leaderboard += StringFormat("%s,%.2f,%.2f,%.2f,%.2f\n",
                                     stats.name,
                                     stats.WinRate(),
                                     stats.ProfitFactor(),
                                     stats.bestTrade,
                                     stats.worstTrade);
        }
      return leaderboard;
     }

   bool              ExportHistory(const string fileName = "monitoring/performance_history.csv") const
     {
      int handle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
      if(handle == INVALID_HANDLE)
        {
         PrintFormat("Performance tracker: cannot write %s. Error %d", fileName, GetLastError());
         return false;
        }

      FileWrite(handle, "timestamp", "balance", "equity", "exposure", "net_profit", "drawdown_pct", "open_positions");

      for(int i = 0; i < ArraySize(m_points); i++)
        {
         const PerformancePoint point = m_points[i];
         FileWrite(handle,
                   TimeToString(point.timestamp, TIME_DATE | TIME_SECONDS),
                   DoubleToString(point.balance, 2),
                   DoubleToString(point.equity, 2),
                   DoubleToString(point.exposure, 2),
                   DoubleToString(point.netProfit, 2),
                   DoubleToString(point.drawdownPct, 2),
                   IntegerToString(point.openPositions));
        }

      FileClose(handle);
      return true;
     }

private:
   double            CalculateDrawdownPercent(const double equity) const
     {
      if(m_peakEquity <= 0.0)
         return 0.0;
      double dd = (m_peakEquity - equity) / m_peakEquity;
      return MathMax(0.0, 100.0 * dd);
     }

   int               EnsureStrategy(const string strategyName)
     {
      for(int i = 0; i < ArraySize(m_strategies); i++)
        {
         if(m_strategies[i].name == strategyName)
            return i;
        }

      const int next = ArraySize(m_strategies) + 1;
      ArrayResize(m_strategies, next);
      StrategyStats stats;
      stats.name       = strategyName;
      stats.grossProfit = 0.0;
      stats.grossLoss  = 0.0;
      stats.wins       = 0;
      stats.losses     = 0;
      stats.bestTrade  = -DBL_MAX;
      stats.worstTrade = DBL_MAX;
      m_strategies[next - 1] = stats;
      return next - 1;
     }
  };
