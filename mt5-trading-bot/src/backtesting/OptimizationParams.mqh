//+------------------------------------------------------------------+
//| OptimizationParams.mqh                                           |
//| Shared EA parameter declarations and Strategy Tester ranges.      |
//+------------------------------------------------------------------+
#pragma once

input double InpRiskPerTrade      = 1.0;   // % risk per trade
input int    InpSignalLookback    = 50;    // bars for signal model
input double InpStopATRMultiplier = 2.0;   // ATR based stop multiplier
input double InpTakeATRMultiplier = 3.5;   // ATR based take multiplier
input int    InpMagic             = 555;   // magic number for EA positions
input bool   InpUseTrailingStop   = true;  // enable trailing stop logic
input double InpTrailingATR       = 1.5;   // trailing ATR multiplier
input double InpMaxSpreadPoints   = 25;    // spread filter in points

struct OptimizationRange
  {
   string name;
   double start;
   double stop;
   double step;
   bool   as_integer;
  };

// Default ranges tuned for MT5 Strategy Tester grid search
const OptimizationRange OPTIMIZATION_TABLE[]=
  {
   {"InpRiskPerTrade",      0.25, 2.0, 0.25,  false},
   {"InpSignalLookback",    20,   120, 20,    true },
   {"InpStopATRMultiplier", 1.0,  4.0, 0.5,   false},
   {"InpTakeATRMultiplier", 2.0,  6.0, 0.5,   false},
   {"InpTrailingATR",       1.0,  3.5, 0.5,   false},
   {"InpMaxSpreadPoints",   10,   50,  5,     true }
  };

// Helper to print the configured ranges inside the Strategy Tester log
void LogOptimizationRanges()
  {
   for(int i=0;i<ArraySize(OPTIMIZATION_TABLE);i++)
     {
      const OptimizationRange range=OPTIMIZATION_TABLE[i];
      PrintFormat("[OPT] %s: start=%.2f stop=%.2f step=%.2f integer=%s",
                  range.name,range.start,range.stop,range.step,range.as_integer?"true":"false");
     }
  }

// Compile-time validation helper to ensure steps are positive
#define ENSURE_POSITIVE_STEP(NAME, STEP) static_assert((STEP)>0,"Optimization step must be > 0 for "#NAME)

ENSURE_POSITIVE_STEP(InpRiskPerTrade,0.25);
ENSURE_POSITIVE_STEP(InpSignalLookback,20);
ENSURE_POSITIVE_STEP(InpStopATRMultiplier,0.5);
ENSURE_POSITIVE_STEP(InpTakeATRMultiplier,0.5);
ENSURE_POSITIVE_STEP(InpTrailingATR,0.5);
ENSURE_POSITIVE_STEP(InpMaxSpreadPoints,5);
