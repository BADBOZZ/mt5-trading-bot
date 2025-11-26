#pragma once
#property strict

enum ENUM_SIGNAL_MODE
  {
   SIGNAL_TREND = 0,
   SIGNAL_MEAN_REVERSION = 1,
   SIGNAL_BREAKOUT = 2
  };

input group "Risk Management"
input double   RiskPerTrade     = 1.0;   // % balance risked per trade
input double   MaxAccountRisk   = 6.0;   // % of balance simultaneously at risk
input double   StopLossPoints   = 400;   // dynamic stop
input double   TakeProfitPoints = 400;   // dynamic target

input group "Signal & Execution"
input ENUM_SIGNAL_MODE SignalMode = SIGNAL_TREND;
input int              SlowMAPeriod = 50;
input int              FastMAPeriod = 14;
input double           VolatilityMultiplier = 1.5;
input int              TrailingStep = 15;

input group "Tester"
input bool             EnableWalkForward = true;
input bool             ExportTradeHistory = true;

struct OptimizationBand
  {
   string name;
   double start;
   double stop;
   double step;
  };

// These bands mirror the Python ParameterSpace defaults.
const OptimizationBand OPT_BANDS[] =
  {
   {"RiskPerTrade",0.5,2.0,0.5},
   {"StopLossPoints",200,600,50},
   {"TakeProfitPoints",200,600,50},
   {"TrailingStep",10,30,5},
   {"VolatilityMultiplier",1.0,2.0,0.25}
  };

string DescribeBand(const OptimizationBand &band)
  {
   return StringFormat("%s: %.2f -> %.2f step %.2f",band.name,band.start,band.stop,band.step);
  }

void PrintOptimizationBands()
  {
   for(int i=0;i<ArraySize(OPT_BANDS);++i)
      Print(DescribeBand(OPT_BANDS[i]));
  }
