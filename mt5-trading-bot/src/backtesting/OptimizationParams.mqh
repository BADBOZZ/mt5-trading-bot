#pragma once
#property strict

/**
 *  OptimizationParams.mqh
 *
 *  Defines reusable Strategy Tester ranges, walk-forward slices,
 *  multi-currency helpers, and custom optimization criteria used by the
 *  MT5 trading bot. Include this header from Expert Advisors or a
 *  dedicated test harness to make sure every backtest uses the same
 *  reproducible configuration.
 */

#include "PerformanceAnalyzer.mq5"

enum ENUM_OPTIMIZATION_TARGET
  {
   OPT_TARGET_BALANCED = 0,
   OPT_TARGET_SHARPE   = 1,
   OPT_TARGET_DRAWDOWN = 2,
   OPT_TARGET_PROFIT   = 3
  };

struct SParamRange
  {
   string name;
   double start;
   double stop;
   double step;
  };

struct SWalkForwardSlice
  {
   datetime in_start;
   datetime in_end;
   datetime out_start;
   datetime out_end;
  };

struct STesterReport
  {
   double sharpe;
   double max_drawdown;
   double win_rate;
   double profit_factor;
   double recovery_factor;
   double composite;
  };

input string         InpOptimizationSymbols = "EURUSD,GBPUSD,USDJPY,XAUUSD";
input ENUM_TIMEFRAMES InpOptimizationTF     = PERIOD_H1;
input int            InpWalkForwardIS       = 90;   // days
input int            InpWalkForwardOS       = 30;   // days
input ENUM_OPTIMIZATION_TARGET InpOptTarget = OPT_TARGET_BALANCED;
input double         InpRiskFreeRate        = 0.02 / 252.0; // daily assumption

//--- helpers -----------------------------------------------------------------

static void AddRange(SParamRange &ranges[],
                     int &count,
                     const string name,
                     const double start,
                     const double stop,
                     const double step)
  {
   ArrayResize(ranges, count + 1);
   ranges[count].name  = name;
   ranges[count].start = start;
   ranges[count].stop  = stop;
   ranges[count].step  = step;
   count++;
  }

void BuildDefaultRanges(SParamRange &ranges[], int &count)
  {
   count = 0;
   AddRange(ranges, count, "InpLots",     0.05,  1.00, 0.05);
   AddRange(ranges, count, "InpRiskPct",  0.25,  3.00, 0.25);
   AddRange(ranges, count, "InpStopLoss", 150,   600,  25);
   AddRange(ranges, count, "InpTakeProfit",200,  1200, 25);
   AddRange(ranges, count, "InpTrail",     50,   400,  25);
   AddRange(ranges, count, "InpATRPeriod", 7,    28,   1);
   AddRange(ranges, count, "InpSessionFilter", 0, 1,   1);
  }

void DescribeRangesToLog(const SParamRange &ranges[], const int count)
  {
   for(int i = 0; i < count; i++)
   {
      const SParamRange range = ranges[i];
      PrintFormat("Range -> %s: %.4f ... %.4f step %.4f",
                  range.name, range.start, range.stop, range.step);
   }
  }

void ParseSymbolList(string &symbols[])
  {
   const int parts = StringSplit(InpOptimizationSymbols, ',', symbols);
   for(int i = 0; i < parts; i++)
   {
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);
      symbols[i] = StringToUpper(symbols[i]);
   }
  }

bool BuildWalkForwardSlice(const datetime start_date,
                           const int iteration,
                           SWalkForwardSlice &slice)
  {
   const int in_days  = MathMax(5, InpWalkForwardIS);
   const int out_days = MathMax(1, InpWalkForwardOS);
   const int shift    = iteration * out_days;

   slice.in_start  = start_date + shift * 86400;
   slice.in_end    = slice.in_start + in_days * 86400;
   slice.out_start = slice.in_end;
   slice.out_end   = slice.out_start + out_days * 86400;
   return (slice.out_end > slice.out_start);
  }

double EvaluateOptimizationTarget(const CPerformanceAnalyzer &analyzer,
                                  const ENUM_OPTIMIZATION_TARGET target)
  {
   switch(target)
   {
      case OPT_TARGET_SHARPE:
         return analyzer.SharpeRatio();
      case OPT_TARGET_DRAWDOWN:
         return -analyzer.MaxDrawdown();
      case OPT_TARGET_PROFIT:
         return analyzer.ProfitFactor();
      default:
         return analyzer.CompositeScore();
   }
  }

STesterReport BuildTesterReport(const CPerformanceAnalyzer &analyzer)
  {
   STesterReport report;
   report.sharpe          = analyzer.SharpeRatio();
   report.max_drawdown    = analyzer.MaxDrawdown();
   report.win_rate        = analyzer.WinRate();
   report.profit_factor   = analyzer.ProfitFactor();
   report.recovery_factor = analyzer.RecoveryFactor();
   report.composite       = analyzer.CompositeScore();
   return report;
  }

bool GenerateOptimizationReport(const string file_name,
                                const CPerformanceAnalyzer &analyzer)
  {
   const STesterReport report = BuildTesterReport(analyzer);
   const int file_handle = FileOpen(file_name, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
   if(file_handle == INVALID_HANDLE)
   {
      PrintFormat("OptimizationParams: failed to create %s", file_name);
      return false;
   }

   FileWrite(file_handle,
             "sharpe",
             "max_drawdown",
             "win_rate",
             "profit_factor",
             "recovery_factor",
             "composite");

   FileWrite(file_handle,
             DoubleToString(report.sharpe, 3),
             DoubleToString(report.max_drawdown, 2),
             DoubleToString(report.win_rate * 100.0, 2),
             DoubleToString(report.profit_factor, 2),
             DoubleToString(report.recovery_factor, 2),
             DoubleToString(report.composite, 4));

   FileClose(file_handle);
   PrintFormat("OptimizationParams: wrote optimization report to %s", file_name);
   return true;
  }
