#pragma once

struct SignalInfo
  {
   string           strategy;
   string           symbol;
   ENUM_ORDER_TYPE  type;
   double           confidence;
   datetime         timestamp;
  };

class SignalDisplay
  {
private:
   long     m_chartId;
   string   m_prefix;
   bool     m_ready;

public:
                     SignalDisplay() : m_chartId(0), m_prefix(""), m_ready(false) {}

   bool              Init(const long chartId,const string prefix)
     {
      m_chartId = chartId;
      m_prefix  = prefix;
      m_ready   = true;
      return(true);
     }

   void              Update(const SignalInfo &signals[])
     {
      if(!m_ready)
         return;
     }

   void              Destroy()
     {
      m_ready = false;
     }
  };
