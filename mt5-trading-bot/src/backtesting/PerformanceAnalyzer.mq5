#property copyright "MetaTrader 5"
#property link      "https://www.metatrader5.com"
#property version   "1.00"
#property strict
#property script_show_inputs

#include "OptimizationParams.mqh"

struct TesterPerformance
  {
   double   sharpe;
   double   maxDrawdown;
   double   winRate;
   double   profitFactor;
   double   recoveryFactor;
  };

TesterPerformance g_performance;

double  CalculateSharpeRatio()
  {
   double value=TesterStatistics(STAT_SHARPE_RATIO);
   if(MathIsValidNumber(value))
      return value;
   return 0.0;
  }

double  CalculateMaxDrawdown()
  {
   double dd = TesterStatistics(STAT_EQUITY_DD); // currency
   double equity = TesterStatistics(STAT_INITIAL_DEPOSIT);
   if(equity<=0.0)
      equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity>0.0)
      return dd / equity;
   return 0.0;
  }

double  CalculateWinRate()
  {
   double total = TesterStatistics(STAT_TRADES);
   if(total==0.0)
      return 0.0;
   return TesterStatistics(STAT_PROFIT_TRADES)/total;
  }

double  CalculateProfitFactor()
  {
   double value=TesterStatistics(STAT_PROFIT_FACTOR);
   if(MathIsValidNumber(value))
      return value;
   double grossProfit=TesterStatistics(STAT_GROSS_PROFIT);
   double grossLoss=MathAbs(TesterStatistics(STAT_GROSS_LOSS));
   if(grossLoss==0.0)
      return (grossProfit>0.0)?DBL_MAX:0.0;
   return grossProfit/grossLoss;
  }

double  CalculateRecoveryFactor(const double netProfit,double maxDrawdown)
  {
   if(maxDrawdown<=0.0)
      return DBL_MAX;
   return netProfit/maxDrawdown;
  }

void    CollectPerformance()
  {
   double netProfit = TesterStatistics(STAT_PROFIT);
   g_performance.sharpe         = CalculateSharpeRatio();
   g_performance.maxDrawdown    = CalculateMaxDrawdown();
   g_performance.winRate        = CalculateWinRate();
   g_performance.profitFactor   = CalculateProfitFactor();
   g_performance.recoveryFactor = CalculateRecoveryFactor(netProfit,TesterStatistics(STAT_EQUITY_DD));
  }

void    ExportPerformanceReport()
  {
   string reportFile = StringFormat("reports/%s_%s_performance.csv",__FILE__,_Symbol);
   if(!FileIsExist("reports"))
      FolderCreate("reports");

   int handle = FileOpen(reportFile,FILE_WRITE|FILE_CSV|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      Print("Failed to create performance report: ",GetLastError());
      return;
     }

   FileWrite(handle,"metric","value");
   FileWrite(handle,"SharpeRatio",DoubleToString(g_performance.sharpe,4));
   FileWrite(handle,"MaxDrawdown",DoubleToString(g_performance.maxDrawdown,4));
   FileWrite(handle,"WinRate",DoubleToString(g_performance.winRate*100.0,2)+"%");
   FileWrite(handle,"ProfitFactor",DoubleToString(g_performance.profitFactor,4));
   FileWrite(handle,"RecoveryFactor",DoubleToString(g_performance.recoveryFactor,4));
   FileClose(handle);
  }

int     OnInit()
  {
   return(INIT_SUCCEEDED);
  }

void    OnTesterInit()
  {
   ZeroMemory(g_performance);
  }

double  OnTester()
  {
   CollectPerformance();
   return g_performance.recoveryFactor;
  }

void    OnTesterDeinit()
  {
   ExportPerformanceReport();
  }
