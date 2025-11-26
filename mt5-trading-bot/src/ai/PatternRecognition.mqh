#property copyright "MT5 Trading Bot"
#property link      "https://example.com"
#property version   "1.0"
#property strict

#pragma once

#include <Math\Algebra.mqh>
#include <Math\Stat\Math.mqh>

enum ENUM_MARKET_PATTERN
  {
   PATTERN_NONE = 0,
   PATTERN_TREND_ACCELERATION,
   PATTERN_MEAN_REVERSION,
   PATTERN_BREAKOUT,
   PATTERN_VOLATILITY_COMPRESSION,
   PATTERN_VOLUME_SURGE,
   PATTERN_CYCLE_ROTATION
  };

enum ENUM_MARKET_REGIME
  {
   REGIME_UNKNOWN = 0,
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_BREAKOUT,
   REGIME_VOLATILE
  };

struct PatternSignal
  {
   ENUM_MARKET_PATTERN pattern;
   ENUM_MARKET_REGIME  regime;
   bool                bullish;
   double              confidence;
   double              velocity;
   double              volatility;
   string              description;
   datetime            timestamp;
  };

//--- Utility helpers --------------------------------------------------------
double _Normalize(double value,double min,double max)
  {
   if(max - min <= 0.0)
      return 0.0;
   double normalized = (value - min) / (max - min);
   return MathMax(0.0,MathMin(1.0,normalized));
  }

double _SeriesStdDev(const double &series[],int count)
  {
   if(count <= 1)
      return 0.0;

   double sum = 0.0;
   double sum2 = 0.0;
   for(int i = 0; i < count; ++i)
     {
      double val = series[i];
      sum += val;
      sum2 += val * val;
     }

   double mean = sum / count;
   double variance = (sum2 - count * mean * mean) / (count - 1);
   return MathSqrt(MathMax(variance,0.0));
  }

double _SeriesSlope(const double &series[],int count)
  {
   if(count < 2)
      return 0.0;

   double sumX = 0.0;
   double sumY = 0.0;
   double sumXY = 0.0;
   double sumXX = 0.0;

   for(int i = 0; i < count; ++i)
     {
      double x = i;
      double y = series[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
     }

   double denom = (count * sumXX - sumX * sumX);
   if(denom == 0.0)
      return 0.0;

   return (count * sumXY - sumX * sumY) / denom;
  }

double _SeriesRSquared(const double &series[],int count)
  {
   if(count < 3)
      return 0.0;

   double slope = _SeriesSlope(series,count);
   double sumY = 0.0;
   for(int i = 0; i < count; ++i)
      sumY += series[i];

   double mean = sumY / count;
   double ssTot = 0.0;
   double ssRes = 0.0;
   for(int i = 0; i < count; ++i)
     {
      double y = series[i];
      double x = i;
      double yHat = slope * x + (mean - slope * (count - 1) / 2.0);
      ssTot += MathPow(y - mean,2.0);
      ssRes += MathPow(y - yHat,2.0);
     }

   if(ssTot <= 0.0)
      return 0.0;

   return 1.0 - (ssRes / ssTot);
  }

double _TrueRange(const double high,const double low,const double prevClose)
  {
   double tr1 = high - low;
   double tr2 = MathAbs(high - prevClose);
   double tr3 = MathAbs(low - prevClose);
   return MathMax(tr1,MathMax(tr2,tr3));
  }

double _ATR(const double &high[],const double &low[],const double &close[],int period)
  {
   if(period <= 1)
      return 0.0;

   double atr = 0.0;
   for(int i = 1; i <= period; ++i)
     {
      double tr = _TrueRange(high[i],low[i],close[i-1]);
      atr += tr;
     }
   return atr / period;
  }

//--- Pattern detection ------------------------------------------------------
bool DetectTrendSignal(const double &close[],int lookback,PatternSignal &signal)
  {
   if(lookback < 10)
      return false;

   double slope = _SeriesSlope(close,lookback);
   double r2    = _SeriesRSquared(close,lookback);
   double std   = _SeriesStdDev(close,lookback);

   if(MathAbs(slope) < std * 0.01 || r2 < 0.35)
      return false;

   signal.pattern     = PATTERN_TREND_ACCELERATION;
   signal.regime      = REGIME_TRENDING;
   signal.bullish     = slope > 0.0;
   signal.velocity    = slope;
   signal.volatility  = std;
   signal.confidence  = _Normalize(MathAbs(slope) * r2,0.0,std * 0.05);
   signal.description = signal.bullish ? "Accelerating bullish trend" : "Accelerating bearish trend";
   signal.timestamp   = TimeCurrent();
   return true;
  }

bool DetectMeanReversion(const double &close[],int fastLen,int slowLen,PatternSignal &signal)
  {
   if(fastLen <= 1 || slowLen <= fastLen)
      return false;

   double fastSum = 0.0;
   double slowSum = 0.0;
   for(int i = 0; i < fastLen; ++i)
      fastSum += close[i];
   for(int j = 0; j < slowLen; ++j)
      slowSum += close[j];

   double fastMA = fastSum / fastLen;
   double slowMA = slowSum / slowLen;
   double distance = fastMA - slowMA;
   double std = _SeriesStdDev(close,slowLen);

   if(std == 0.0)
      return false;

   double zScore = distance / std;
   if(MathAbs(zScore) < 1.0)
      return false;

   signal.pattern     = PATTERN_MEAN_REVERSION;
   signal.regime      = REGIME_RANGING;
   signal.bullish     = zScore < 0.0;
   signal.velocity    = -zScore;
   signal.volatility  = std;
   signal.confidence  = _Normalize(MathAbs(zScore),0.0,3.0);
   signal.description = signal.bullish ? "Mean reversion long setup" : "Mean reversion short setup";
   signal.timestamp   = TimeCurrent();
   return true;
  }

bool DetectBreakout(const double &high[],const double &low[],const double &close[],int period,double atrMult,PatternSignal &signal)
  {
   if(period < 5)
      return false;

   int idxHigh = ArrayMaximum(high,1,period);
   int idxLow  = ArrayMinimum(low,1,period);
   double highest = high[idxHigh];
   double lowest  = low[idxLow];
   double atr     = _ATR(high,low,close,MathMin(period,14));
   double lastClose = close[0];

   if(lastClose > highest + atrMult * atr)
     {
      signal.pattern     = PATTERN_BREAKOUT;
      signal.regime      = REGIME_BREAKOUT;
      signal.bullish     = true;
      signal.velocity    = (lastClose - highest) / atr;
      signal.volatility  = atr;
      signal.confidence  = _Normalize(signal.velocity,0.0,3.0);
      signal.description = "Bullish breakout beyond resistance";
      signal.timestamp   = TimeCurrent();
      return true;
     }

   if(lastClose < lowest - atrMult * atr)
     {
      signal.pattern     = PATTERN_BREAKOUT;
      signal.regime      = REGIME_BREAKOUT;
      signal.bullish     = false;
      signal.velocity    = (lowest - lastClose) / atr;
      signal.volatility  = atr;
      signal.confidence  = _Normalize(signal.velocity,0.0,3.0);
      signal.description = "Bearish breakdown beyond support";
      signal.timestamp   = TimeCurrent();
      return true;
     }

   return false;
  }

bool DetectVolatilityCompression(const double &high[],const double &low[],const double &close[],int lookback,PatternSignal &signal)
  {
   if(lookback < 10)
      return false;

   double atrShort = _ATR(high,low,close,MathMax(5,lookback / 2));
   double atrLong  = _ATR(high,low,close,lookback);
   if(atrLong <= 0.0 || atrShort <= 0.0)
      return false;

   double ratio = atrShort / atrLong;
   if(ratio > 0.65)
      return false;

   signal.pattern     = PATTERN_VOLATILITY_COMPRESSION;
   signal.regime      = REGIME_VOLATILE;
   signal.bullish     = false;
   signal.velocity    = ratio;
   signal.volatility  = atrShort;
   signal.confidence  = _Normalize(0.65 - ratio,0.0,0.65);
   signal.description = "Volatility compression – expect expansion";
   signal.timestamp   = TimeCurrent();
   return true;
  }

ENUM_MARKET_REGIME DetectMarketRegime(const double &close[],const double &high[],const double &low[],int trendLen,int volLen)
  {
   PatternSignal tmp;
   if(DetectTrendSignal(close,trendLen,tmp))
      return REGIME_TRENDING;
   if(DetectBreakout(high,low,close,trendLen,1.0,tmp))
      return REGIME_BREAKOUT;
   if(DetectVolatilityCompression(high,low,close,volLen,tmp))
      return REGIME_VOLATILE;
   return REGIME_RANGING;
  }

class CPatternRecognizer
  {
private:
   int    m_trendLookback;
   int    m_meanFast;
   int    m_meanSlow;
   int    m_volLookback;
   double m_breakoutAtrMult;

public:
                     CPatternRecognizer():
                     m_trendLookback(42),
                     m_meanFast(10),
                     m_meanSlow(30),
                     m_volLookback(28),
                     m_breakoutAtrMult(1.25)
                     {}

   void              Configure(int trendLen,int fast,int slow,int volLen,double atrMult)
     {
      m_trendLookback   = MathMax(trendLen,10);
      m_meanFast        = MathMax(fast,5);
      m_meanSlow        = MathMax(slow,m_meanFast+1);
      m_volLookback     = MathMax(volLen,12);
      m_breakoutAtrMult = MathMax(atrMult,0.5);
     }

   int               Scan(const double &open[],const double &high[],const double &low[],const double &close[],PatternSignal &outTrend,PatternSignal &outAlt)
     {
      int detections = 0;
      if(DetectTrendSignal(close,m_trendLookback,outTrend))
         detections++;
      if(!DetectBreakout(high,low,close,m_trendLookback,m_breakoutAtrMult,outAlt))
        {
         if(!DetectVolatilityCompression(high,low,close,m_volLookback,outAlt))
           {
            if(!DetectMeanReversion(close,m_meanFast,m_meanSlow,outAlt))
              {
               outAlt.pattern     = PATTERN_NONE;
               outAlt.regime      = REGIME_UNKNOWN;
               outAlt.bullish     = false;
               outAlt.confidence  = 0.0;
               outAlt.velocity    = 0.0;
               outAlt.volatility  = 0.0;
               outAlt.description = "No secondary pattern detected";
               outAlt.timestamp   = TimeCurrent();
              }
           }
         else
            detections++;
        }
      else
         detections++;

      return detections;
     }
  };

