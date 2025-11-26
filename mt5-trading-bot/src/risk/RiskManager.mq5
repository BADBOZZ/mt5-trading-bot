//+------------------------------------------------------------------+
//| RiskManager.mq5                                                 |
//| Calculates position sizes based on uniform risk rules.          |
//+------------------------------------------------------------------+
#include "..\config\risk-config.mqh"

namespace RiskManager
  {
//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
   double CurrentTotalExposure()
     {
      double exposure = 0.0;
      int total = PositionsTotal();
      for(int i = 0; i < total; ++i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         exposure += PositionGetDouble(POSITION_VOLUME);
        }
      return exposure;
     }

   double RiskCapitalPerTrade()
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double percent = MathMax(0.0, RiskConfig::RiskPercentPerTrade());
      return balance * percent / 100.0;
     }

   double NormalizeVolume(const string symbol, double requestedLots)
     {
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLotSymbol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double maxLot = MathMin(RiskConfig::MaxLotPerTrade(), maxLotSymbol);
      double adjLots = requestedLots;

      if(lotStep <= 0)
         lotStep = 0.01;

      if(minLot <= 0)
         minLot = lotStep;

      if(adjLots < minLot)
         adjLots = minLot;

      if(adjLots > maxLot)
         adjLots = maxLot;

      double steps = MathFloor(adjLots / lotStep + 0.5);
      double normalized = steps * lotStep;
      return MathMax(minLot, MathMin(normalized, maxLot));
     }

   double RemainingExposureCapacity()
     {
      return MathMax(0.0, RiskConfig::MaxTotalExposureLots() - CurrentTotalExposure());
     }

//+------------------------------------------------------------------+
//| Primary calculation                                              |
//+------------------------------------------------------------------+
   double CalculateLotSize(const string symbol,
                           const double entryPrice,
                           const double stopLossPrice)
     {
      if(symbol == "" || entryPrice <= 0 || stopLossPrice <= 0)
         return 0.0;

      if(!SymbolSelect(symbol, true))
         return 0.0;

      double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue= SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

      if(point <= 0 || tickSize <= 0 || tickValue <= 0)
         return 0.0;

      double stopDistance = MathAbs(entryPrice - stopLossPrice);
      double minDistance  = RiskConfig::StopLossMinDistancePoints() * point;
      stopDistance        = MathMax(stopDistance, minDistance);

      double riskMoney = RiskCapitalPerTrade();
      double ticks     = stopDistance / tickSize;

      if(ticks <= 0)
         return 0.0;

      double moneyPerLot = ticks * tickValue;
      if(moneyPerLot <= 0)
         return 0.0;

      double rawLots = riskMoney / moneyPerLot;
      rawLots *= RiskConfig::AccountTypeLotMultiplier();

      rawLots = NormalizeVolume(symbol, rawLots);

      double exposureRoom = RemainingExposureCapacity();
      if(exposureRoom <= 0)
         return 0.0;

      if(rawLots > exposureRoom)
         rawLots = exposureRoom;

      return NormalizeVolume(symbol, rawLots);
     }

   double CalculateLotSizeByPoints(const string symbol,
                                   const double entryPrice,
                                   const double stopLossPoints)
     {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0)
         return 0.0;
      double stopLossPrice = entryPrice - stopLossPoints * point;
      if(stopLossPoints < 0)
         stopLossPrice = entryPrice + MathAbs(stopLossPoints) * point;
      return CalculateLotSize(symbol, entryPrice, stopLossPrice);
     }

   bool CanOpenPosition(const string symbol, const double plannedLots)
     {
      if(plannedLots <= 0.0)
         return false;

      double normalized = NormalizeVolume(symbol, plannedLots);
      if(normalized <= 0.0)
         return false;

      if(normalized > RiskConfig::MaxLotPerTrade())
         return false;

      double exposureRoom = RemainingExposureCapacity();
      if(exposureRoom < normalized)
         return false;

      return true;
     }
  }
