#property strict
#property tester_indicator
#property script_show_inputs

#include "OptimizationParams.mqh"

// Performance analyzer for MT5 Strategy Tester integration. Tracks trade-level
// data in order to calculate optimization criteria and export rich reports that
// the Strategy Tester can consume when running optimizations, walk-forward
// simulations, and multi-currency passes.

input ENUM_OPTIMIZATION_CRITERIA InpOptimizationCriterion = OPT_CRITERIA_RECOVERY;
input double             InpRiskFreeRate         = 0.02;   // annual risk free rate
input bool               InpExportTradeHistory   = true;
input bool               InpExportEquityCurve    = true;
input bool               InpExportStrategySheet  = true;
input string             InpReportLabel          = "mt5_bot";
input bool               InpUseCommonFiles       = true;

struct TradeRecord
  {
   datetime time;
   string   symbol;
   double   volume;
   double   profit;
   double   balance;
   bool     is_win;
   ulong    ticket;
  };

class PerformanceAnalyzer
  {
private:
   double       m_riskFreeRate;
   double       m_maxDrawdown;
   double       m_highWatermark;
   double       m_grossProfit;
   double       m_grossLoss;
   double       m_netProfit;
   int          m_totalTrades;
   int          m_winningTrades;
   int          m_losingTrades;
   double       m_equity[];
   datetime     m_equityTime[];
   double       m_returns[];
   TradeRecord  m_trades[];

public:
   void         Reset()
     {
      m_riskFreeRate = InpRiskFreeRate;
      m_maxDrawdown  = 0.0;
      m_highWatermark= 0.0;
      m_grossProfit  = 0.0;
      m_grossLoss    = 0.0;
      m_netProfit    = 0.0;
      m_totalTrades  = 0;
      m_winningTrades= 0;
      m_losingTrades = 0;
      ArrayResize(m_equity,0);
      ArrayResize(m_equityTime,0);
      ArrayResize(m_returns,0);
      ArrayResize(m_trades,0);
     }

   bool         CollectHistory(datetime from_time, datetime to_time)
     {
      Reset();
      if(!HistorySelect(from_time,to_time))
         return false;

      double initial = TesterStatistics(STAT_INITIAL_DEPOSIT);
      if(initial==0.0)
         initial = AccountInfoDouble(ACCOUNT_BALANCE);

      ArrayResize(m_equity,1);
      ArrayResize(m_equityTime,1);
      m_equity[0]    = initial;
      m_equityTime[0]= from_time;
      m_highWatermark= initial;

      const int deals_total = HistoryDealsTotal();
      if(deals_total<=0)
         return false;

      ArrayResize(m_returns,deals_total);

      for(int i=0; i<deals_total; ++i)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket==0)
            continue;

         const long entry = HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry==DEAL_ENTRY_IN)
            continue; // wait for exit to avoid counting legs twice

         double volume = HistoryDealGetDouble(ticket,DEAL_VOLUME);
         if(MathAbs(volume)<DBL_EPSILON)
            continue;

         const double profit = HistoryDealGetDouble(ticket,DEAL_PROFIT) +
            HistoryDealGetDouble(ticket,DEAL_SWAP);
         const datetime deal_time = (datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
         const string symbol = HistoryDealGetString(ticket,DEAL_SYMBOL);

         const int next_index = ArraySize(m_equity);
         ArrayResize(m_equity,next_index+1);
         ArrayResize(m_equityTime,next_index+1);
         ArrayResize(m_trades,m_totalTrades+1);

         const double prev_equity = m_equity[next_index-1];
         const double new_equity  = prev_equity + profit;
         m_equity[next_index]     = new_equity;
         m_equityTime[next_index] = deal_time;
         m_returns[m_totalTrades] = (prev_equity!=0.0 ? profit/prev_equity : 0.0);

         TradeRecord record;
         record.time    = deal_time;
         record.symbol  = symbol;
         record.volume  = volume;
         record.profit  = profit;
         record.balance = new_equity;
         record.is_win  = (profit>0.0);
         record.ticket  = ticket;
         m_trades[m_totalTrades] = record;

         ++m_totalTrades;
         if(profit>0.0)
           {
            ++m_winningTrades;
            m_grossProfit += profit;
           }
         else if(profit<0.0)
           {
            ++m_losingTrades;
            m_grossLoss += MathAbs(profit);
           }

         m_netProfit += profit;

         if(new_equity>m_highWatermark)
            m_highWatermark = new_equity;

         const double drawdown = m_highWatermark - new_equity;
         if(drawdown>m_maxDrawdown)
            m_maxDrawdown = drawdown;
        }

      return (m_totalTrades>0);
     }

   double       SharpeRatio() const
     {
      const int count = m_totalTrades;
      if(count<2)
         return 0.0;

      double mean = 0.0;
      for(int i=0; i<count; ++i)
         mean += m_returns[i];
      mean /= count;

      const double daily_rf = InpRiskFreeRate/252.0;
      double variance = 0.0;
      for(int j=0; j<count; ++j)
        {
         const double diff = (m_returns[j]-daily_rf) - (mean-daily_rf);
         variance += diff*diff;
        }

      if(variance<=0.0)
         return 0.0;

      const double stddev = MathSqrt(variance/(count-1));
      if(stddev==0.0)
         return 0.0;

      return (mean-daily_rf)/stddev*MathSqrt(252.0);
     }

   double       MaxDrawdown() const
     {
      return m_maxDrawdown;
     }

   double       WinRate() const
     {
      if(m_totalTrades==0)
         return 0.0;
      return (double)m_winningTrades/(double)m_totalTrades;
     }

   double       ProfitFactor() const
     {
      if(m_grossLoss==0.0)
         return 0.0;
      return m_grossProfit/m_grossLoss;
     }

   double       NetProfit() const
     {
      return m_netProfit;
     }

   double       RecoveryFactor() const
     {
      if(m_maxDrawdown==0.0)
         return 0.0;
      return m_netProfit/m_maxDrawdown;
     }

   bool         ExportTradeHistory(const string file_name) const
     {
      if(ArraySize(m_trades)==0)
         return false;

      int flags = FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE;
      if(InpUseCommonFiles)
         flags |= FILE_COMMON;

      const int handle = FileOpen(file_name,flags);
      if(handle==INVALID_HANDLE)
         return false;

      FileWrite(handle,"ticket","time","symbol","volume","profit","balance","win");
      for(int i=0; i<ArraySize(m_trades); ++i)
        {
         const TradeRecord &rec = m_trades[i];
         FileWrite(handle,
                   LongToString((long)rec.ticket),
                   TimeToString(rec.time,TIME_DATE|TIME_SECONDS),
                   rec.symbol,
                   DoubleToString(rec.volume,2),
                   DoubleToString(rec.profit,2),
                   DoubleToString(rec.balance,2),
                   rec.is_win ? "1" : "0");
        }

      FileClose(handle);
      return true;
     }

   bool         ExportEquityCurve(const string file_name) const
     {
      if(ArraySize(m_equity)<=1)
         return false;

      int flags = FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE;
      if(InpUseCommonFiles)
         flags |= FILE_COMMON;

      const int handle = FileOpen(file_name,flags);
      if(handle==INVALID_HANDLE)
         return false;

      FileWrite(handle,"time","equity");
      for(int i=0; i<ArraySize(m_equity); ++i)
        {
         FileWrite(handle,
                   TimeToString(m_equityTime[i],TIME_DATE|TIME_SECONDS),
                   DoubleToString(m_equity[i],2));
        }

      FileClose(handle);
      return true;
     }

   bool         ExportStrategySnapshot(const string file_name,const string strategy_id,const double criterion_value) const
     {
      int flags = FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_READ|FILE_APPEND;
      if(InpUseCommonFiles)
         flags |= FILE_COMMON;

      const int handle = FileOpen(file_name,flags);
      if(handle==INVALID_HANDLE)
         return false;

      if(FileSize(handle)==0)
        {
         FileWrite(handle,"strategy","criterion","net_profit","win_rate","sharpe","max_dd","profit_factor","recovery_factor","trades");
        }

      FileSeek(handle,0,SEEK_END);
      FileWrite(handle,
                strategy_id,
                DoubleToString(criterion_value,4),
                DoubleToString(m_netProfit,2),
                DoubleToString(WinRate(),4),
                DoubleToString(SharpeRatio(),4),
                DoubleToString(MaxDrawdown(),2),
                DoubleToString(ProfitFactor(),4),
                DoubleToString(RecoveryFactor(),4),
                IntegerToString(m_totalTrades));
      FileClose(handle);
      return true;
     }
  };

PerformanceAnalyzer g_analyzer;

string ComposeReportName(const string suffix)
  {
   return InpReportLabel + "_" + suffix;
  }

double SelectCriterion()
  {
   return EvaluateOptimizationCriterion(InpOptimizationCriterion,
                                        g_analyzer.NetProfit(),
                                        g_analyzer.MaxDrawdown(),
                                        g_analyzer.SharpeRatio(),
                                        g_analyzer.ProfitFactor(),
                                        g_analyzer.WinRate());
  }

bool RefreshAnalyzer()
  {
   const datetime from_time = (datetime)TesterStatistics(STAT_START_DATE);
   const datetime to_time   = (datetime)TesterStatistics(STAT_END_DATE);
   return g_analyzer.CollectHistory(from_time,to_time);
  }

int OnInit()
  {
   SelectOptimizationSymbols();
   g_analyzer.Reset();
   return(INIT_SUCCEEDED);
  }

void OnTesterInit()
  {
   g_analyzer.Reset();
   ExportOptimizationManifest(ComposeReportName("optimization_params.csv"));
   ExportWalkForwardPlan(ComposeReportName("walkforward.csv"));
  }

double OnTester()
  {
   if(!RefreshAnalyzer())
      return 0.0;

   if(InpExportTradeHistory)
      g_analyzer.ExportTradeHistory(ComposeReportName("trades.csv"));

   if(InpExportEquityCurve)
      g_analyzer.ExportEquityCurve(ComposeReportName("equity.csv"));

   const double criterion = SelectCriterion();

   if(InpExportStrategySheet)
      g_analyzer.ExportStrategySnapshot(ComposeReportName("strategies.csv"),Symbol(),criterion);

   return criterion;
  }

void OnTesterPass()
  {
   if(!RefreshAnalyzer())
      return;

   const double criterion = SelectCriterion();
   if(InpExportStrategySheet)
      g_analyzer.ExportStrategySnapshot(ComposeReportName("strategies.csv"),Symbol(),criterion);
  }

void OnTesterDeinit()
  {
   // no-op but reserved for future report flushing
  }
