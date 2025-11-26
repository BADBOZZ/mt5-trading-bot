//+------------------------------------------------------------------+
//| PerformanceTracker.mq5                                           |
//| Real-time and historical performance tracking utilities          |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Strategy level statistics container                              |
//+------------------------------------------------------------------+
class CStrategyStats : public CObject
  {
private:
   string   m_name;
   double   m_net_profit;
   double   m_gross_profit;
   double   m_gross_loss;
   double   m_volume;
   int      m_total_trades;
   int      m_wins;
   int      m_losses;
   double   m_best_trade;
   double   m_worst_trade;
   double   m_peak_equity;
   double   m_max_drawdown;
   datetime m_last_update;
   double   m_pending_equity[];
   datetime m_pending_timestamps[];

public:
   CStrategyStats();
   void     Init(const string name);
   void     UpdateTrade(const double profit,const double volume,const double balanceAfter,const double riskPerTrade,const ulong ticket,const string symbol);
   void     PushEquity(const datetime timestamp,const double equity);
   int      ExportSnapshots(const int handle) const;
   void     ClearSnapshots();

   string   Name() const { return(m_name); }
   double   NetProfit() const { return(m_net_profit); }
   double   ProfitFactor() const { return(m_gross_loss!=0.0 ? MathAbs(m_gross_profit/m_gross_loss) : 0.0); }
   double   WinRate() const { return(m_total_trades>0 ? (double)m_wins/m_total_trades : 0.0); }
   double   AvgTrade() const { return(m_total_trades>0 ? m_net_profit/m_total_trades : 0.0); }
   double   Volume() const { return(m_volume); }
   double   MaxDrawdown() const { return(m_max_drawdown); }
   int      TotalTrades() const { return(m_total_trades); }
   datetime LastUpdate() const { return(m_last_update); }
   double   BestTrade() const { return(m_best_trade); }
   double   WorstTrade() const { return(m_worst_trade); }
   int      PendingSnapshotCount() const { return(ArraySize(m_pending_equity)); }
  };

//+------------------------------------------------------------------+
//| Performance tracker with storage                                 |
//+------------------------------------------------------------------+
class CPerformanceTracker
  {
private:
   CArrayObj m_stats;
   string    m_strategy_names[];
   string    m_storage_dir;
   int       m_flush_interval_sec;
   datetime  m_last_flush;

   CStrategyStats* GetOrCreate(const string strategy);
   int      FindIndex(const string strategy) const;
   bool     EnsureDirectory() const;
   void     MaybeFlush();
   string   BuildFilePath(const string strategy) const;

public:
   CPerformanceTracker();
   bool     Init(const string storageDir="Monitoring\\Performance",const int flushIntervalSec=300);
   void     RecordTrade(const string strategy,const string symbol,const double profit,const double balanceAfter,const double volume,const double riskPerTrade,const ulong ticket);
   void     RecordEquity(const string strategy,const datetime timestamp,const double equity);
   void     FlushHistory();
   string   Leaderboard() const;
   double   GetMetric(const string strategy,const string metric) const;
  };

//+------------------------------------------------------------------+
//| Strategy stats implementation                                    |
//+------------------------------------------------------------------+
CStrategyStats::CStrategyStats()
  {
   Init("");
  }

void CStrategyStats::Init(const string name)
  {
   m_name=name;
   m_net_profit=0.0;
   m_gross_profit=0.0;
   m_gross_loss=0.0;
   m_volume=0.0;
   m_total_trades=0;
   m_wins=0;
   m_losses=0;
   m_best_trade=-DBL_MAX;
   m_worst_trade=DBL_MAX;
   m_peak_equity=0.0;
   m_max_drawdown=0.0;
   m_last_update=0;
   ArrayResize(m_pending_equity,0);
   ArrayResize(m_pending_timestamps,0);
  }

void CStrategyStats::UpdateTrade(const double profit,const double volume,const double balanceAfter,const double riskPerTrade,const ulong ticket,const string symbol)
  {
   m_net_profit+=profit;
   if(profit>=0)
     {
      m_gross_profit+=profit;
      m_wins++;
     }
   else
     {
      m_gross_loss+=profit;
      m_losses++;
     }

   m_total_trades++;
   m_volume+=volume;
   if(profit>m_best_trade)
      m_best_trade=profit;
   if(profit<m_worst_trade)
      m_worst_trade=profit;

   if(balanceAfter>m_peak_equity)
      m_peak_equity=balanceAfter;

   const double drawdown=m_peak_equity-balanceAfter;
   if(drawdown>m_max_drawdown)
      m_max_drawdown=drawdown;

   m_last_update=TimeCurrent();

   string message=StringFormat("%s | ticket=%I64u symbol=%s profit=%.2f risk=%.2f",
                               m_name,ticket,symbol,profit,riskPerTrade);
   Print("[Performance] ",message);
  }

void CStrategyStats::PushEquity(const datetime timestamp,const double equity)
  {
   const int current=ArraySize(m_pending_equity);
   ArrayResize(m_pending_equity,current+1);
   ArrayResize(m_pending_timestamps,current+1);
   m_pending_equity[current]=equity;
   m_pending_timestamps[current]=timestamp;

   if(equity>m_peak_equity)
      m_peak_equity=equity;

   const double drawdown=m_peak_equity-equity;
   if(drawdown>m_max_drawdown)
      m_max_drawdown=drawdown;
  }

int CStrategyStats::ExportSnapshots(const int handle) const
  {
   const int count=ArraySize(m_pending_equity);
   for(int i=0;i<count;i++)
     {
      const string timestamp=TimeToString(m_pending_timestamps[i],TIME_DATE|TIME_SECONDS);
      FileWrite(handle,m_name,timestamp,DoubleToString(m_pending_equity[i],2),DoubleToString(m_net_profit,2),DoubleToString(m_max_drawdown,2));
     }

   return(count);
  }

void CStrategyStats::ClearSnapshots()
  {
   ArrayResize(m_pending_equity,0);
   ArrayResize(m_pending_timestamps,0);
  }

//+------------------------------------------------------------------+
//| Performance tracker implementation                               |
//+------------------------------------------------------------------+
CPerformanceTracker::CPerformanceTracker()
  {
   m_stats.Create();
   ArrayResize(m_strategy_names,0);
   m_storage_dir="Monitoring\\Performance";
   m_flush_interval_sec=300;
   m_last_flush=0;
  }

bool CPerformanceTracker::Init(const string storageDir,const int flushIntervalSec)
  {
   m_storage_dir=storageDir;
   m_flush_interval_sec=MathMax(60,flushIntervalSec);
   return(EnsureDirectory());
  }

CStrategyStats* CPerformanceTracker::GetOrCreate(const string strategy)
  {
   const int index=FindIndex(strategy);
   if(index!=-1)
      return((CStrategyStats*)m_stats.At(index));

   CStrategyStats *stats=new CStrategyStats;
   stats.Init(strategy);
   m_stats.Add(stats);
   const int size=ArraySize(m_strategy_names);
   ArrayResize(m_strategy_names,size+1);
   m_strategy_names[size]=strategy;
   return(stats);
  }

int CPerformanceTracker::FindIndex(const string strategy) const
  {
   const int size=ArraySize(m_strategy_names);
   for(int i=0;i<size;i++)
     {
      if(m_strategy_names[i]==strategy)
         return(i);
     }
   return(-1);
  }

bool CPerformanceTracker::EnsureDirectory() const
  {
   ResetLastError();
   if(FolderCreate(m_storage_dir))
      return(true);

   const int err=GetLastError();
   if(err==5010)
      return(true);

   PrintFormat("[Performance] Unable to prepare directory %s (err=%d)",m_storage_dir,err);
   return(false);
  }

string CPerformanceTracker::BuildFilePath(const string strategy) const
  {
   return(m_storage_dir+"\\"+strategy+"_performance.csv");
  }

void CPerformanceTracker::RecordTrade(const string strategy,const string symbol,const double profit,const double balanceAfter,const double volume,const double riskPerTrade,const ulong ticket)
  {
   CStrategyStats *stats=GetOrCreate(strategy);
   if(stats==NULL)
      return;

   stats.UpdateTrade(profit,volume,balanceAfter,riskPerTrade,ticket,symbol);
   MaybeFlush();
  }

void CPerformanceTracker::RecordEquity(const string strategy,const datetime timestamp,const double equity)
  {
   CStrategyStats *stats=GetOrCreate(strategy);
   if(stats==NULL)
      return;

   stats.PushEquity(timestamp,equity);
   MaybeFlush();
  }

void CPerformanceTracker::MaybeFlush()
  {
   if(m_last_flush==0)
      m_last_flush=TimeCurrent();

   if(TimeCurrent()-m_last_flush<m_flush_interval_sec)
      return;

   FlushHistory();
  }

void CPerformanceTracker::FlushHistory()
  {
   if(!EnsureDirectory())
      return;

   const int count=m_stats.Total();
   for(int i=0;i<count;i++)
     {
      CStrategyStats *stats=(CStrategyStats*)m_stats.At(i);
      if(stats==NULL || stats.PendingSnapshotCount()==0)
         continue;

      const string path=BuildFilePath(stats.Name());
      const int fileHandle=FileOpen(path,FILE_WRITE|FILE_READ|FILE_CSV|FILE_SHARE_READ|FILE_ANSI);
      if(fileHandle==INVALID_HANDLE)
        {
         PrintFormat("[Performance] Unable to open %s (err=%d)",path,GetLastError());
         continue;
        }

      const bool isNew=(FileSize(fileHandle)==0);
      FileSeek(fileHandle,0,SEEK_END);
      if(isNew)
         FileWrite(fileHandle,"strategy","timestamp","equity","net_profit","max_drawdown");

      stats.ExportSnapshots(fileHandle);
      FileClose(fileHandle);
      stats.ClearSnapshots();
     }

   m_last_flush=TimeCurrent();
  }

string CPerformanceTracker::Leaderboard() const
  {
   string report="Strategy,NetProfit,WinRate,PF,Trades\n";
   const int count=m_stats.Total();
   for(int i=0;i<count;i++)
     {
      CStrategyStats *stats=(CStrategyStats*)m_stats.At(i);
      if(stats==NULL)
         continue;

      report+=StringFormat("%s,%.2f,%.2f,%.2f,%d\n",
                           stats.Name(),
                           stats.NetProfit(),
                           stats.WinRate(),
                           stats.ProfitFactor(),
                           stats.TotalTrades());
     }
   return(report);
  }

static double ExtractMetric(const CStrategyStats *stats,const string metric)
  {
   if(stats==NULL)
      return(0.0);

   if(metric=="net_profit")
      return(stats.NetProfit());
   if(metric=="win_rate")
      return(stats.WinRate());
   if(metric=="profit_factor")
      return(stats.ProfitFactor());
   if(metric=="max_drawdown")
      return(stats.MaxDrawdown());
   if(metric=="avg_trade")
      return(stats.AvgTrade());
   if(metric=="best_trade")
      return(stats.BestTrade());
   if(metric=="worst_trade")
      return(stats.WorstTrade());
   if(metric=="trades")
      return(stats.TotalTrades());

   return(0.0);
  }

double CPerformanceTracker::GetMetric(const string strategy,const string metric) const
  {
   const int index=FindIndex(strategy);
   if(index==-1)
      return(0.0);

   CStrategyStats *stats=(CStrategyStats*)m_stats.At(index);
   return(ExtractMetric(stats,metric));
  }

//+------------------------------------------------------------------+
//| Global helper instance                                           |
//+------------------------------------------------------------------+
CPerformanceTracker g_PerformanceTracker;

bool InitPerformanceTracker()
  {
   return(g_PerformanceTracker.Init());
  }

void FlushPerformanceTracker()
  {
   g_PerformanceTracker.FlushHistory();
  }

//+------------------------------------------------------------------+
