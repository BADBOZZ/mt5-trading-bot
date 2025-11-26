#property strict
#property script_show_inputs

#include "../src/backtesting/OptimizationParams.mqh"

// Script that configures the MT5 Strategy Tester to run multi-currency walk-
// forward optimizations using the same parameter ranges that the EA consumes.

input string             InpSymbolsUnderTest   = "EURUSD,GBPUSD,USDJPY";
input ENUM_TIMEFRAMES    InpTesterTimeframe    = PERIOD_H1;
input datetime           InpTesterStart        = D'2021.01.01';
input datetime           InpTesterEnd          = D'2024.12.31';
input double             InpTesterDeposit      = 100000;
input string             InpDepositCurrency    = "USD";
input ENUM_TESTER_MODEL  InpTesterModel        = TESTER_MODEL_EVERY_TICK_BASED_ON_REAL_TICKS;
input ENUM_TESTER_OPTIMIZATION InpOptimizationMethod = OPTIMIZATION_BISECTION;
input ENUM_TESTER_MODE   InpTesterMode         = TESTER_MODE_OPTIMIZATION;
input ENUM_TESTER_FORWARD InpForwardMode       = FORWARD_ORIGINAL;
input double             InpForwardPercent     = 30.0;
input bool               InpEnableWalkForward  = true;
input bool               InpGenerateReports    = true;

string ComposeConfigFile(const string suffix)
  {
   return "backtest_" + suffix;
  }

bool ExportSymbolUniverse(const string file_name)
  {
   SymbolTarget symbols[];
   ParseOptimizationSymbols(symbols);
   if(ArraySize(symbols)==0)
      return false;

   int flags = FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_COMMON;
   const int handle = FileOpen(file_name,flags);
   if(handle==INVALID_HANDLE)
      return false;

   FileWrite(handle,"symbol","timeframe","weight");
   for(int i=0; i<ArraySize(symbols); ++i)
     {
      const SymbolTarget &item = symbols[i];
      FileWrite(handle,
                item.symbol,
                EnumToString(item.timeframe),
                DoubleToString(item.weight,2));
     }

   FileClose(handle);
   return true;
  }

void ConfigureTester()
  {
   SelectOptimizationSymbols();

   TesterSetInteger(TESTER_MODE,InpTesterMode);
   TesterSetInteger(TESTER_MODEL,InpTesterModel);
   TesterSetInteger(TESTER_OPTIMIZATION,InpOptimizationMethod);
   TesterSetInteger(TESTER_OPTIMIZATION_CRITERION,OPTIMIZATION_CRITERION_CUSTOM_MAX);
   TesterSetInteger(TESTER_SPREAD,0);
   TesterSetDouble(TESTER_DEPOSIT,InpTesterDeposit);
   TesterSetString(TESTER_CURRENCY,InpDepositCurrency);
   TesterSetInteger(TESTER_FROM,(long)InpTesterStart);
   TesterSetInteger(TESTER_TO,(long)InpTesterEnd);
   TesterSetInteger(TESTER_FORWARD,InpForwardMode);
   TesterSetDouble(TESTER_FORWARD_VALUE,InpForwardPercent);

   string symbols[];
   const int total = StringSplit(InpSymbolsUnderTest,',',symbols);
   if(total>0)
      TesterSetString(TESTER_SYMBOL,TrimCopy(symbols[0]));
  }

void ExportReports()
  {
   if(!InpGenerateReports)
      return;

   ExportOptimizationManifest(ComposeConfigFile("optimization_params.csv"));
   ExportSymbolUniverse(ComposeConfigFile("symbols.csv"));

   if(InpEnableWalkForward)
      ExportWalkForwardPlan(ComposeConfigFile("walkforward.csv"));
  }

void OnStart()
  {
   ConfigureTester();
   ExportReports();
   PrintFormat("MT5 Strategy Tester configured for %s with custom optimization criteria.",InpSymbolsUnderTest);
  }
