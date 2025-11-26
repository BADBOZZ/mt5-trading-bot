#pragma once

#include "..\config\strategy-config.mqh"
#include "..\indicators\Indicators.mqh"

struct StrategySignalResult
{
   ENUM_STRATEGY_SIGNAL signal;
   double confidence;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
};

class BaseStrategy
{
protected:
   string m_name;
   string m_symbols[];
   ENUM_TIMEFRAMES m_timeframes[];
   double m_lastConfidence;

public:
   BaseStrategy()
   {
      m_name           = "BaseStrategy";
      m_lastConfidence = 0.0;
   }
   virtual ~BaseStrategy() {}

   virtual void Reset() { m_lastConfidence = 0.0; }

   virtual StrategySignalResult GenerateSignal(const string symbol,
                                               const ENUM_TIMEFRAMES timeframe) = 0;

   string Name() const { return m_name; }

   int GetSymbols(string &buffer[]) const
   {
      int count = ArraySize(m_symbols);
      ArrayResize(buffer, count);
      for(int i=0; i<count; i++)
         buffer[i] = m_symbols[i];
      return count;
   }

   int GetTimeframes(ENUM_TIMEFRAMES &buffer[]) const
   {
      int count = ArraySize(m_timeframes);
      ArrayResize(buffer, count);
      for(int i=0; i<count; i++)
         buffer[i] = m_timeframes[i];
      return count;
   }

   bool SupportsSymbol(const string symbol) const
   {
      for(int i=0; i<ArraySize(m_symbols); i++)
         if(StringCompare(m_symbols[i], symbol, true) == 0)
            return true;
      return false;
   }

   bool SupportsTimeframe(const ENUM_TIMEFRAMES timeframe) const
   {
      for(int i=0; i<ArraySize(m_timeframes); i++)
         if(m_timeframes[i] == timeframe)
            return true;
      return false;
   }

protected:
   void SetUniverse(const string symbols[], const ENUM_TIMEFRAMES timeframes[])
   {
      int countSymbols = ArraySize(symbols);
      ArrayResize(m_symbols, countSymbols);
      for(int i=0; i<countSymbols; i++)
         m_symbols[i] = symbols[i];

      int countTfs = ArraySize(timeframes);
      ArrayResize(m_timeframes, countTfs);
      for(int j=0; j<countTfs; j++)
         m_timeframes[j] = timeframes[j];
   }

   StrategySignalResult NeutralSignal(const string symbol,
                                      const ENUM_TIMEFRAMES timeframe) const
   {
      StrategySignalResult result;
      result.signal     = STRATEGY_SIGNAL_HOLD;
      result.confidence = 0.0;
      result.entryPrice = 0.0;
      result.stopLoss   = 0.0;
      result.takeProfit = 0.0;
      result.symbol     = symbol;
      result.timeframe  = timeframe;
      return result;
   }

   StrategySignalResult BuildSignal(const string symbol,
                                    const ENUM_TIMEFRAMES timeframe,
                                    const ENUM_STRATEGY_SIGNAL signalType,
                                    const double confidence,
                                    const double entryPrice,
                                    const double stopLoss,
                                    const double takeProfit) const
   {
      StrategySignalResult result;
      result.signal     = signalType;
      result.confidence = ClampConfidence(confidence);
      result.entryPrice = entryPrice;
      result.stopLoss   = stopLoss;
      result.takeProfit = takeProfit;
      result.symbol     = symbol;
      result.timeframe  = timeframe;
      return result;
   }

   double ClampConfidence(const double confidence) const
   {
      return MathMax(0.0, MathMin(100.0, confidence));
   }

   double CalculateStopLoss(const double entryPrice,
                            const double atrValue,
                            const double atrMultiplier,
                            const bool isLong) const
   {
      if(atrValue <= 0.0 || atrMultiplier <= 0.0)
         return entryPrice;

      double distance = atrValue * atrMultiplier;
      if(isLong)
         return entryPrice - distance;
      return entryPrice + distance;
   }

   double CalculateTakeProfit(const double entryPrice,
                              const double atrValue,
                              const double atrMultiplier,
                              const bool isLong) const
   {
      if(atrValue <= 0.0 || atrMultiplier <= 0.0)
         return entryPrice;

      double distance = atrValue * atrMultiplier;
      if(isLong)
         return entryPrice + distance;
      return entryPrice - distance;
   }

   double CalculateConfidenceFromSlope(const double slope,
                                       const double minSlope,
                                       const double maxSlopeContribution = 0.003) const
   {
      double normalized = Indicator_NormalizeConfidence(MathAbs(slope),
                                                        minSlope,
                                                        maxSlopeContribution);
      return ClampConfidence(normalized * 100.0);
   }
};
