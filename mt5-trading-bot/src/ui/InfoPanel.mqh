#pragma once

#include <ChartObjects\ChartObjectsTxtControls.mqh>

struct StrategyStatus
  {
   string  name;
   string  symbol;
   bool    enabled;
  };

struct RiskSnapshot
  {
   double  dailyPnL;
   double  drawdownPercent;
   double  marginUsed;
   double  balance;
   double  equity;
  };

class InfoPanel
  {
private:
   long     m_chartId;
   string   m_prefix;
   bool     m_ready;

public:
                     InfoPanel() : m_chartId(0), m_prefix(""), m_ready(false) {}

   bool              Init(const long chartId,const string prefix)
     {
      m_chartId = chartId;
      m_prefix  = prefix;
      m_ready   = true;
      return(true);
     }

   void              Update(const RiskSnapshot &snapshot,const StrategyStatus &statuses[])
     {
      if(!m_ready)
         return;
     }

   void              Destroy()
     {
      m_ready = false;
     }
  };
