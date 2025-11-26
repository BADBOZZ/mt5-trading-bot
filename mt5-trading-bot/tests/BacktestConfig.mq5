#property strict

#include "..\src\backtesting\OptimizationParams.mqh"
#include "..\src\backtesting\PerformanceAnalyzer.mq5"

CPerformanceAnalyzer g_analyzer;

int OnInit()
  {
   g_analyzer.SetRiskFreeRate(0.02);
   return(INIT_SUCCEEDED);
  }

void OnTesterInit()
  {
   g_analyzer.Reset();
  }

double OnTester()
  {
   g_analyzer.ProcessTesterHistory();
   if(!AllowCandidate())
      return -1.0;
   return CalculateOptimizationScore();
  }
