#property strict
#property script_show_inputs

#include "..\\src\\backtesting\\PerformanceAnalyzer.mq5"
#include "..\\src\\backtesting\\OptimizationParams.mqh"

PerformanceAnalyzer      g_analyzer;
OptimizationParamRange   g_ranges[];
WalkForwardSlice         g_slices[];
OptimizationSnapshot     g_snapshot;
string                   g_symbols[];

// Forward declarations
void PrepareStrategyTesterArtifacts();
void RunWalkForwardReport();
void RefreshSnapshot();

int OnInit()
  {
   PrepareStrategyTesterArtifacts();
   return(INIT_SUCCEEDED);
  }

void OnTesterInit()
  {
   PrepareStrategyTesterArtifacts();
   g_analyzer.Reset(0.0,"StrategyTester");
   if(ArraySize(g_symbols)==0)
      ParseSymbols(InpSymbols,g_symbols);
   g_analyzer.UseSymbols(g_symbols);
  }

double OnTester()
  {
   datetime wf_end=(InpWFEnd==0 ? TimeCurrent() : InpWFEnd);
   g_analyzer.ProcessHistory(InpWFStart,wf_end);

   RefreshSnapshot();
   SaveOptimizationReport(g_snapshot,InpOptimizationGoal,"MetaTrader5EA","tester_optimization_report.csv");
   g_analyzer.ExportTradeHistory("tester_trade_history.csv");
   g_analyzer.ExportEquityCurve("tester_equity_curve.csv");
   g_analyzer.ExportSummary("tester_summary.csv");
   g_analyzer.AppendStrategyComparison("MetaTrader5EA","tester_strategy_comparison.csv");

   if(InpEnableWalkForward)
      RunWalkForwardReport();

   return EvaluateCriterion(g_snapshot,InpOptimizationGoal);
  }

void OnTesterPass()
  {
   PrintFormat("Tester pass finished: sharpe=%.3f win=%.2f%% pf=%.2f recovery=%.2f",
               g_snapshot.sharpe,
               g_snapshot.win_rate,
               g_snapshot.profit_factor,
               g_snapshot.recovery);
  }

void PrepareStrategyTesterArtifacts()
  {
   // Parameter ranges for optimization
   BuildDefaultRanges(g_ranges);
   SerializeRangesToCsv(g_ranges,"tester_parameter_ranges.csv");

   // Multi-currency universe
   ParseSymbols(InpSymbols,g_symbols);

   // Walk-forward schedule
   if(InpEnableWalkForward)
     {
      datetime wf_end=(InpWFEnd==0 ? TimeCurrent() : InpWFEnd);
      int wf_windows=BuildWalkForwardSlices(InpWFStart,wf_end,InpWFTrainMonths,InpWFTestMonths,g_slices);
      if(wf_windows>0)
         ExportWalkForwardPlan(g_slices,"tester_walkforward_windows.csv");
     }
  }

void RefreshSnapshot()
  {
   g_snapshot.trades=g_analyzer.TradeCount();
   g_snapshot.net_profit=g_analyzer.NetProfit();
   g_snapshot.sharpe=g_analyzer.SharpeRatio();
   g_snapshot.recovery=g_analyzer.RecoveryFactor();
   g_snapshot.profit_factor=g_analyzer.ProfitFactor();
   g_snapshot.win_rate=g_analyzer.WinRate();
   g_snapshot.max_drawdown_pct=g_analyzer.MaxDrawdownPct();
   g_snapshot.expectancy=(g_snapshot.trades>0 ? g_snapshot.net_profit/(double)g_snapshot.trades : 0.0);
  }

void RunWalkForwardReport()
  {
   if(ArraySize(g_slices)==0)
      return;

   int handle=FileOpen("tester_walkforward_results.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_WRITE);
   if(handle==INVALID_HANDLE)
     {
      Print("BacktestConfig: unable to export walk-forward metrics");
      return;
     }

   FileWrite(handle,"window","train_from","train_to","test_from","test_to","sharpe","profit_factor","win_rate","max_drawdown_pct","net_profit","recovery_factor");

   for(int i=0;i<ArraySize(g_slices);++i)
     {
      string prefix=StringFormat("WF_%02d",i+1);
      g_analyzer.Reset(0.0,prefix);
      g_analyzer.UseSymbols(g_symbols);
      g_analyzer.ProcessHistory(g_slices[i].test_from,g_slices[i].test_to);

      double sharpe=g_analyzer.SharpeRatio();
      double pf=g_analyzer.ProfitFactor();
      double win=g_analyzer.WinRate();
      double dd=g_analyzer.MaxDrawdownPct();
      double net=g_analyzer.NetProfit();
      double recovery=g_analyzer.RecoveryFactor();

      FileWrite(handle,
                prefix,
                TimeToString(g_slices[i].train_from),
                TimeToString(g_slices[i].train_to),
                TimeToString(g_slices[i].test_from),
                TimeToString(g_slices[i].test_to),
                sharpe,
                pf,
                win,
                dd,
                net,
                recovery);

      g_analyzer.AppendStrategyComparison(prefix,"tester_strategy_comparison.csv");
      g_analyzer.ExportEquityCurve(StringFormat("%s_equity_curve.csv",prefix));
     }

   FileClose(handle);
  }
