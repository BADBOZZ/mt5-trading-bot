//+------------------------------------------------------------------+
//| Risk Configuration Parameters                                    |
//| Provides all adjustable risk inputs for the EA.                  |
//+------------------------------------------------------------------+
#ifndef __RISK_CONFIG_MQH__
#define __RISK_CONFIG_MQH__

//--- account sizing model
enum ENUM_RISK_ACCOUNT_TYPE
  {
   RISK_ACCOUNT_STANDARD = 0,
   RISK_ACCOUNT_MINI     = 1,
   RISK_ACCOUNT_MICRO    = 2
  };

//--- user adjustable inputs (visible inside MetaTrader 5)
input double                 InpRiskPercentPerTrade      = 1.0;    // % of balance to risk per trade
input double                 InpMaxLotPerTrade           = 2.0;    // hard lot cap per order
input double                 InpMaxTotalExposureLots     = 6.0;    // aggregate open volume limit
input int                    InpMaxPositionsPerSymbol    = 3;      // simultaneous trades per symbol
input double                 InpMaxDailyLossPercent      = 3.0;    // daily equity loss stop (% of day start equity)
input double                 InpMaxDrawdownPercent       = 10.0;   // equity drawdown limit from peak
input int                    InpLossCooldownMinutes      = 30;     // cooldown interval after a loss
input ENUM_RISK_ACCOUNT_TYPE InpAccountType              = RISK_ACCOUNT_STANDARD; // account contract type
input double                 InpMinAccountBalance        = 500.0;  // minimum required balance to trade
input double                 InpMarginBufferFactor       = 1.20;   // margin headroom multiplier
input double                 InpEmergencyStopEquityPct   = 35.0;   // trigger emergency stop if equity falls below this % of balance
input double                 InpStopLossMinDistancePts   = 100.0;  // minimum stop loss distance in points

namespace RiskConfig
  {
//--- getters keep the rest of the code decoupled from raw input names
   inline double RiskPercentPerTrade()
     {
      return InpRiskPercentPerTrade;
     }

   inline double MaxLotPerTrade()
     {
      return InpMaxLotPerTrade;
     }

   inline double MaxTotalExposureLots()
     {
      return InpMaxTotalExposureLots;
     }

   inline int MaxPositionsPerSymbol()
     {
      return InpMaxPositionsPerSymbol;
     }

   inline double MaxDailyLossPercent()
     {
      return InpMaxDailyLossPercent;
     }

   inline double MaxDrawdownPercent()
     {
      return InpMaxDrawdownPercent;
     }

   inline int LossCooldownMinutes()
     {
      return InpLossCooldownMinutes;
     }

   inline ENUM_RISK_ACCOUNT_TYPE AccountType()
     {
      return InpAccountType;
     }

   inline double MinAccountBalance()
     {
      return InpMinAccountBalance;
     }

   inline double MarginBufferFactor()
     {
      return InpMarginBufferFactor;
     }

   inline double EmergencyStopEquityPercent()
     {
      return InpEmergencyStopEquityPct;
     }

   inline double StopLossMinDistancePoints()
     {
      return InpStopLossMinDistancePts;
     }

   inline double AccountTypeLotMultiplier()
     {
      switch(InpAccountType)
        {
         case RISK_ACCOUNT_MINI: return 0.1;
         case RISK_ACCOUNT_MICRO: return 0.01;
         default: return 1.0;
        }
     }
  }

#endif // __RISK_CONFIG_MQH__
