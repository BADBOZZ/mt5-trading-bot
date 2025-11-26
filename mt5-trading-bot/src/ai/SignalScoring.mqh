#pragma once

#include "PatternRecognition.mqh"

struct SignalContext
  {
   ENUM_MARKET_REGIME regime;
   double             atr;
   double             spread;
   double             volatility;
   double             liquidityScore;
   double             historicalWinRate;
   double             payoffRatio;
   double             drawdownRatio;
   double             sampleSize;
  };

class CSignalScoringEngine
  {
private:
   double m_minConfidence;
   double m_maxRisk;
   double m_recentSharpe;

   double Weight(double value,double weight) const
     {
      return MathMax(0.0,MathMin(1.0,value)) * weight;
     }

public:
                     CSignalScoringEngine():
                     m_minConfidence(0.35),
                     m_maxRisk(2.0),
                     m_recentSharpe(1.5)
                     {}

   void              Configure(double minConfidence,double maxRisk,double recentSharpe)
     {
      m_minConfidence = MathMax(0.05,minConfidence);
      m_maxRisk       = MathMax(0.5,maxRisk);
      m_recentSharpe  = MathMax(0.1,recentSharpe);
     }

   double            ScorePattern(const PatternSignal &pattern,const SignalContext &context) const
     {
      double base = pattern.confidence;
      double regimeBias = 0.0;

      switch(context.regime)
        {
         case REGIME_TRENDING:
            regimeBias = pattern.pattern == PATTERN_TREND_ACCELERATION ? 0.15 : -0.05;
            break;
         case REGIME_RANGING:
            regimeBias = pattern.pattern == PATTERN_MEAN_REVERSION ? 0.12 : -0.08;
            break;
         case REGIME_BREAKOUT:
            regimeBias = pattern.pattern == PATTERN_BREAKOUT ? 0.18 : -0.02;
            break;
         case REGIME_VOLATILE:
            regimeBias = (pattern.pattern == PATTERN_VOLATILITY_COMPRESSION) ? 0.1 : -0.1;
            break;
         default:
            regimeBias = 0.0;
        }

      double regimeScore = MathMax(0.0,MathMin(1.0,base + regimeBias));

      double riskPenalty = 0.0;
      if(context.atr > 0.0 && context.spread > 0.0)
        {
         double costRatio = context.spread / context.atr;
         riskPenalty = MathMin(0.25,costRatio);
        }

      double liquidityBonus = Weight(context.liquidityScore,0.15);
      double winRateBonus   = Weight(context.historicalWinRate,0.25);
      double payoffBonus    = Weight(MathMin(context.payoffRatio / 2.0,1.0),0.2);
      double drawdownPenalty = Weight(MathMin(context.drawdownRatio / m_maxRisk,1.0),0.2);

      double adaptiveSharpe = MathMin(m_recentSharpe / 3.0,1.0);

      double score = regimeScore
                     + liquidityBonus
                     + winRateBonus
                     + payoffBonus
                     + adaptiveSharpe * 0.1
                     - riskPenalty
                     - drawdownPenalty;

      return MathMax(0.0,MathMin(1.0,score));
     }

   double            ScoreHistoricalPerformance(const double &pnlSeries[],int trades,double decay) const
     {
      if(trades <= 0)
         return 0.5;

      double weighted = 0.0;
      double weightSum = 0.0;
      double currentDecay = 1.0;
      for(int i = 0; i < trades; ++i)
        {
         weighted += pnlSeries[i] * currentDecay;
         weightSum += currentDecay;
         currentDecay *= decay;
         if(currentDecay < 0.01)
            currentDecay = 0.01;
        }

      if(weightSum == 0.0)
         return 0.5;

      double avg = weighted / weightSum;
      return MathMax(0.0,MathMin(1.0,0.5 + avg));
     }

   bool              ShouldTrade(const PatternSignal &pattern,const SignalContext &context,double &finalScore) const
     {
      finalScore = ScorePattern(pattern,context);
      return finalScore >= m_minConfidence;
     }
  };

