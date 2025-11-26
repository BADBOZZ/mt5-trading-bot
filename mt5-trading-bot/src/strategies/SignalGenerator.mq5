#property strict
#property script_show_inputs

#include "..\config\strategy-config.mqh"
#include "BaseStrategy.mqh"
#include "TrendFollowingStrategy.mq5"
#include "MeanReversionStrategy.mq5"
#include "BreakoutStrategy.mq5"

input string InpTrendSymbols      = "";
input string InpTrendTimeframes   = "";
input string InpMeanSymbols       = "";
input string InpMeanTimeframes    = "";
input string InpBreakoutSymbols   = "";
input string InpBreakoutTimeframes= "";
input double InpTrendWeight       = 0.4;
input double InpMeanWeight        = 0.35;
input double InpBreakoutWeight    = 0.25;
input double InpConflictThreshold = 0.15;
input bool   InpLogSignals        = true;

TrendFollowingStrategy   g_trendStrategy;
MeanReversionStrategy    g_meanStrategy;
BreakoutStrategy         g_breakoutStrategy;
StrategyWeightConfig     g_weightConfig;

int OnInit()
{
   LoadStrategyWeights(g_weightConfig,
                       InpTrendWeight,
                       InpMeanWeight,
                       InpBreakoutWeight,
                       InpConflictThreshold);

   TrendStrategyConfig trendCfg;
   LoadTrendStrategyConfig(trendCfg, InpTrendSymbols, InpTrendTimeframes);
   g_trendStrategy.Configure(trendCfg);

   MeanReversionStrategyConfig meanCfg;
   LoadMeanReversionConfig(meanCfg, InpMeanSymbols, InpMeanTimeframes);
   g_meanStrategy.Configure(meanCfg);

   BreakoutStrategyConfig breakoutCfg;
   LoadBreakoutStrategyConfig(breakoutCfg, InpBreakoutSymbols, InpBreakoutTimeframes);
   g_breakoutStrategy.Configure(breakoutCfg);

   Comment("Signal generator initialized.");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   double buyScore  = 0.0;
   double sellScore = 0.0;

   ProcessStrategy(g_trendStrategy,   g_weightConfig.trendWeight,         buyScore, sellScore);
   ProcessStrategy(g_meanStrategy,    g_weightConfig.meanReversionWeight, buyScore, sellScore);
   ProcessStrategy(g_breakoutStrategy,g_weightConfig.breakoutWeight,      buyScore, sellScore);

   ApplyDecision(buyScore, sellScore);
}

void OnDeinit(const int reason)
{
   Comment("Signal generator stopped.");
}

void ProcessStrategy(BaseStrategy &strategy,
                     const double weight,
                     double &buyScore,
                     double &sellScore)
{
   string symbols[];
   ENUM_TIMEFRAMES timeframes[];
   int symbolCount = strategy.GetSymbols(symbols);
   int tfCount     = strategy.GetTimeframes(timeframes);

   double bestBuyNormalized  = 0.0;
   double bestSellNormalized = 0.0;
   StrategySignalResult bestBuySignal;
   StrategySignalResult bestSellSignal;
   bool hasBuy = false;
   bool hasSell = false;

   for(int i=0; i<symbolCount; i++)
   {
      for(int j=0; j<tfCount; j++)
      {
         StrategySignalResult signal = strategy.GenerateSignal(symbols[i], timeframes[j]);
         double normalized = signal.confidence / 100.0;
         if(signal.signal == STRATEGY_SIGNAL_BUY && normalized > bestBuyNormalized)
         {
            bestBuyNormalized = normalized;
            bestBuySignal     = signal;
            hasBuy            = true;
         }
         else if(signal.signal == STRATEGY_SIGNAL_SELL && normalized > bestSellNormalized)
         {
            bestSellNormalized = normalized;
            bestSellSignal     = signal;
            hasSell            = true;
         }
      }
   }

   buyScore  += bestBuyNormalized  * weight;
   sellScore += bestSellNormalized * weight;

   if(InpLogSignals)
   {
      if(hasBuy)
      {
         PrintFormat("Strategy %s BUY %s %s %.1f%%",
                     strategy.Name(),
                     bestBuySignal.symbol,
                     EnumToString(bestBuySignal.timeframe),
                     bestBuySignal.confidence);
      }
      if(hasSell)
      {
         PrintFormat("Strategy %s SELL %s %s %.1f%%",
                     strategy.Name(),
                     bestSellSignal.symbol,
                     EnumToString(bestSellSignal.timeframe),
                     bestSellSignal.confidence);
      }
   }
}

void ApplyDecision(const double buyScore, const double sellScore)
{
   double diff = buyScore - sellScore;
   double total = buyScore + sellScore;

   if(total == 0.0)
   {
      Comment("Signal: HOLD | Reason: No active signals");
      return;
   }

   if(MathAbs(diff) <= g_weightConfig.conflictThreshold)
   {
      Comment(StringFormat("Signal: HOLD | Buy %.2f Sell %.2f | Conflict filter %.2f",
                           buyScore,
                           sellScore,
                           g_weightConfig.conflictThreshold));
      return;
   }

   if(diff > 0.0)
   {
      double confidence = MathMin(100.0, (buyScore / total) * 100.0);
      Comment(StringFormat("Signal: BUY | Score %.2f vs %.2f | Confidence %.1f%%",
                           buyScore,
                           sellScore,
                           confidence));
   }
   else
   {
      double confidence = MathMin(100.0, (sellScore / total) * 100.0);
      Comment(StringFormat("Signal: SELL | Score %.2f vs %.2f | Confidence %.1f%%",
                           buyScore,
                           sellScore,
                           confidence));
   }
}
