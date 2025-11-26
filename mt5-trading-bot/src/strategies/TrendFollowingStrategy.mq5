#pragma once

#include "BaseStrategy.mqh"

class TrendFollowingStrategy : public BaseStrategy
{
private:
   TrendStrategyConfig m_config;

public:
   TrendFollowingStrategy()
   {
      m_name = "TrendFollowingStrategy";
   }

   void Configure(const TrendStrategyConfig &config)
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

      double fastEMA = Indicator_GetEMA(symbol, timeframe, m_config.fastEmaPeriod);
      double slowEMA = Indicator_GetEMA(symbol, timeframe, m_config.slowEmaPeriod);
      double emaSlope = fastEMA - slowEMA;

      double macdMain = 0.0, macdSignal = 0.0, macdHist = 0.0;
      if(!Indicator_GetMACD(symbol,
                            timeframe,
                            m_config.fastEmaPeriod,
                            m_config.slowEmaPeriod,
                            m_config.macdSignalPeriod,
                            macdMain,
                            macdSignal,
                            macdHist))
      {
         return result;
      }

      double atr = Indicator_GetATR(symbol, timeframe, 14);
      double price = iClose(symbol, timeframe, 0);

      bool trendUp   = (fastEMA > slowEMA) && (macdMain > macdSignal) && (macdHist > 0.0);
      bool trendDown = (fastEMA < slowEMA) && (macdMain < macdSignal) && (macdHist < 0.0);

      double slopeConfidence = CalculateConfidenceFromSlope(emaSlope,
                                                            m_config.minSlope,
                                                            m_config.minSlope * 10.0);

      double macdConfidence = Indicator_NormalizeConfidence(MathAbs(macdHist),
                                                            0.0,
                                                            0.002) * 100.0;

      double higherConfidence = 0.0;
      ENUM_TIMEFRAMES higherTf = SelectHigherTimeframe(timeframe);
      if(higherTf != timeframe)
      {
         double higherTrendFast = Indicator_GetEMA(symbol, higherTf, m_config.fastEmaPeriod);
         double higherTrendSlow = Indicator_GetEMA(symbol, higherTf, m_config.slowEmaPeriod);
         bool higherBull = higherTrendFast > higherTrendSlow;
         bool higherBear = higherTrendFast < higherTrendSlow;
         if((trendUp && higherBull) || (trendDown && higherBear))
            higherConfidence = 25.0;
      }

      double combinedConfidence = ClampConfidence(slopeConfidence * 0.45 +
                                                  macdConfidence * 0.4 +
                                                  higherConfidence);

      if(combinedConfidence < m_config.minConfidence)
         return result;

      if(trendUp)
      {
         double stopLoss   = CalculateStopLoss(price, atr, m_config.stopAtrMultiplier, true);
         double takeProfit = CalculateTakeProfit(price, atr, m_config.takeProfitAtrMultiplier, true);
         return BuildSignal(symbol,
                            timeframe,
                            STRATEGY_SIGNAL_BUY,
                            combinedConfidence,
                            price,
                            stopLoss,
                            takeProfit);
      }

      if(trendDown)
      {
         double stopLoss   = CalculateStopLoss(price, atr, m_config.stopAtrMultiplier, false);
         double takeProfit = CalculateTakeProfit(price, atr, m_config.takeProfitAtrMultiplier, false);
         return BuildSignal(symbol,
                            timeframe,
                            STRATEGY_SIGNAL_SELL,
                            combinedConfidence,
                            price,
                            stopLoss,
                            takeProfit);
      }

      return result;
   }

private:
   ENUM_TIMEFRAMES SelectHigherTimeframe(const ENUM_TIMEFRAMES currentTf) const
   {
      ENUM_TIMEFRAMES selected = currentTf;
      for(int i=0; i<ArraySize(m_timeframes); i++)
         if(m_timeframes[i] > selected)
            selected = m_timeframes[i];
      return selected;
   }
};
