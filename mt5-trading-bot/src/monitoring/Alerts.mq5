#property copyright "Monitoring Toolkit"
#property version   "1.00"
#property strict

#include "Logger.mq5"

enum AlertChannel
  {
   ALERT_CHANNEL_POPUP   = 1,
   ALERT_CHANNEL_EMAIL   = 2,
   ALERT_CHANNEL_PUSH    = 4
  };

struct AlertSettings
  {
   bool   enable_popup;
   bool   enable_email;
   bool   enable_push;
   string email_subject_prefix;
   string risk_contact;
  };

class AlertRouter
  {
private:
   AlertSettings m_settings;

   void EmitPopup(const string title,const string body) const
     {
      if(!m_settings.enable_popup)
         return;
      Alert(StringFormat("%s: %s",title,body));
     }

   void EmitEmail(const string title,const string body) const
     {
      if(!m_settings.enable_email)
         return;
      string subject=StringFormat("%s%s",m_settings.email_subject_prefix,title);
      SendMail(subject,body);
     }

   void EmitPush(const string title,const string body) const
     {
      if(!m_settings.enable_push)
         return;
      string payload=StringFormat("%s\n%s",title,body);
      SendNotification(payload);
     }

public:
                     AlertRouter()
     {
      m_settings.enable_popup=true;
      m_settings.enable_email=false;
      m_settings.enable_push=false;
      m_settings.email_subject_prefix="EA ";
      m_settings.risk_contact="RiskDesk";
     }

   void Configure(const AlertSettings &settings)
     {
      m_settings=settings;
     }

   void Dispatch(const string title,const string body,const int channels=ALERT_CHANNEL_POPUP|ALERT_CHANNEL_PUSH) const
     {
      if((channels & ALERT_CHANNEL_POPUP)>0)
         EmitPopup(title,body);
      if((channels & ALERT_CHANNEL_EMAIL)>0)
         EmitEmail(title,body);
      if((channels & ALERT_CHANNEL_PUSH)>0)
         EmitPush(title,body);
     }

   void TradeExecution(const ulong ticket,
                       const string action,
                       const double volume,
                       const double price,
                       const string status) const
     {
      string title=StringFormat("Trade %s %I64u",action,ticket);
      string body=StringFormat("Volume %.2f @ %s (%s)",volume,DoubleToString(price,_Digits),status);
      Dispatch(title,body);
      LogTradeEvent(ticket,action,volume,price,status,body);
     }

   void RiskLimit(const string rule_id,
                  const string description,
                  const double exposure,
                  const double limit_value,
                  const bool hard_limit) const
     {
      string title=StringFormat("%s limit breached",hard_limit ? "HARD" : "Soft");
      string body=StringFormat("Rule=%s (%s) exposure %.2f limit %.2f notify %s",rule_id,description,exposure,limit_value,m_settings.risk_contact);
      Dispatch(title,body,ALERT_CHANNEL_POPUP|ALERT_CHANNEL_EMAIL);
      LogErrorEvent("RiskLimit",body);
     }

   void StrategySignal(const string strategy,
                       const string signal,
                       const double strength,
                       const string timeframe) const
     {
      string title=StringFormat("%s signal",strategy);
      string body=StringFormat("%s (%s) strength %.2f",signal,timeframe,strength);
      Dispatch(title,body,ALERT_CHANNEL_POPUP);
      LogStrategySignal(strategy,signal,strength,timeframe);
     }
  };

AlertRouter g_alerts;

void InitializeAlerts(const AlertSettings &settings)
  {
   g_alerts.Configure(settings);
  }

void AlertTradeExecution(const ulong ticket,const string action,const double volume,const double price,const string status)
  {
   g_alerts.TradeExecution(ticket,action,volume,price,status);
  }

void AlertRiskLimitBreach(const string rule_id,const string description,const double exposure,const double limit_value,const bool hard_limit)
  {
   g_alerts.RiskLimit(rule_id,description,exposure,limit_value,hard_limit);
  }

void AlertStrategySignal(const string strategy,const string signal,const double strength,const string timeframe)
  {
   g_alerts.StrategySignal(strategy,signal,strength,timeframe);
  }
