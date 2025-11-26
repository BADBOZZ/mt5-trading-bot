#pragma once

#include <MovingAverages.mqh>

double Indicator_GetEMA(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const int period,
                        const int shift = 0)
{
   int handle = iMA(symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   IndicatorRelease(handle);
   return buffer[0];
}

bool Indicator_GetMACD(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const int fastPeriod,
                       const int slowPeriod,
                       const int signalPeriod,
                       double &mainValue,
                       double &signalValue,
                       double &histogramValue)
{
   int handle = iMACD(symbol, timeframe, fastPeriod, slowPeriod, signalPeriod, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;

   double mainBuffer[];
   double signalBuffer[];
   double histBuffer[];
   bool success = (CopyBuffer(handle, 0, 0, 2, mainBuffer) > 0 &&
                   CopyBuffer(handle, 1, 0, 2, signalBuffer) > 0 &&
                   CopyBuffer(handle, 2, 0, 2, histBuffer) > 0);
   if(success)
   {
      mainValue      = mainBuffer[0];
      signalValue    = signalBuffer[0];
      histogramValue = histBuffer[0];
   }
   IndicatorRelease(handle);
   return success;
}

double Indicator_GetRSI(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const int period,
                        const int shift = 0)
{
   int handle = iRSI(symbol, timeframe, period, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return 50.0;

   double buffer[];
   if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0)
   {
      IndicatorRelease(handle);
      return 50.0;
   }
   IndicatorRelease(handle);
   return buffer[0];
}

bool Indicator_GetBollinger(const string symbol,
                            const ENUM_TIMEFRAMES timeframe,
                            const int period,
                            const double deviation,
                            const int shift,
                            double &upper,
                            double &middle,
                            double &lower)
{
   int handle = iBands(symbol, timeframe, period, 0, deviation, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;

   double upperBuffer[];
   double middleBuffer[];
   double lowerBuffer[];
   bool success = (CopyBuffer(handle, 0, shift, 1, upperBuffer) > 0 &&
                   CopyBuffer(handle, 1, shift, 1, middleBuffer) > 0 &&
                   CopyBuffer(handle, 2, shift, 1, lowerBuffer) > 0);
   if(success)
   {
      upper  = upperBuffer[0];
      middle = middleBuffer[0];
      lower  = lowerBuffer[0];
   }
   IndicatorRelease(handle);
   return success;
}

bool Indicator_GetStochastic(const string symbol,
                             const ENUM_TIMEFRAMES timeframe,
                             const int kPeriod,
                             const int dPeriod,
                             const int slowing,
                             const int shift,
                             double &mainSto,
                             double &signalSto)
{
   int handle = iStochastic(symbol, timeframe, kPeriod, dPeriod, slowing, MODE_STO_LOWHIGH, STO_LOWHIGH);
   if(handle == INVALID_HANDLE)
      return false;

   double mainBuffer[];
   double signalBuffer[];
   bool success = (CopyBuffer(handle, 0, shift, 1, mainBuffer) > 0 &&
                   CopyBuffer(handle, 1, shift, 1, signalBuffer) > 0);
   if(success)
   {
      mainSto   = mainBuffer[0];
      signalSto = signalBuffer[0];
   }
   IndicatorRelease(handle);
   return success;
}

double Indicator_GetATR(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const int period,
                        const int shift = 0)
{
   int handle = iATR(symbol, timeframe, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   IndicatorRelease(handle);
   return buffer[0];
}

double Indicator_GetHighestHigh(const string symbol,
                                const ENUM_TIMEFRAMES timeframe,
                                const int lookback)
{
   double highs[];
   if(CopyHigh(symbol, timeframe, 0, lookback, highs) <= 0)
      return 0.0;

   double maxHigh = highs[0];
   for(int i=1; i<ArraySize(highs); i++)
      if(highs[i] > maxHigh)
         maxHigh = highs[i];
   return maxHigh;
}

double Indicator_GetLowestLow(const string symbol,
                              const ENUM_TIMEFRAMES timeframe,
                              const int lookback)
{
   double lows[];
   if(CopyLow(symbol, timeframe, 0, lookback, lows) <= 0)
      return 0.0;

   double minLow = lows[0];
   for(int i=1; i<ArraySize(lows); i++)
      if(lows[i] < minLow)
         minLow = lows[i];
   return minLow;
}

double Indicator_GetAverageVolume(const string symbol,
                                  const ENUM_TIMEFRAMES timeframe,
                                  const int lookback)
{
   long volumes[];
   if(CopyVolume(symbol, timeframe, 1, lookback, volumes) <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i=0; i<ArraySize(volumes); i++)
      sum += (double)volumes[i];
   if(ArraySize(volumes) == 0)
      return 0.0;
   return sum / (double)ArraySize(volumes);
}

double Indicator_GetVolume(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift = 0)
{
   long volumes[];
   if(CopyVolume(symbol, timeframe, shift, 1, volumes) <= 0)
      return 0.0;
   return (double)volumes[0];
}

bool Indicator_GetMultiTimeframeEMA(const string symbol,
                                    const ENUM_TIMEFRAMES lowerTf,
                                    const ENUM_TIMEFRAMES higherTf,
                                    const int lowerPeriod,
                                    const int higherPeriod,
                                    double &lowerValue,
                                    double &higherValue)
{
   lowerValue  = Indicator_GetEMA(symbol, lowerTf, lowerPeriod);
   higherValue = Indicator_GetEMA(symbol, higherTf, higherPeriod);
   return (lowerValue != 0.0 && higherValue != 0.0);
}

double Indicator_CombineScores(const double scoreA,
                               const double scoreB,
                               const double weightA = 0.5)
{
   double wA = MathMax(0.0, MathMin(1.0, weightA));
   double wB = 1.0 - wA;
   return (scoreA * wA) + (scoreB * wB);
}

double Indicator_NormalizeConfidence(const double rawValue,
                                     const double minValue,
                                     const double maxValue)
{
   if(maxValue - minValue == 0.0)
      return 0.0;
   double normalized = (rawValue - minValue) / (maxValue - minValue);
   return MathMax(0.0, MathMin(1.0, normalized));
}
