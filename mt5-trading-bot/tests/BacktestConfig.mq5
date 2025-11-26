#property copyright "MetaTrader 5"
#property strict
#property tester_indicator "BacktestConfig"

#include "..\\src\\backtesting\\OptimizationParams.mqh"

input string           TesterSymbols   = "EURUSD,GBPUSD,USDJPY";
input ENUM_TIMEFRAMES  TesterTimeframe = PERIOD_H1;
input string           ReportPrefix    = "regression";

string   Trim(const string value)
  {
   string copy=value;
   StringTrimLeft(copy);
   StringTrimRight(copy);
   return copy;
  }

void     PrintStrategyComparison()
  {
   string entries[];
   int total=StringSplit(TesterSymbols,',',entries);
   for(int i=0;i<total;i++)
      PrintFormat("Strategy #%d assigned to %s on %s",i+1,Trim(entries[i]),EnumToString(TesterTimeframe));
  }

void     ExportTradeHistoryCSV()
  {
   if(!ExportTradeHistory)
      return;

   string folder="reports";
   if(!FileIsExist(folder))
      FolderCreate(folder);

   string filename=StringFormat("%s/%s_trades.csv",folder,ReportPrefix);
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      Print("Failed to create trade report: ",GetLastError());
      return;
     }

   FileWrite(handle,"ticket","time","symbol","type","volume","profit","balance");

   if(!HistorySelect(0,TimeCurrent()))
     {
      Print("HistorySelect failed: ",GetLastError());
      FileClose(handle);
      return;
     }

   double balance=TesterStatistics(STAT_INITIAL_DEPOSIT);
   int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
     {
      ulong    ticket=HistoryDealGetTicket(i);
      datetime dealTime=(datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
      string   symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      ENUM_DEAL_TYPE dealType=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
      double   volume=HistoryDealGetDouble(ticket,DEAL_VOLUME);
      double   profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      balance+=profit;

      FileWrite(
         handle,
         (string)ticket,
         TimeToString(dealTime,TIME_DATE|TIME_SECONDS),
         symbol,
         EnumToString(dealType),
         DoubleToString(volume,2),
         DoubleToString(profit,2),
         DoubleToString(balance,2)
      );
     }

   FileClose(handle);
  }

double   CustomOptimizationScore()
  {
   double netProfit = TesterStatistics(STAT_PROFIT);
   double sharpe    = TesterStatistics(STAT_SHARPE_RATIO);
   double drawdown  = TesterStatistics(STAT_EQUITY_DD);
   if(drawdown<=0.0)
      drawdown=1.0;
   return (netProfit/drawdown)*(1.0+MathMin(sharpe,2.0));
  }

int      OnInit()
  {
   PrintOptimizationBands();
   PrintStrategyComparison();
   return(INIT_SUCCEEDED);
  }

double   OnTester()
  {
   return CustomOptimizationScore();
  }

void     OnTesterDeinit()
  {
   ExportTradeHistoryCSV();
  }
