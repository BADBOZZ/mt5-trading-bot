//+------------------------------------------------------------------+
//| BacktestConfig.mq5                                               |
//| Reference Strategy Tester setup for regression verification.      |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

#include "..\\src\\backtesting\\OptimizationParams.mqh"

input string   InpSymbols           = "EURUSD,GBPUSD,USDJPY";
input ENUM_TIMEFRAMES InpTimeframe  = PERIOD_H1;
input datetime InpStartDate         = D'2023.01.01';
input datetime InpEndDate           = D'2024.01.01';
input bool     InpEnableForward     = true;
input int      InpForwardDays       = 30;
input string   InpReportPrefix      = "tests\\reports";

struct StrategyTestResult
  {
   string symbol;
   double sharpe;
   double max_dd;
   double win_rate;
   double profit_factor;
   double recovery_factor;
  };

// Forward declarations -------------------------------------------------
string Trim(const string value);
void PrepareHistory(const string symbol);
void ExportTradeHistory(const string symbol,const string file_name);
StrategyTestResult AnalyzeSymbol(const string symbol);
void WriteStrategyComparison(const StrategyTestResult &rows[]);

//+------------------------------------------------------------------+
//| Script entry point                                               |
//+------------------------------------------------------------------+
void OnStart()
  {
   LogOptimizationRanges();

   string symbols[];
   StringSplit(InpSymbols,',',symbols);
   StrategyTestResult results[];

   for(int i=0;i<ArraySize(symbols);i++)
     {
      string symbol=Trim(symbols[i]);
      if(symbol=="")
         continue;
      PrepareHistory(symbol);
      StrategyTestResult stats=AnalyzeSymbol(symbol);
      int next=ArraySize(results);
      ArrayResize(results,next+1);
      results[next]=stats;
      string csv=StringFormat("%s_%s_trades.csv",InpReportPrefix,symbol);
      ExportTradeHistory(symbol,csv);
     }

   WriteStrategyComparison(results);
  }

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
string Trim(const string value)
  {
   string out=value;
   StringTrimLeft(out);
   StringTrimRight(out);
   return out;
  }

//+------------------------------------------------------------------+
//| Download history for Strategy Tester                             |
//+------------------------------------------------------------------+
void PrepareHistory(const string symbol)
  {
   datetime start=InpStartDate;
   datetime finish=InpEndDate;
   if(InpEnableForward)
      finish+=InpForwardDays*24*60*60;
   SymbolSelect(symbol,true);
   PrintFormat("History requested for %s %s from %s to %s",symbol,IntegerToString(InpTimeframe),TimeToString(start,TIME_DATE),TimeToString(finish,TIME_DATE));
   ResetLastError();
   MqlRates rates[];
   int copied=CopyRates(symbol,InpTimeframe,start,finish,rates);
   if(copied<=0)
      PrintFormat("Warning: unable to pre-load %s history, error %d",symbol,GetLastError());
  }

//+------------------------------------------------------------------+
//| Analyze closed deals for a symbol                                 |
//+------------------------------------------------------------------+
StrategyTestResult AnalyzeSymbol(const string symbol)
  {
   StrategyTestResult result;
   result.symbol=symbol;

   if(!HistorySelect(InpStartDate,InpEndDate))
     {
      Print("HistorySelect failed for analysis");
      return result;
     }

   double profits[];
   double balances[];
   bool wins[];

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);

   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
         continue;
      string deal_symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      if(deal_symbol!=symbol)
         continue;
      if((long)HistoryDealGetInteger(ticket,DEAL_ENTRY)!=DEAL_ENTRY_OUT)
         continue;

      double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      balance+=profit;

      int idx=ArraySize(profits);
      ArrayResize(profits,idx+1);
      profits[idx]=profit;

      ArrayResize(wins,idx+1);
      wins[idx]=(profit>0.0);

      ArrayResize(balances,idx+1);
      balances[idx]=balance;
     }

   // Metrics -------------------------------------------------------
   result.sharpe = CalculateSharpe(profits);
   result.max_dd = CalculateMaxDrawdown(balances);
   result.win_rate = CalculateWinRate(wins);
   result.profit_factor = CalculateProfitFactor(profits);
   double net_profit=0.0;
   for(int k=0;k<ArraySize(profits);k++)
      net_profit+=profits[k];
   result.recovery_factor = (result.max_dd<=0 ? 0 : net_profit/result.max_dd);

   PrintFormat("[%s] Sharpe=%.4f MDD=%.2f Win%%=%.2f ProfitFactor=%.4f",
               symbol,result.sharpe,result.max_dd,result.win_rate*100.0,result.profit_factor);
   return result;
  }

//+------------------------------------------------------------------+
//| Helpers for metrics                                              |
//+------------------------------------------------------------------+
double CalculateSharpe(const double &profits[])
  {
   int total=ArraySize(profits);
   if(total<=1)
      return 0.0;
   double mean=0.0;
   for(int i=0;i<total;i++)
      mean+=profits[i];
   mean/=total;

   double variance=0.0;
   for(int j=0;j<total;j++)
     {
      double diff=profits[j]-mean;
      variance+=diff*diff;
     }
   variance/=(total-1);
   if(variance<=0.0)
      return 0.0;
   return (mean/MathSqrt(variance))*MathSqrt(252.0);
  }

double CalculateMaxDrawdown(const double &balances[])
  {
   double peak=-DBL_MAX;
   double max_dd=0.0;
   for(int i=0;i<ArraySize(balances);i++)
     {
      double value=balances[i];
      if(value>peak)
         peak=value;
      double dd=peak-value;
      if(dd>max_dd)
         max_dd=dd;
     }
   return max_dd;
  }

double CalculateWinRate(const bool &wins[])
  {
   int total=ArraySize(wins);
   if(total==0)
      return 0.0;
   int success=0;
   for(int i=0;i<total;i++)
      if(wins[i])
         success++;
   return (double)success/(double)total;
  }

double CalculateProfitFactor(const double &profits[])
  {
   double gross_profit=0.0;
   double gross_loss=0.0;
   for(int i=0;i<ArraySize(profits);i++)
     {
      if(profits[i]>0)
         gross_profit+=profits[i];
      else
         gross_loss+=profits[i];
     }
   if(gross_loss>=0.0)
      return (gross_profit>0) ? DBL_MAX : 0.0;
   return MathAbs(gross_profit/gross_loss);
  }

//+------------------------------------------------------------------+
//| CSV export for Strategy Tester trade history                      |
//+------------------------------------------------------------------+
void ExportTradeHistory(const string symbol,const string file_name)
  {
   if(!HistorySelect(InpStartDate,InpEndDate))
      return;

   int handle=FileOpen(file_name,FILE_WRITE|FILE_CSV|FILE_ANSI,';');
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("Unable to open %s for writing",file_name);
      return;
     }

   FileWrite(handle,"ticket","time","symbol","profit","balance");
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
         continue;
      string deal_symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      if(deal_symbol!=symbol)
         continue;
      if((long)HistoryDealGetInteger(ticket,DEAL_ENTRY)!=DEAL_ENTRY_OUT)
         continue;
      balance+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      FileWrite(handle,(int)ticket,(datetime)HistoryDealGetInteger(ticket,DEAL_TIME),deal_symbol,
                HistoryDealGetDouble(ticket,DEAL_PROFIT),balance);
     }
   FileClose(handle);
   PrintFormat("Trade history exported to %s",file_name);
  }

//+------------------------------------------------------------------+
//| Strategy comparison report                                       |
//+------------------------------------------------------------------+
void WriteStrategyComparison(const StrategyTestResult &rows[])
  {
   string file_name=StringFormat("%s_strategy_comparison.csv",InpReportPrefix);
   int handle=FileOpen(file_name,FILE_WRITE|FILE_CSV|FILE_ANSI,';');
   if(handle==INVALID_HANDLE)
      return;
   FileWrite(handle,"symbol","sharpe","mdd","win_rate","profit_factor","recovery_factor");
   for(int i=0;i<ArraySize(rows);i++)
     {
      FileWrite(handle,
                rows[i].symbol,
                rows[i].sharpe,
                rows[i].max_dd,
                rows[i].win_rate,
                rows[i].profit_factor,
                rows[i].recovery_factor);
     }
   FileClose(handle);
   PrintFormat("Strategy comparison exported to %s",file_name);
  }
