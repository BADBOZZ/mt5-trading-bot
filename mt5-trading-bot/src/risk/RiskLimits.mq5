//+------------------------------------------------------------------+
//| RiskLimits.mq5                                                  |
//| Enforces global risk guardrails (daily loss, drawdown, etc.).    |
//+------------------------------------------------------------------+
#ifndef __RISK_LIMITS_MQ5__
#define __RISK_LIMITS_MQ5__

#include "..\config\risk-config.mqh"

namespace RiskLimits
  {
   const string GV_KEY_DAY_INDEX      = "RiskLimits_DayIndex";
   const string GV_KEY_DAILY_START    = "RiskLimits_DailyStartEquity";
   const string GV_KEY_PEAK_EQUITY    = "RiskLimits_PeakEquity";
   const string GV_KEY_LAST_LOSS      = "RiskLimits_LastLossTime";
   const string GV_KEY_EMERGENCY_STOP = "RiskLimits_EmergencyStop";

   double GetGlobalOrDefault(const string key, const double defaultValue)
     {
      if(GlobalVariableCheck(key))
         return GlobalVariableGet(key);
      GlobalVariableSet(key, defaultValue);
      return defaultValue;
     }

   void EnsureDailyContext()
     {
      datetime now = TimeCurrent();
      int dayIndex = TimeDayOfYear(now);
      double storedDay = GetGlobalOrDefault(GV_KEY_DAY_INDEX, -1);
      if((int)storedDay != dayIndex)
        {
         GlobalVariableSet(GV_KEY_DAY_INDEX, dayIndex);
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(GV_KEY_DAILY_START, equity);
         GlobalVariableSet(GV_KEY_PEAK_EQUITY, equity);
        }
     }

   void UpdatePeakEquity()
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double peak   = GetGlobalOrDefault(GV_KEY_PEAK_EQUITY, equity);
      if(equity > peak)
         GlobalVariableSet(GV_KEY_PEAK_EQUITY, equity);
     }

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

   int CurrentPositionsForSymbol(const string symbol)
     {
      int total = PositionsTotal();
      int count = 0;
      for(int i = 0; i < total; ++i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(posSymbol == symbol)
            ++count;
        }
      return count;
     }

   bool CheckDailyLossLimit()
     {
      EnsureDailyContext();
      double startEquity = GetGlobalOrDefault(GV_KEY_DAILY_START, AccountInfoDouble(ACCOUNT_EQUITY));
      double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
      double allowedLoss = startEquity * RiskConfig::MaxDailyLossPercent() / 100.0;
      double realizedLoss = startEquity - equity;
      if(allowedLoss <= 0)
         return true;
      return realizedLoss < allowedLoss;
     }

   bool CheckDrawdownLimit()
     {
      EnsureDailyContext();
      UpdatePeakEquity();
      double peak   = GetGlobalOrDefault(GV_KEY_PEAK_EQUITY, AccountInfoDouble(ACCOUNT_EQUITY));
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double drawdown = peak - equity;
      double maxDrawdown = peak * RiskConfig::MaxDrawdownPercent() / 100.0;
      if(maxDrawdown <= 0)
         return true;
      return drawdown < maxDrawdown;
     }

   bool CheckPositionsPerSymbol(const string symbol, const int additionalPositions = 0)
     {
      int existing = CurrentPositionsForSymbol(symbol);
      int limit    = RiskConfig::MaxPositionsPerSymbol();
      if(limit <= 0)
         return true;
      return existing + additionalPositions <= limit;
     }

   bool CheckTotalExposure(const double additionalLots = 0.0)
     {
      double limit = RiskConfig::MaxTotalExposureLots();
      if(limit <= 0)
         return true;
      double total = CurrentTotalExposure();
      return (total + additionalLots) <= limit;
     }

   bool IsInCooldown()
     {
      if(RiskConfig::LossCooldownMinutes() <= 0)
         return false;
      if(!GlobalVariableCheck(GV_KEY_LAST_LOSS))
         return false;
      double lastLoss = GlobalVariableGet(GV_KEY_LAST_LOSS);
      datetime now = TimeCurrent();
      int cooldownSeconds = RiskConfig::LossCooldownMinutes() * 60;
      return (now - (datetime)lastLoss) < cooldownSeconds;
     }

   void RegisterLossEvent(const double lossAmount)
     {
      (void)lossAmount;
      GlobalVariableSet(GV_KEY_LAST_LOSS, TimeCurrent());
     }

   void ActivateEmergencyStop()
     {
      GlobalVariableSet(GV_KEY_EMERGENCY_STOP, 1.0);
     }

   void ResetEmergencyStop()
     {
      GlobalVariableDel(GV_KEY_EMERGENCY_STOP);
     }

   bool IsEmergencyStopActive()
     {
      return GlobalVariableCheck(GV_KEY_EMERGENCY_STOP);
     }

   bool CanTrade(const string symbol, const double additionalLots, const int additionalPositions = 1)
     {
      if(IsEmergencyStopActive())
         return false;
      if(IsInCooldown())
         return false;
      if(!CheckDailyLossLimit())
         return false;
      if(!CheckDrawdownLimit())
         return false;
      if(!CheckPositionsPerSymbol(symbol, additionalPositions))
         return false;
      if(!CheckTotalExposure(additionalLots))
         return false;
      return true;
     }
  }

#endif // __RISK_LIMITS_MQ5__
