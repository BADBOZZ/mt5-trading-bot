#pragma once

#property strict

struct OptimizationRange
  {
   string name;
   double start;
   double step;
   double stop;
  };

enum ENUM_OptimizationCriterion
  {
   OptimizationCriterion_BalanceMax = 0,
   OptimizationCriterion_RecoveryFactor,
   OptimizationCriterion_Custom
  };

input double InpRiskPercent     = 1.0;
input double InpStopLossPoints  = 200;
input double InpTakeProfitPoints= 400;
input int    InpMagic           = 1001;

const OptimizationRange OPTIMIZATION_RANGES[] =
  {
   {"InpRiskPercent",      0.25, 0.25, 3.0},
   {"InpStopLossPoints",   100.0, 25.0, 500.0},
   {"InpTakeProfitPoints", 100.0, 25.0, 700.0}
  };

string BuildOptimizationPlanJson(const ENUM_OptimizationCriterion criterion = OptimizationCriterion_BalanceMax)
  {
   string json = "{\"ranges\":[";
   for(int i = 0; i < ArraySize(OPTIMIZATION_RANGES); ++i)
     {
      const OptimizationRange range = OPTIMIZATION_RANGES[i];
      json += StringFormat("{\"name\":\"%s\",\"start\":%G,\"step\":%G,\"stop\":%G}",
                           range.name, range.start, range.step, range.stop);
      if(i < ArraySize(OPTIMIZATION_RANGES) - 1)
         json += ",";
     }
   json += "]";
   json += StringFormat(",\"criterion\":\"%s\"}", EnumToString(criterion));
   return json;
  }

string BuildReportName(const string symbol, const string suffix)
  {
   string stamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   StringReplace(stamp, ":", "");
   StringReplace(stamp, ".", "");
   StringReplace(stamp, " ", "_");
   return StringFormat("%s_%s_%s.htm", symbol, suffix, stamp);
  }
