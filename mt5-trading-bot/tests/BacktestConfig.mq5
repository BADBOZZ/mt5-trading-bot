#property script_show_inputs
#property strict

#include "..\\src\\backtesting\\PerformanceAnalyzer.mq5"
#include "..\\src\\backtesting\\OptimizationParams.mqh"

input string   InpSymbols      = "EURUSD,GBPUSD,USDJPY";
input datetime InpStartDate    = D'2024.01.01';
input datetime InpEndDate      = D'2024.06.30';
input double   InpRiskFreeRate = 0.02;
input string   InpReportSuffix = "validation";

void OnStart()
  {
   Print("Generating backtest configuration snapshot...");
   const string configFile = BuildReportName("CONFIG", "tester");
   if(SaveTesterConfig(configFile))
      PrintFormat("Strategy Tester config exported to %s", configFile);

   TradePerformanceStats stats;
   CPerformanceAnalyzer analyzer;
   double equityCurve[];
   ArrayResize(equityCurve, 5);
   equityCurve[0] = 10000;
   equityCurve[1] = 10250;
   equityCurve[2] = 10100;
   equityCurve[3] = 10500;
   equityCurve[4] = 10400;

   double tradeReturns[];
   ArrayResize(tradeReturns, 4);
   tradeReturns[0] = 0.02;
   tradeReturns[1] = -0.01;
   tradeReturns[2] = 0.03;
   tradeReturns[3] = -0.005;

   analyzer.Evaluate(equityCurve, ArraySize(equityCurve), tradeReturns, ArraySize(tradeReturns), InpRiskFreeRate, stats);
   PrintFormat("Sharpe=%.2f MaxDD=%.2f WinRate=%.2f%% ProfitFactor=%.2f",
               stats.sharpeRatio, stats.maxDrawdown, stats.winRate, stats.profitFactor);
   analyzer.ExportHistory(BuildReportName("history", InpReportSuffix));

   Print("Optimization plan: ", BuildOptimizationPlanJson());
  }

bool SaveTesterConfig(const string filename)
  {
   const int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("Unable to open %s for writing. Error %d", filename, GetLastError());
      return false;
     }

   FileWriteString(handle, "[Tester]\n");
   FileWriteString(handle, StringFormat("Symbols=%s\n", InpSymbols));
   FileWriteString(handle, StringFormat("Start=%s\n", TimeToString(InpStartDate, TIME_DATE)));
   FileWriteString(handle, StringFormat("End=%s\n", TimeToString(InpEndDate, TIME_DATE)));
   FileWriteString(handle, StringFormat("Reports=%s\n", BuildReportName("report", InpReportSuffix)));
   FileWriteString(handle, StringFormat("Optimization=%s\n", BuildOptimizationPlanJson()));
   FileClose(handle);
   return true;
  }
