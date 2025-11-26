#property strict

input double InpRiskPerTrade      = 1.0;
input int    InpStopLossPoints    = 350;
input int    InpTakeProfitPoints  = 700;
input double InpTrailingStopPoints= 200.0;
input int    InpLookbackPeriod    = 200;
input double InpMinSharpe         = 0.8;
input double InpMaxDrawdownPct    = 10.0;

struct SOptimizationRange
  {
   string name;
   double start;
   double step;
   double stop;
   bool   integer;
  };

const SOptimizationRange OPTIMIZATION_RANGES[] =
  {
     {"InpRiskPerTrade",       0.25, 0.25, 2.0,   false},
     {"InpStopLossPoints",     150.0, 25.0, 700.0, true},
     {"InpTakeProfitPoints",   300.0, 25.0, 900.0, true},
     {"InpTrailingStopPoints", 100.0, 25.0, 400.0, false},
     {"InpLookbackPeriod",     100.0, 20.0, 400.0, true},
     {"InpMinSharpe",          0.50,  0.10, 1.50, false},
     {"InpMaxDrawdownPct",     5.0,   0.5,  15.0, false}
  };

enum ENUM_OPTIMIZATION_CRITERIA
  {
   OPT_CRITERIA_EXPECTANCY = 0,
   OPT_CRITERIA_RECOVERY   = 1,
   OPT_CRITERIA_CUSTOM     = 2
  };

input ENUM_OPTIMIZATION_CRITERIA InpOptimizationCriterion = OPT_CRITERIA_CUSTOM;

double CalculateOptimizationScore(void)
  {
   double net_profit   = TesterStatistics(STAT_PROFIT);
   double max_drawdown = TesterStatistics(STAT_EQUITY_DD);
   double sharpe       = TesterStatistics(STAT_SHARPE_RATIO);
   double profit_factor= TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery     = (max_drawdown == 0.0) ? 0.0 : net_profit / max_drawdown;

   switch(InpOptimizationCriterion)
     {
      case OPT_CRITERIA_EXPECTANCY:
         return TesterStatistics(STAT_EXPECTED_PAYOFF);
      case OPT_CRITERIA_RECOVERY:
         return recovery;
      default:
         double drawdown_penalty = max_drawdown * 0.1;
         return (profit_factor * 50.0) + (sharpe * 100.0) + (recovery * 25.0) - drawdown_penalty;
     }
  }

bool AllowCandidate(void)
  {
   double drawdown_pct = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double sharpe       = TesterStatistics(STAT_SHARPE_RATIO);
   return (drawdown_pct <= InpMaxDrawdownPct) && (sharpe >= InpMinSharpe);
  }
