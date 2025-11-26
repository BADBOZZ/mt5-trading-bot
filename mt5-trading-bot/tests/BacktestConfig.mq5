#property strict
#property script_show_inputs

#include "..\src\backtesting\OptimizationParams.mqh"

CPerformanceAnalyzer g_analyzer;
SParamRange          g_ranges[];
int                  g_range_count = 0;

struct SStrategyComparison
  {
   string label;
   double sharpe;
   double max_dd;
   double win_rate;
   double profit_factor;
   double recovery;
   double score;
  };

SStrategyComparison g_strategy_results[];

int OnInit()
  {
   BuildDefaultRanges(g_ranges, g_range_count);
   DescribeRangesToLog(g_ranges, g_range_count);
   g_analyzer.SetRiskFreeRate(InpRiskFreeRate);

   Print("=== Walk-forward slices preview ===");
   SWalkForwardSlice slice;
   for(int i = 0; i < 3; i++)
   {
      if(BuildWalkForwardSlice(TimeCurrent(), i, slice))
      {
         PrintFormat("Slice %d: IS(%s -> %s)  OS(%s -> %s)",
                     i,
                     TimeToString(slice.in_start, TIME_DATE),
                     TimeToString(slice.in_end, TIME_DATE),
                     TimeToString(slice.out_start, TIME_DATE),
                     TimeToString(slice.out_end, TIME_DATE));
      }
   }
   return INIT_SUCCEEDED;
  }

double OnTester()
  {
   string symbols[];
   ParseSymbolList(symbols);
   const int symbol_count = ArraySize(symbols);

   const datetime from = (datetime)TesterStatistics(STAT_TRADE_START);
   const datetime to   = (datetime)TesterStatistics(STAT_TRADE_END);
   bool analyzed = false;
   if(symbol_count > 0)
      analyzed = g_analyzer.AnalyzeMulti(from, to, symbols, symbol_count);

   if(!analyzed)
      analyzed = g_analyzer.Analyze(from, to);

   if(!analyzed)
      return 0.0;

   const string prefix = StringFormat("Tester\\Files\\%s_%d", _Symbol, (int)TesterStatistics(STAT_PASSES_TOTAL));
   g_analyzer.ExportHistory(prefix + "_history.csv");
   ExportEquityCurve(prefix + "_equity.csv");
   GenerateOptimizationReport(prefix + "_report.csv", g_analyzer);
   PushStrategyComparison(prefix);

   return EvaluateOptimizationTarget(g_analyzer, InpOptTarget);
  }

void OnTesterDeinit()
  {
   ExportComparisonReport();
  }

void PushStrategyComparison(const string label)
  {
   const int index = ArraySize(g_strategy_results);
   ArrayResize(g_strategy_results, index + 1);
   g_strategy_results[index].label         = label;
   g_strategy_results[index].sharpe        = g_analyzer.SharpeRatio();
   g_strategy_results[index].max_dd        = g_analyzer.MaxDrawdown();
   g_strategy_results[index].win_rate      = g_analyzer.WinRate();
   g_strategy_results[index].profit_factor = g_analyzer.ProfitFactor();
   g_strategy_results[index].recovery      = g_analyzer.RecoveryFactor();
   g_strategy_results[index].score         = g_analyzer.CompositeScore();
  }

void ExportComparisonReport()
  {
   const int total = ArraySize(g_strategy_results);
   if(total == 0)
      return;

   const string file_name = "Tester\\Files\\strategy_comparison.csv";
   const int handle = FileOpen(file_name, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("BacktestConfig: failed to create %s", file_name);
      return;
   }

   FileWrite(handle,
             "label",
             "sharpe",
             "max_drawdown",
             "win_rate",
             "profit_factor",
             "recovery_factor",
             "score");

   for(int i = 0; i < total; i++)
   {
      const SStrategyComparison snap = g_strategy_results[i];
      FileWrite(handle,
                snap.label,
                DoubleToString(snap.sharpe, 3),
                DoubleToString(snap.max_dd, 2),
                DoubleToString(snap.win_rate * 100.0, 2),
                DoubleToString(snap.profit_factor, 2),
                DoubleToString(snap.recovery, 2),
                DoubleToString(snap.score, 4));
   }

   FileClose(handle);
   PrintFormat("BacktestConfig: wrote comparison for %d passes.", total);
  }

void ExportEquityCurve(const string file_name)
  {
   double equity[];
   datetime timestamps[];
   if(!g_analyzer.BuildEquitySeries(equity, timestamps))
      return;

   const int total = ArraySize(equity);
   const int handle = FileOpen(file_name, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("BacktestConfig: failed to create %s", file_name);
      return;
   }

   FileWrite(handle, "time", "equity");
   for(int i = 0; i < total; i++)
   {
      FileWrite(handle,
                TimeToString(timestamps[i], TIME_DATE|TIME_SECONDS),
                DoubleToString(equity[i], 2));
   }
   FileClose(handle);
  }
