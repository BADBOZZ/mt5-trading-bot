#property strict
#ifndef __PERFORMANCE_TRACKER_MQ5__
#define __PERFORMANCE_TRACKER_MQ5__

#include <Trade\Trade.mqh>
#include <Math\Stat.mqh>
#include "Logger.mq5"
#include "Alerts.mq5"

//+------------------------------------------------------------------+
//| Rolling statistics per strategy                                  |
//+------------------------------------------------------------------+
struct StrategyStats
  {
   string            Id;
   double            NetProfit;
   double            GrossProfit;
   double            GrossLoss;
   double            PeakEquity;
   double            Equity;
   double            MaxDrawdownPct;
   double            MaxRunupPct;
   double            TotalVolume;
   double            TotalHoldMinutes;
   int               TotalTrades;
   int               WinningTrades;
   int               LosingTrades;
   double            SumReturns;
   double            SumSqReturns;
   double            BestTrade;
   double            WorstTrade;
   datetime          LastTradeTime;

                     StrategyStats(void)
     {
      Id="";
      NetProfit=0.0;
      GrossProfit=0.0;
      GrossLoss=0.0;
      PeakEquity=0.0;
      Equity=0.0;
      MaxDrawdownPct=0.0;
      MaxRunupPct=0.0;
      TotalVolume=0.0;
      TotalHoldMinutes=0.0;
      TotalTrades=0;
      WinningTrades=0;
      LosingTrades=0;
      SumReturns=0.0;
      SumSqReturns=0.0;
      BestTrade=-DBL_MAX;
      WorstTrade=DBL_MAX;
      LastTradeTime=0;
     }
  };

//+------------------------------------------------------------------+
//| Performance tracker                                              |
//+------------------------------------------------------------------+
class PerformanceTracker
  {
private:
   string            m_historyFolder;
   string            m_historyFile;
   string            m_snapshotFile;
   double            m_startBalance;
   double            m_currentBalance;
   double            m_currentEquity;
   double            m_globalPeakEquity;
   double            m_globalMaxDrawdown;
   datetime          m_sessionStart;
   datetime          m_lastSnapshot;
   int               m_snapshotIntervalMinutes;
   bool              m_historyReady;
   MonitoringLogger *m_logger;
   AlertService     *m_alerts;
   string            m_strategyIds[];
   StrategyStats     m_strategyStats[];

   string NormalizePath(const string value)
     {
      string path=value;
      if(StringLen(path)==0)
         path="monitoring\\performance";
      StringReplace(path,"/","\\");
      while(StringFind(path,"\\\\")>=0)
         StringReplace(path,"\\\\","\\");
      return path;
     }

   bool EnsureHistoryFolder(void)
     {
      if(m_historyReady)
         return true;
      string folder=NormalizePath(m_historyFolder);
      if(FileIsExist(folder,FILE_COMMON) || FolderCreate(folder,FILE_COMMON))
        {
         m_historyReady=true;
         m_historyFolder=folder;
         m_historyFile=folder+"\\trade_history.csv";
         m_snapshotFile=folder+"\\snapshots.csv";
         return true;
        }
      int err=GetLastError();
      PrintFormat("[Performance] Failed to create folder %s (error %d)",folder,err);
      return false;
     }

   string FormatTimestamp(void) const
     {
      return TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
     }

   void ResetStats(StrategyStats &stats,const string strategyId)
     {
      stats=StrategyStats();
      stats.Id=strategyId;
      stats.PeakEquity=m_startBalance;
      stats.Equity=m_startBalance;
     }

   int EnsureStrategyIndex(const string strategyId)
     {
      int count=ArraySize(m_strategyIds);
      for(int i=0;i<count;i++)
        {
         if(m_strategyIds[i]==strategyId)
            return i;
        }

      int newSize=count+1;
      ArrayResize(m_strategyIds,newSize);
      ArrayResize(m_strategyStats,newSize);
      int index=newSize-1;
      ResetStats(m_strategyStats[index],strategyId);
      m_strategyIds[index]=strategyId;
      return index;
     }

   double WinRate(const StrategyStats &stats) const
     {
      if(stats.TotalTrades==0)
         return 0.0;
      return (double)stats.WinningTrades/(double)stats.TotalTrades*100.0;
     }

   double ProfitFactor(const StrategyStats &stats) const
     {
      if(MathAbs(stats.GrossLoss)<DBL_EPSILON)
         return (stats.GrossProfit>0.0)?stats.GrossProfit:0.0;
      return stats.GrossProfit/MathAbs(stats.GrossLoss);
     }

   double AverageTrade(const StrategyStats &stats) const
     {
      if(stats.TotalTrades==0)
         return 0.0;
      return stats.NetProfit/(double)stats.TotalTrades;
     }

   double SharpeRatio(const StrategyStats &stats) const
     {
      if(stats.TotalTrades<2)
         return 0.0;
      double mean=stats.SumReturns/(double)stats.TotalTrades;
      double variance=(stats.SumSqReturns - stats.SumReturns*stats.SumReturns/(double)stats.TotalTrades)/(double)(stats.TotalTrades-1);
      if(variance<=0.0)
         return 0.0;
      double stdDev=MathSqrt(variance);
      if(stdDev<=0.0)
         return 0.0;
      return mean/stdDev*MathSqrt(252.0);
     }

   double AverageHoldMinutes(const StrategyStats &stats) const
     {
      if(stats.TotalTrades==0)
         return 0.0;
      return stats.TotalHoldMinutes/(double)stats.TotalTrades;
     }

   double MaxDrawdownAll(void) const
     {
      double combined=m_globalMaxDrawdown;
      int count=ArraySize(m_strategyStats);
      for(int i=0;i<count;i++)
         combined=MathMax(combined,m_strategyStats[i].MaxDrawdownPct);
      return combined;
     }

   bool AppendHistoryRow(const string strategyId,const string symbol,const ENUM_ORDER_TYPE orderType,const ulong ticket,
                         const double volume,const double entryPrice,const double exitPrice,const double profit,
                         const double balanceAfter,const double equityAfter,const double riskAmount,
                         const double holdMinutes,const string note)
     {
      if(!EnsureHistoryFolder())
         return false;

      string fields[];
      if(ArrayResize(fields,14)!=14)
         return false;
      int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      if(digits<=0)
         digits=(int)_Digits;

      fields[0]=FormatTimestamp();
      fields[1]=strategyId;
      fields[2]=symbol;
      fields[3]=EnumToString(orderType);
      fields[4]=(string)ticket;
      fields[5]=DoubleToString(volume,2);
      fields[6]=DoubleToString(entryPrice,digits);
      fields[7]=DoubleToString(exitPrice,digits);
      fields[8]=DoubleToString(profit,2);
      fields[9]=DoubleToString(balanceAfter,2);
      fields[10]=DoubleToString(equityAfter,2);
      fields[11]=DoubleToString(riskAmount,2);
      fields[12]=DoubleToString(holdMinutes,2);
      fields[13]=note;

      string row="";
      int size=ArraySize(fields);
      for(int i=0;i<size;i++)
        {
         if(i>0)
            row+=",";
         string value=fields[i];
         StringReplace(value,"\"","\"\"");
         if(StringFind(value,",")>=0 || StringFind(value,";")>=0 || StringFind(value,"\n")>=0)
            value="\""+value+"\"";
         row+=value;
        }
      row+="\r\n";

      string path=(StringLen(m_historyFile)>0)?m_historyFile:(NormalizePath(m_historyFolder)+"\\trade_history.csv");
      int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
      if(handle==INVALID_HANDLE)
        {
         int err=GetLastError();
         PrintFormat("[Performance] Unable to open history file (%d)",err);
         return false;
        }
      FileSeek(handle,0,SEEK_END);
      bool ok=(FileWriteString(handle,row)>0);
      FileClose(handle);
      return ok;
     }

   bool AppendSnapshot(const StrategyStats &stats)
     {
      if(!EnsureHistoryFolder())
         return false;

      string fields[];
      if(ArrayResize(fields,11)!=11)
         return false;

      fields[0]=FormatTimestamp();
      fields[1]=stats.Id;
      fields[2]=DoubleToString(stats.NetProfit,2);
      fields[3]=DoubleToString(WinRate(stats),2);
      fields[4]=DoubleToString(ProfitFactor(stats),2);
      fields[5]=DoubleToString(SharpeRatio(stats),2);
      fields[6]=DoubleToString(stats.MaxDrawdownPct,2);
      fields[7]=(string)stats.TotalTrades;
      fields[8]=DoubleToString(AverageTrade(stats),2);
      fields[9]=DoubleToString(stats.TotalVolume,2);
      fields[10]=DoubleToString(stats.Equity,2);

      string row="";
      for(int i=0;i<11;i++)
        {
         if(i>0)
            row+=",";
         row+=fields[i];
        }
      row+="\r\n";

      string path=(StringLen(m_snapshotFile)>0)?m_snapshotFile:(NormalizePath(m_historyFolder)+"\\snapshots.csv");
      int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
      if(handle==INVALID_HANDLE)
        {
         int err=GetLastError();
         PrintFormat("[Performance] Unable to open snapshot file (%d)",err);
         return false;
        }
      FileSeek(handle,0,SEEK_END);
      bool ok=(FileWriteString(handle,row)>0);
      FileClose(handle);
      return ok;
     }

   void UpdateDrawdownForStats(StrategyStats &stats,const double equityAfter)
     {
      if(equityAfter>stats.PeakEquity)
         stats.PeakEquity=equityAfter;
      stats.Equity=equityAfter;
      if(stats.PeakEquity>0.0)
        {
         double dd=(stats.PeakEquity-equityAfter)/stats.PeakEquity*100.0;
         if(dd>stats.MaxDrawdownPct)
            stats.MaxDrawdownPct=dd;
         double runup=(equityAfter-m_startBalance)/m_startBalance*100.0;
         if(runup>stats.MaxRunupPct)
            stats.MaxRunupPct=runup;
        }
     }

   bool MaybeSnapshot(void)
     {
      if(m_snapshotIntervalMinutes<=0)
         return false;
      datetime now=TimeCurrent();
      if(m_lastSnapshot!=0 && (now-m_lastSnapshot)<m_snapshotIntervalMinutes*60)
         return false;
      bool ok=true;
      int count=ArraySize(m_strategyStats);
      for(int i=0;i<count;i++)
         ok&=AppendSnapshot(m_strategyStats[i]);
      m_lastSnapshot=now;
      return ok;
     }

   void TouchLogger(const StrategyStats &stats)
     {
      if(m_logger==NULL)
         return;
      m_logger.LogPerformance(stats.Id,stats.NetProfit,m_currentBalance,m_currentEquity,WinRate(stats),stats.MaxDrawdownPct,SharpeRatio(stats),ProfitFactor(stats));
     }

public:
                     PerformanceTracker(void)
     {
      m_historyFolder="monitoring\\performance";
      m_historyFile="";
      m_snapshotFile="";
      m_startBalance=0.0;
      m_currentBalance=0.0;
      m_currentEquity=0.0;
      m_globalPeakEquity=0.0;
      m_globalMaxDrawdown=0.0;
      m_sessionStart=TimeCurrent();
      m_lastSnapshot=0;
      m_snapshotIntervalMinutes=15;
      m_historyReady=false;
      m_logger=NULL;
      m_alerts=NULL;
      ArrayFree(m_strategyIds);
      ArrayFree(m_strategyStats);
     }

   void             Init(const double balance,const string historyFolder="monitoring\\performance")
     {
      m_startBalance=balance;
      m_currentBalance=balance;
      m_currentEquity=balance;
      m_globalPeakEquity=balance;
      m_globalMaxDrawdown=0.0;
      m_sessionStart=TimeCurrent();
      m_historyFolder=NormalizePath(historyFolder);
      m_lastSnapshot=0;
      m_historyReady=false;
      EnsureHistoryFolder();
     }

   void             AttachLogger(MonitoringLogger *logger)
     {
      m_logger=logger;
     }

   void             AttachAlerts(AlertService *alerts)
     {
      m_alerts=alerts;
     }

   void             SetSnapshotInterval(const int minutes)
     {
      m_snapshotIntervalMinutes=MathMax(1,minutes);
     }

   bool             UpdateEquity(const double balance,const double equity)
     {
      m_currentBalance=balance;
      m_currentEquity=equity;
      if(equity>m_globalPeakEquity)
         m_globalPeakEquity=equity;
      if(m_globalPeakEquity>0.0)
        {
         double dd=(m_globalPeakEquity-equity)/m_globalPeakEquity*100.0;
         if(dd>m_globalMaxDrawdown)
            m_globalMaxDrawdown=dd;
        }
      return MaybeSnapshot();
     }

   bool             RecordTrade(const string strategyId,const string symbol,const ENUM_ORDER_TYPE orderType,
                                const double volume,const double entryPrice,const double exitPrice,
                                const double stopLoss,const double takeProfit,const double profit,
                                const double balanceAfter,const double equityAfter,
                                const datetime openTime,const datetime closeTime,const double riskAmount,
                                const ulong ticket=0,
                                const string note="")
     {
      int index=EnsureStrategyIndex(strategyId);
      StrategyStats &stats=m_strategyStats[index];
      stats.TotalTrades++;
      stats.TotalVolume+=volume;
      stats.NetProfit+=profit;
      if(profit>=0.0)
        {
         stats.WinningTrades++;
         stats.GrossProfit+=profit;
         if(profit>stats.BestTrade)
            stats.BestTrade=profit;
        }
      else
        {
         stats.LosingTrades++;
         stats.GrossLoss+=profit;
         if(profit<stats.WorstTrade)
            stats.WorstTrade=profit;
        }
      double holdMinutes=0.0;
      if(closeTime>openTime)
         holdMinutes=(double)(closeTime-openTime)/60.0;
      stats.TotalHoldMinutes+=holdMinutes;
      double pctReturn=(balanceAfter>0.0)?(profit/balanceAfter*100.0):0.0;
      stats.SumReturns+=pctReturn;
      stats.SumSqReturns+=pctReturn*pctReturn;
      stats.LastTradeTime=closeTime;

      m_currentBalance=balanceAfter;
      m_currentEquity=equityAfter;
      UpdateDrawdownForStats(stats,equityAfter);
      UpdateEquity(balanceAfter,equityAfter);
      TouchLogger(stats);

      AppendHistoryRow(strategyId,symbol,orderType,ticket,volume,entryPrice,exitPrice,profit,balanceAfter,equityAfter,riskAmount,holdMinutes,note);

      if(m_logger!=NULL)
         m_logger.LogTrade(strategyId,symbol,orderType,volume,exitPrice,stopLoss,takeProfit,ticket,profit,balanceAfter,equityAfter,note);

      return true;
     }

   StrategyStats    GetStats(const string strategyId) const
     {
      int count=ArraySize(m_strategyIds);
      for(int i=0;i<count;i++)
        {
         if(m_strategyIds[i]==strategyId)
            return m_strategyStats[i];
        }
      return StrategyStats();
     }

   string           CompareStrategies(const string first,const string second) const
     {
      StrategyStats a=GetStats(first);
      StrategyStats b=GetStats(second);
      if(StringLen(a.Id)==0 || StringLen(b.Id)==0)
         return "Comparison unavailable - stats missing";

      string summary=StringFormat("%s vs %s | net %.2f vs %.2f | win %.2f%% vs %.2f%% | PF %.2f vs %.2f | DD %.2f%% vs %.2f%%",
                                  first,
                                  second,
                                  a.NetProfit,
                                  b.NetProfit,
                                  WinRate(a),
                                  WinRate(b),
                                  ProfitFactor(a),
                                  ProfitFactor(b),
                                  a.MaxDrawdownPct,
                                  b.MaxDrawdownPct);
      return summary;
     }

   string           BuildDailyReport(void) const
     {
      string report=StringFormat("Session %s | Balance %.2f -> %.2f | Equity %.2f | Max DD %.2f%%",
                                 TimeToString(m_sessionStart,TIME_DATE),
                                 m_startBalance,
                                 m_currentBalance,
                                 m_currentEquity,
                                 MaxDrawdownAll());
      int count=ArraySize(m_strategyStats);
      for(int i=0;i<count;i++)
        {
         const StrategyStats &stats=m_strategyStats[i];
         report+=StringFormat("\n - %s | net %.2f | win %.2f%% | PF %.2f | DD %.2f%% | trades %d",
                              stats.Id,
                              stats.NetProfit,
                              WinRate(stats),
                              ProfitFactor(stats),
                              stats.MaxDrawdownPct,
                              stats.TotalTrades);
        }
      return report;
     }

   bool             SendDailyReport(void)
     {
      if(m_alerts==NULL)
         return false;
      double dailyReturn=(m_currentEquity-m_startBalance)/m_startBalance*100.0;
      string report=BuildDailyReport();
      return m_alerts.SendPerformanceReport("Daily Performance",report,dailyReturn,MaxDrawdownAll(),m_currentEquity,true);
     }
  };

#endif // __PERFORMANCE_TRACKER_MQ5__
