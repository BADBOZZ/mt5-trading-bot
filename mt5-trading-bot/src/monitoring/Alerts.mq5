#property copyright "Monitoring Toolkit"
#property version   "1.10"
#property strict

#include "Logger.mq5"

//+------------------------------------------------------------------+
//| Alert channels                                                   |
//+------------------------------------------------------------------+
enum AlertChannel
  {
   ALERT_CHANNEL_POPUP    = 1,
   ALERT_CHANNEL_EMAIL    = 2,
   ALERT_CHANNEL_PUSH     = 4,
   ALERT_CHANNEL_TELEGRAM = 8
  };

//+------------------------------------------------------------------+
//| Configuration structures                                         |
//+------------------------------------------------------------------+
struct AlertSettings
  {
   bool   enable_popup;
   bool   enable_email;
   bool   enable_push;
   string email_subject_prefix;
   string risk_contact;
  };

struct TelegramSettings
  {
   bool   enabled;
   string bot_token;
   string chat_id;
   string api_endpoint;
   bool   send_as_silent;
   int    timeout_ms;
  };

//+------------------------------------------------------------------+
//| URL encoding helper                                              |
//+------------------------------------------------------------------+
string UrlEncode(const string value)
  {
   string encoded="";
   int len=StringLen(value);
   for(int i=0;i<len;i++)
     {
      ushort ch=StringGetCharacter(value,i);
      bool safe=(ch>='A' && ch<='Z') ||
                (ch>='a' && ch<='z') ||
                (ch>='0' && ch<='9') ||
                ch=='-' || ch=='_' || ch=='.' || ch=='~';
      if(safe)
         encoded+=CharToString((uchar)ch);
      else if(ch==' ')
         encoded+="%20";
      else
         encoded+=StringFormat("%%%02X",ch);
     }
   return(encoded);
  }

//+------------------------------------------------------------------+
//| Alert router implementation                                      |
//+------------------------------------------------------------------+
class AlertRouter
  {
private:
   AlertSettings    m_settings;
   TelegramSettings m_telegram;

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

   bool EmitTelegram(const string title,const string body,const bool silent=false) const
     {
      if(!m_telegram.enabled || m_telegram.bot_token=="" || m_telegram.chat_id=="")
         return(false);

      string endpoint=m_telegram.api_endpoint;
      if(endpoint=="")
         endpoint="https://api.telegram.org";
      int len=StringLen(endpoint);
      if(len>0 && StringGetCharacter(endpoint,len-1)=='/')
         endpoint=StringSubstr(endpoint,0,len-1);

      string url=StringFormat("%s/bot%s/sendMessage",endpoint,m_telegram.bot_token);
      string text=StringFormat("<b>%s</b>\n%s",title,body);
      string payload=StringFormat("chat_id=%s&text=%s&parse_mode=HTML&disable_notification=%s",
                                  m_telegram.chat_id,
                                  UrlEncode(text),
                                  ((silent || m_telegram.send_as_silent) ? "true" : "false"));

      char request[];
      StringToCharArray(payload,request,0,WHOLE_ARRAY,CP_UTF8);
      char response[];
      string headers="Content-Type: application/x-www-form-urlencoded\r\n";
      string resp_headers="";
      int status=WebRequest("POST",url,headers,m_telegram.timeout_ms,request,response,resp_headers);
      if(status==-1)
        {
         int err=GetLastError();
         LogErrorEvent("Telegram",StringFormat("WebRequest failed err=%d",err),err);
         ResetLastError();
         return(false);
        }

      if(status>=200 && status<300)
         return(true);

      string resp=CharArrayToString(response,0,ArraySize(response),CP_UTF8);
      LogErrorEvent("Telegram",StringFormat("HTTP %d %s",status,resp));
      return(false);
     }

public:
                     AlertRouter()
     {
      m_settings.enable_popup=true;
      m_settings.enable_email=false;
      m_settings.enable_push=false;
      m_settings.email_subject_prefix="EA ";
      m_settings.risk_contact="RiskDesk";
      m_telegram.enabled=false;
      m_telegram.api_endpoint="https://api.telegram.org";
      m_telegram.send_as_silent=false;
      m_telegram.timeout_ms=5000;
     }

   void Configure(const AlertSettings &settings)
     {
      m_settings=settings;
     }

   void ConfigureTelegram(const TelegramSettings &settings)
     {
      m_telegram=settings;
      if(m_telegram.api_endpoint=="")
         m_telegram.api_endpoint="https://api.telegram.org";
      if(m_telegram.timeout_ms<=0)
         m_telegram.timeout_ms=5000;
     }

   void Dispatch(const string title,const string body,const int channels=ALERT_CHANNEL_POPUP|ALERT_CHANNEL_PUSH|ALERT_CHANNEL_TELEGRAM,const bool silent_telegram=false) const
     {
      if((channels & ALERT_CHANNEL_POPUP)>0)
         EmitPopup(title,body);
      if((channels & ALERT_CHANNEL_EMAIL)>0)
         EmitEmail(title,body);
      if((channels & ALERT_CHANNEL_PUSH)>0)
         EmitPush(title,body);
      if((channels & ALERT_CHANNEL_TELEGRAM)>0)
         EmitTelegram(title,body,silent_telegram);
     }

   void TradeExecution(const ulong ticket,
                       const string action,
                       const double volume,
                       const double price,
                       const string status) const
     {
      string title=StringFormat("Trade %s %I64u",action,ticket);
      string body=StringFormat("Volume %.2f @ %s (%s)",volume,DoubleToString(price,_Digits),status);
      Dispatch(title,body,ALERT_CHANNEL_POPUP|ALERT_CHANNEL_PUSH|ALERT_CHANNEL_TELEGRAM);
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
      Dispatch(title,body,ALERT_CHANNEL_POPUP|ALERT_CHANNEL_EMAIL|ALERT_CHANNEL_TELEGRAM);
      LogErrorEvent("RiskLimit",body);
     }

   void StrategySignal(const string strategy,
                       const string signal,
                       const double strength,
                       const string timeframe) const
     {
      string title=StringFormat("%s signal",strategy);
      string body=StringFormat("%s (%s) strength %.2f",signal,timeframe,strength);
      Dispatch(title,body,ALERT_CHANNEL_POPUP|ALERT_CHANNEL_TELEGRAM,true);
      LogStrategySignal(strategy,signal,strength,timeframe);
     }

   void DailyPerformanceReport(const string period,
                               const double net_pnl,
                               const double return_pct,
                               const double max_drawdown,
                               const double win_rate) const
     {
      string title=StringFormat("Performance %s",period);
      string body=StringFormat("PNL %.2f (%+.2f%%) DD %.2f Win %.2f%%",net_pnl,return_pct,max_drawdown,win_rate);
      Dispatch(title,body,ALERT_CHANNEL_TELEGRAM,true);
      LogPerformanceMetric(StringFormat("pnl_%s",period),net_pnl,"portfolio",period);
     }
  };

//+------------------------------------------------------------------+
//| Global helpers                                                   |
//+------------------------------------------------------------------+
AlertRouter g_alerts;

void InitializeAlerts(const AlertSettings &settings)
  {
   g_alerts.Configure(settings);
  }

void InitializeAlerts(const AlertSettings &settings,const TelegramSettings &telegram_settings)
  {
   g_alerts.Configure(settings);
   g_alerts.ConfigureTelegram(telegram_settings);
  }

void ConfigureTelegramChannel(const TelegramSettings &settings)
  {
   g_alerts.ConfigureTelegram(settings);
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

void AlertDailyPerformance(const string period,const double net_pnl,const double return_pct,const double max_drawdown,const double win_rate)
  {
   g_alerts.DailyPerformanceReport(period,net_pnl,return_pct,max_drawdown,win_rate);
  }
