#pragma once

#include "BaseStrategy.mqh"

class BreakoutStrategy : public BaseStrategy
{
private:
   BreakoutStrategyConfig m_config;

public:
   BreakoutStrategy()
   {
      m_name = "BreakoutStrategy";
   }

   void Configure(const BreakoutStrategyConfig &config)
   {
      m_config = config;
      SetUniverse(m_config.universe.symbols, m_config.universe.timeframes);
   }

   virtual StrategySignalResult GenerateSignal(const string symbol,
                                               const ENUM_TIMEFRAMES timeframe)
   {
      StrategySignalResult result = NeutralSignal(symbol, timeframe);
      if(!SupportsSymbol(symbol) || !SupportsTimeframe(timeframe))
         return result;

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         point = 0.0001;

      double resistance = Indicator_GetHighestHigh(symbol, timeframe, m_config.resistanceLookback);
      double support    = Indicator_GetLowestLow(symbol, timeframe, m_config.supportLookback);
      double price      = iClose(symbol, timeframe, 0);
      double prevClose  = iClose(symbol, timeframe, 1);
      double atr        = Indicator_GetATR(symbol, timeframe, 14);

      double avgVolume  = Indicator_GetAverageVolume(symbol, timeframe, m_config.volumeLookback);
      double currentVol = Indicator_GetVolume(symbol, timeframe, 0);

      double buffer     = m_config.breakoutBufferPoints * point;
      double tolerance  = m_config.retestTolerancePoints * point;

      bool volumeConfirm = (avgVolume > 0.0) &&
                           (currentVol >= avgVolume * m_config.volumeSpikeMultiplier);

      bool breakoutUp   = (price > resistance + buffer) &&
                          (prevClose <= resistance + tolerance);
      bool breakoutDown = (price < support - buffer) &&
                          (prevClose >= support - tolerance);

      double higherScore = EvaluateHigherTimeframeAlignment(symbol, timeframe, breakoutUp, breakoutDown);

      if(!volumeConfirm)
         return result;

      double volumeScore = Indicator_NormalizeConfidence(currentVol,
                                                         avgVolume,
                                                         avgVolume * m_config.volumeSpikeMultiplier * 1.5) * 100.0;

      if(breakoutUp)
      {
         double distancePoints = (price - resistance) / point;
         double distanceScore = Indicator_NormalizeConfidence(distancePoints,
                                                              m_config.breakoutBufferPoints,
                                                              m_config.breakoutBufferPoints * 4.0) * 100.0;
         double confidence = ClampConfidence(45.0 + volumeScore * 0.3 + distanceScore * 0.2 + higherScore * 0.5);
         if(confidence >= m_config.minConfidence)
         {
            double stopLoss   = price - MathMax(atr * 1.2, tolerance * 2.0);
            double takeProfit = price + MathMax(atr * 2.5, distancePoints * point * 1.5);
            return BuildSignal(symbol,
                               timeframe,
                               STRATEGY_SIGNAL_BUY,
                               confidence,
                               price,
                               stopLoss,
                               takeProfit);
         }
      }

      if(breakoutDown)
      {
         double distancePoints = (support - price) / point;
         double distanceScore = Indicator_NormalizeConfidence(distancePoints,
                                                              m_config.breakoutBufferPoints,
                                                              m_config.breakoutBufferPoints * 4.0) * 100.0;
         double confidence = ClampConfidence(45.0 + volumeScore * 0.3 + distanceScore * 0.2 + higherScore * 0.5);
         if(confidence >= m_config.minConfidence)
         {
            double stopLoss   = price + MathMax(atr * 1.2, tolerance * 2.0);
            double takeProfit = price - MathMax(atr * 2.5, distancePoints * point * 1.5);
            return BuildSignal(symbol,
                               timeframe,
                               STRATEGY_SIGNAL_SELL,
                               confidence,
                               price,
                               stopLoss,
                               takeProfit);
         }
      }

      return result;
   }

private:
   double EvaluateHigherTimeframeAlignment(const string symbol,
                                           const ENUM_TIMEFRAMES currentTf,
                                           const bool breakoutUp,
                                           const bool breakoutDown) const
   {
      ENUM_TIMEFRAMES higherTf = SelectHigherTimeframe(currentTf);
      if(higherTf == currentTf)
         return 15.0;

      double fast = Indicator_GetEMA(symbol, higherTf, 34);
      double slow = Indicator_GetEMA(symbol, higherTf, 89);
      bool higherUp   = fast > slow;
      bool higherDown = fast < slow;

      if(breakoutUp && higherUp)
         return 35.0;
      if(breakoutDown && higherDown)
         return 35.0;
      if((breakoutUp && !higherDown) || (breakoutDown && !higherUp))
         return 20.0;
      return 5.0;
   }

   ENUM_TIMEFRAMES SelectHigherTimeframe(const ENUM_TIMEFRAMES currentTf) const
   {
      ENUM_TIMEFRAMES selected = currentTf;
      for(int i=0; i<ArraySize(m_timeframes); i++)
         if(m_timeframes[i] > selected)
            selected = m_timeframes[i];
      return selected;
   }
};
