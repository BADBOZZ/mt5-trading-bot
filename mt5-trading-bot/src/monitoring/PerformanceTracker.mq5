#property copyright "Monitoring Toolkit"
#property version   "1.00"
#property strict

#include "Logger.mq5"

//+------------------------------------------------------------------+
//| Strategy statistics structure                                    |
//+------------------------------------------------------------------+
struct StrategyStats
  {
   string   name;
   double   net_pnl;
   double   gross_profit;
   double   gross_loss;
   double   max_drawdown;
   double   peak_equity;
   int      trades;
   int      wins;
   datetime last_update;
  };

//+------------------------------------------------------------------+
//| Performance tracker                                              |
//+------------------------------------------------------------------+
class PerformanceTracker
  {
private:
   StrategyStats m_stats[];
   string        m_history_dir;
   string        m_history_file;

   int FindStrategyIndex(const string strategy) const
     {
      int total=ArraySize(m_stats);
      for(int i=0;i<total;i++)
        {
         if(m_stats[i].name==strategy)
            return(i);
        }
      return(-1);
     }

   int EnsureStrategy(const string strategy)
     {
      int idx=FindStrategyIndex(strategy);
      if(idx!=-1)
         return(idx);
      StrategyStats stats;
      stats.name=strategy;
      stats.net_pnl=0.0;
      stats.gross_profit=0.0;
      stats.gross_loss=0.0;
      stats.max_drawdown=0.0;
      stats.peak_equity=0.0;
      stats.trades=0;
      stats.wins=0;
      stats.last_update=TimeCurrent();
      int new_size=ArraySize(m_stats)+1;
      ArrayResize(m_stats,new_size);
      m_stats[new_size-1]=stats;
      return(new_size-1);
     }

   void AppendHistory(const StrategyStats &stats,const double pnl,const double equity,const double risk_bps) const
     {
      string path=StringFormat("%s\\%s",m_history_dir,m_history_file);
      int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
        {
         LogErrorEvent("PerformanceHistory",StringFormat("Unable to open %s",path));
         return;
        }
      FileSeek(handle,0,SEEK_END);
      string timestamp=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      FileWrite(handle,timestamp,stats.name,DoubleToString(pnl,2),DoubleToString(equity,2),DoubleToString(stats.net_pnl,2),DoubleToString(stats.max_drawdown,2),DoubleToString(risk_bps,2));
      FileClose(handle);
     }

public:
                     PerformanceTracker()
     {
      m_history_dir="MonitoringLogs";
      m_history_file="performance_history.csv";
      FolderCreate(m_history_dir);
     }

   void Configure(const string directory,const string filename)
     {
      m_history_dir=(directory=="" ? "MonitoringLogs" : directory);
      m_history_file=(filename=="" ? "performance_history.csv" : filename);
      FolderCreate(m_history_dir);
     }

   void UpdateTrade(const string strategy,
                    const double pnl,
                    const double equity_after,
                    const double risk_bps=0.0)
     {
      int idx=EnsureStrategy(strategy);
      StrategyStats &stats=m_stats[idx];
      stats.net_pnl+=pnl;
      if(pnl>=0.0)
         stats.gross_profit+=pnl;
      else
         stats.gross_loss+=MathAbs(pnl);
      stats.trades++;
      if(pnl>0.0)
         stats.wins++;

      if(equity_after>stats.peak_equity)
         stats.peak_equity=equity_after;
      double drawdown=MathMax(0.0,stats.peak_equity-equity_after);
      if(drawdown>stats.max_drawdown)
         stats.max_drawdown=drawdown;

      stats.last_update=TimeCurrent();
      LogPerformanceMetric(StringFormat("%s_trade_pnl",strategy),pnl,strategy,"trade");
      LogPerformanceMetric(StringFormat("%s_net",strategy),stats.net_pnl,strategy,"cumulative");
      AppendHistory(stats,pnl,equity_after,risk_bps);
     }

   double GetWinRate(const string strategy) const
     {
      int idx=FindStrategyIndex(strategy);
      if(idx==-1 || m_stats[idx].trades==0)
         return(0.0);
      return(100.0*m_stats[idx].wins/m_stats[idx].trades);
     }

   double GetNetPnl(const string strategy) const
     {
      int idx=FindStrategyIndex(strategy);
      if(idx==-1)
         return(0.0);
      return(m_stats[idx].net_pnl);
     }

   double GetMaxDrawdown(const string strategy) const
     {
      int idx=FindStrategyIndex(strategy);
      if(idx==-1)
         return(0.0);
      return(m_stats[idx].max_drawdown);
     }

   void CompareStrategies(const string primary,const string challenger,double &pnl_diff,double &win_rate_diff) const
     {
      pnl_diff=GetNetPnl(primary)-GetNetPnl(challenger);
      win_rate_diff=GetWinRate(primary)-GetWinRate(challenger);
     }

   void SnapshotAll() const
     {
      int total=ArraySize(m_stats);
      for(int i=0;i<total;i++)
        {
         const StrategyStats &stats=m_stats[i];
         LogPerformanceMetric(StringFormat("%s_snapshot",stats.name),stats.net_pnl,stats.name,"snapshot");
        }
     }
  };

//+------------------------------------------------------------------+
//| Global helper layer                                              |
//+------------------------------------------------------------------+
PerformanceTracker g_performance;

void InitializePerformanceTracker(const string directory="MonitoringLogs",const string filename="performance_history.csv")
  {
   g_performance.Configure(directory,filename);
  }

void TrackStrategyTrade(const string strategy,const double pnl,const double equity_after,const double risk_bps=0.0)
  {
   g_performance.UpdateTrade(strategy,pnl,equity_after,risk_bps);
  }

void CapturePerformanceSnapshot()
  {
   g_performance.SnapshotAll();
  }

void CompareStrategyPerformance(const string primary,const string challenger,double &pnl_diff,double &win_rate_diff)
  {
   g_performance.CompareStrategies(primary,challenger,pnl_diff,win_rate_diff);
  }

double GetStrategyWinRate(const string strategy)
  {
   return(g_performance.GetWinRate(strategy));
  }

double GetStrategyNetPnl(const string strategy)
  {
   return(g_performance.GetNetPnl(strategy));
  }

double GetStrategyMaxDrawdown(const string strategy)
  {
   return(g_performance.GetMaxDrawdown(strategy));
  }
