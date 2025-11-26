#pragma once

#include <Trade\PositionInfo.mqh>

struct PositionRow
  {
   string  symbol;
   string  type;
   double  volume;
   double  profit;
   double  stopLoss;
   double  takeProfit;
  };

class PositionDisplay
  {
private:
   long     m_chartId;
   string   m_prefix;
   bool     m_ready;

public:
                     PositionDisplay() : m_chartId(0), m_prefix(""), m_ready(false) {}

   bool              Init(const long chartId,const string prefix)
     {
      m_chartId = chartId;
      m_prefix  = prefix;
      m_ready   = true;
      return(true);
     }

   void              Update(const PositionRow &rows[])
     {
      if(!m_ready)
         return;
     }

   void              Destroy()
     {
      m_ready = false;
     }
  };
