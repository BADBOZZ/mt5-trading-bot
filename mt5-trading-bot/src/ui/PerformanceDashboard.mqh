#pragma once

struct StrategyPerformance
  {
   string  name;
   double  winRate;
   double  avgProfit;
   double  avgLoss;
   int     tradesToday;
   double  bestTrade;
   double  worstTrade;
  };

class PerformanceDashboard
  {
private:
   long     m_chartId;
   string   m_prefix;
   bool     m_ready;

public:
                     PerformanceDashboard() : m_chartId(0), m_prefix(""), m_ready(false) {}

   bool              Init(const long chartId,const string prefix)
     {
      m_chartId = chartId;
      m_prefix  = prefix;
      m_ready   = true;
      return(true);
     }

   void              Update(const StrategyPerformance &stats[])
     {
      if(!m_ready)
         return;
     }

   void              Destroy()
     {
      m_ready = false;
     }
  };
