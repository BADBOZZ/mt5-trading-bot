//+------------------------------------------------------------------+
//| SafetyChecks.mq5                                                |
//| Performs final safety validation before sending orders.         |
//+------------------------------------------------------------------+
#ifndef __SAFETY_CHECKS_MQ5__
#define __SAFETY_CHECKS_MQ5__

#include "..\config\risk-config.mqh"
#include "RiskManager.mq5"
#include "RiskLimits.mq5"

namespace SafetyChecks
  {
   bool HasRequiredBalance()
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      return balance >= RiskConfig::MinAccountBalance();
     }

   bool HasSufficientMargin(const string symbol,
                            const ENUM_ORDER_TYPE orderType,
                            const double lots,
                            const double price)
     {
      double margin = 0.0;
      if(!OrderCalcMargin(orderType, symbol, lots, price, margin))
         return false;
      double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
      double required   = margin * RiskConfig::MarginBufferFactor();
      return freeMargin >= required;
     }

   bool EmergencyStopRequired()
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      double threshold = balance * RiskConfig::EmergencyStopEquityPercent() / 100.0;
      if(threshold <= 0)
         return false;
      if(equity <= threshold)
        {
         RiskLimits::ActivateEmergencyStop();
         return true;
        }
      return false;
     }

   bool PreTradeValidation(const string symbol,
                           const ENUM_ORDER_TYPE orderType,
                           const double plannedLots,
                           const double entryPrice,
                           const double stopLossPrice)
     {
      if(symbol == "" || plannedLots <= 0 || entryPrice <= 0 || stopLossPrice <= 0)
         return false;

      if(!HasRequiredBalance())
         return false;

      if(EmergencyStopRequired() || RiskLimits::IsEmergencyStopActive())
         return false;

      if(!RiskLimits::CanTrade(symbol, plannedLots, 1))
         return false;

      if(!RiskManager::CanOpenPosition(symbol, plannedLots))
         return false;

      if(!HasSufficientMargin(symbol, orderType, plannedLots, entryPrice))
         return false;

      double recalculatedLots = RiskManager::CalculateLotSize(symbol, entryPrice, stopLossPrice);
      if(recalculatedLots <= 0)
         return false;

      return true;
     }

   void TriggerEmergencyStop()
     {
      RiskLimits::ActivateEmergencyStop();
     }

   void ClearEmergencyStop()
     {
      RiskLimits::ResetEmergencyStop();
     }
  }

#endif // __SAFETY_CHECKS_MQ5__
