#pragma once

#include "BaseStrategy.mqh"

class MeanReversionStrategy : public BaseStrategy
{
private:
   MeanReversionStrategyConfig m_config;

public:
   MeanReversionStrategy()
   {
      m_name = "MeanReversionStrategy";
   }

   void Configure(const MeanReversionStrategyConfig &config)
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

      double rsi = Indicator_GetRSI(symbol, timeframe, m_config.rsiPeriod);
      double upper = 0.0, middle = 0.0, lower = 0.0;
      if(!Indicator_GetBollinger(symbol,
                                 timeframe,
                                 m_config.bollingerPeriod,
                                 m_config.bollingerDeviation,
                                 0,
                                 upper,
                                 middle,
                                 lower))
      {
         return result;
      }

      double stoMain = 0.0, stoSignal = 0.0;
      bool stochOk = Indicator_GetStochastic(symbol,
                                             timeframe,
                                             m_config.stochasticKPeriod,
                                             m_config.stochasticDPeriod,
                                             m_config.stochasticSlowing,
                                             0,
                                             stoMain,
                                             stoSignal);

      double atr = Indicator_GetATR(symbol, timeframe, 14);
      double price = iClose(symbol, timeframe, 0);

      double compression = 0.0;
      if(middle != 0.0)
         compression = (upper - lower) / middle;

      bool oversold = (rsi <= m_config.oversoldLevel) && (price <= lower);
      bool overbought = (rsi >= m_config.overboughtLevel) && (price >= upper);

      bool stoBullCross = stochOk && (stoMain > stoSignal) && (stoMain < 35.0);
      bool stoBearCross = stochOk && (stoMain < stoSignal) && (stoMain > 65.0);

      double higherNeutralScore = EvaluateHigherTimeframeNeutrality(symbol, timeframe);
      double compressionScore = Indicator_NormalizeConfidence(m_config.exitBandCompression - compression,
                                                              0.0,
                                                              m_config.exitBandCompression) * 100.0;

      double confidence = 0.0;
      if(oversold && stoBullCross)
      {
         confidence = ClampConfidence(40.0 +
                                      (m_config.oversoldLevel - rsi) * 0.8 +
                                      compressionScore * 0.2 +
                                      higherNeutralScore * 0.4);

         if(confidence >= m_config.minConfidence)
         {
            double stopLoss   = lower - atr * 0.8;
            double takeProfit = middle;
            if(takeProfit <= price)
               takeProfit = price + atr * 1.2;
            return BuildSignal(symbol,
                               timeframe,
                               STRATEGY_SIGNAL_BUY,
                               confidence,
                               price,
                               stopLoss,
                               takeProfit);
         }
      }

      if(overbought && stoBearCross)
      {
         confidence = ClampConfidence(40.0 +
                                      (rsi - m_config.overboughtLevel) * 0.8 +
                                      compressionScore * 0.2 +
                                      higherNeutralScore * 0.4);

         if(confidence >= m_config.minConfidence)
         {
            double stopLoss   = upper + atr * 0.8;
            double takeProfit = middle;
            if(takeProfit >= price)
               takeProfit = price - atr * 1.2;
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
   double EvaluateHigherTimeframeNeutrality(const string symbol,
                                            const ENUM_TIMEFRAMES currentTf) const
   {
      ENUM_TIMEFRAMES higherTf = SelectHigherTimeframe(currentTf);
      if(higherTf == currentTf)
         return 20.0;

      double higherRsi = Indicator_GetRSI(symbol, higherTf, m_config.rsiPeriod);
      if(higherRsi >= 40.0 && higherRsi <= 60.0)
         return 40.0;
      if(higherRsi >= 35.0 && higherRsi <= 65.0)
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
