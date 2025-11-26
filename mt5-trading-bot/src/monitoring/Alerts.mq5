//+------------------------------------------------------------------+
//| Alerts.mq5                                                       |
//| Centralized alerting utilities for MetaTrader 5 EAs              |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Alert manager class                                              |
//+------------------------------------------------------------------+
class CAlertManager
  {
private:
   bool     m_popup_enabled;
   bool     m_email_enabled;
   bool     m_push_enabled;
   bool     m_telegram_enabled;
   string   m_email_recipient;
   string   m_email_prefix;
   string   m_push_tag;
   string   m_bot_token;
   string   m_chat_id;
   int      m_web_timeout;
   int      m_retries;

   void     SendPopup(const string message) const;
   void     SendEmail(const string subject,const string body) const;
   void     SendPush(const string message) const;
   bool     SendTelegram(const string message) const;
   string   BuildSubject(const string category) const;
   string   OrderTypeToString(const ENUM_ORDER_TYPE type) const;
   string   UrlEncode(const string value) const;
   bool     Dispatch(const string category,const string body) const;

public:
   CAlertManager();
   void ConfigurePopup(const bool enabled);
   void ConfigureEmail(const string prefix,const string recipient,const bool enabled);
   void ConfigurePush(const string tag,const bool enabled);
   void ConfigureTelegram(const string botToken,const string chatId,const bool enabled,const int timeoutMs=5000);
   void SetRetries(const int retries);

   void NotifyTradeExecution(const ulong ticket,const string symbol,const ENUM_ORDER_TYPE type,const double lots,const double price,const double sl,const double tp,const string comment="");
   void NotifyRiskLimit(const string ruleName,const string details,const double currentValue,const double limitValue);
   void NotifyStrategySignal(const string strategy,const string symbol,const ENUM_ORDER_TYPE type,const double confidence);
   void NotifyCustom(const string category,const string message);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAlertManager::CAlertManager()
  {
   m_popup_enabled=true;
   m_email_enabled=false;
   m_push_enabled=false;
   m_telegram_enabled=false;
   m_email_recipient="";
   m_email_prefix="EA";
   m_push_tag="MT5";
   m_bot_token="";
   m_chat_id="";
   m_web_timeout=5000;
   m_retries=1;
  }

//+------------------------------------------------------------------+
//| Configuration helpers                                            |
//+------------------------------------------------------------------+
void CAlertManager::ConfigurePopup(const bool enabled)
  {
   m_popup_enabled=enabled;
  }

void CAlertManager::ConfigureEmail(const string prefix,const string recipient,const bool enabled)
  {
   m_email_prefix=prefix;
   m_email_recipient=recipient;
   m_email_enabled=enabled;
  }

void CAlertManager::ConfigurePush(const string tag,const bool enabled)
  {
   m_push_tag=tag;
   m_push_enabled=enabled;
  }

void CAlertManager::ConfigureTelegram(const string botToken,const string chatId,const bool enabled,const int timeoutMs)
  {
   m_bot_token=botToken;
   m_chat_id=chatId;
   m_telegram_enabled=enabled;
   m_web_timeout=timeoutMs;
  }

void CAlertManager::SetRetries(const int retries)
  {
   m_retries=MathMax(1,retries);
  }

//+------------------------------------------------------------------+
//| Notification entry points                                        |
//+------------------------------------------------------------------+
void CAlertManager::NotifyTradeExecution(const ulong ticket,const string symbol,const ENUM_ORDER_TYPE type,const double lots,const double price,const double sl,const double tp,const string comment)
  {
   string message=StringFormat("TRADE EXECUTED | ticket=%I64u symbol=%s type=%s lots=%.2f price=%.5f sl=%.5f tp=%.5f comment=%s",
                               ticket,symbol,OrderTypeToString(type),lots,price,sl,tp,comment);
   Dispatch("trade_execution",message);
  }

void CAlertManager::NotifyRiskLimit(const string ruleName,const string details,const double currentValue,const double limitValue)
  {
   string message=StringFormat("RISK LIMIT | rule=%s current=%.2f limit=%.2f details=%s",
                               ruleName,currentValue,limitValue,details);
   Dispatch("risk_limit",message);
  }

void CAlertManager::NotifyStrategySignal(const string strategy,const string symbol,const ENUM_ORDER_TYPE type,const double confidence)
  {
   string message=StringFormat("SIGNAL | strategy=%s symbol=%s direction=%s confidence=%.2f",
                               strategy,symbol,OrderTypeToString(type),confidence);
   Dispatch("strategy_signal",message);
  }

void CAlertManager::NotifyCustom(const string category,const string message)
  {
   Dispatch(category,message);
  }

//+------------------------------------------------------------------+
//| Dispatch core                                                    |
//+------------------------------------------------------------------+
bool CAlertManager::Dispatch(const string category,const string body) const
  {
   const string subject=BuildSubject(category);

   if(m_popup_enabled)
      SendPopup(body);

   if(m_email_enabled && StringLen(m_email_recipient)>0)
      SendEmail(subject,body);

   if(m_push_enabled)
      SendPush(StringFormat("%s | %s",subject,body));

   if(m_telegram_enabled)
      SendTelegram(StringFormat("%s\n%s",subject,body));

   return(true);
  }

//+------------------------------------------------------------------+
//| Low-level senders                                                |
//+------------------------------------------------------------------+
void CAlertManager::SendPopup(const string message) const
  {
   for(int i=0;i<m_retries;i++)
      Alert(message);
  }

void CAlertManager::SendEmail(const string subject,const string body) const
  {
   string decoratedSubject=subject;
   if(StringLen(m_email_recipient)>0)
      decoratedSubject=StringFormat("%s -> %s",subject,m_email_recipient);

   for(int i=0;i<m_retries;i++)
      SendMail(decoratedSubject,body);
  }

void CAlertManager::SendPush(const string message) const
  {
   for(int i=0;i<m_retries;i++)
      SendNotification(StringFormat("%s | %s",m_push_tag,message));
  }

bool CAlertManager::SendTelegram(const string message) const
  {
   if(!m_telegram_enabled || StringLen(m_bot_token)==0 || StringLen(m_chat_id)==0)
      return(false);

   string payload=StringFormat("chat_id=%s&text=%s",m_chat_id,UrlEncode(message));
   char data[];
   StringToCharArray(payload,data,0,WHOLE_ARRAY,CP_UTF8);
   char result[];
   string headers;
   ResetLastError();
   const string url="https://api.telegram.org/bot"+m_bot_token+"/sendMessage";
   const string requestHeader="Content-Type: application/x-www-form-urlencoded\r\n";
   const int response=WebRequest("POST",url,requestHeader,m_web_timeout,data,result,headers);
   if(response==-1)
     {
      PrintFormat("[Alerts] Telegram WebRequest error=%d",GetLastError());
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Subject builder                                                   |
//+------------------------------------------------------------------+
string CAlertManager::BuildSubject(const string category) const
  {
   if(StringLen(category)==0)
      return(m_email_prefix+" ALERT");

   return(StringFormat("%s %s",m_email_prefix,StringUpper(category)));
  }

//+------------------------------------------------------------------+
//| Order type helper                                                |
//+------------------------------------------------------------------+
string CAlertManager::OrderTypeToString(const ENUM_ORDER_TYPE type) const
  {
   switch(type)
     {
      case ORDER_TYPE_BUY:            return("BUY");
      case ORDER_TYPE_SELL:           return("SELL");
      case ORDER_TYPE_BUY_LIMIT:      return("BUY_LIMIT");
      case ORDER_TYPE_SELL_LIMIT:     return("SELL_LIMIT");
      case ORDER_TYPE_BUY_STOP:       return("BUY_STOP");
      case ORDER_TYPE_SELL_STOP:      return("SELL_STOP");
      case ORDER_TYPE_BUY_STOP_LIMIT: return("BUY_STOP_LIMIT");
      case ORDER_TYPE_SELL_STOP_LIMIT:return("SELL_STOP_LIMIT");
      default:                        return("UNKNOWN");
     }
  }

//+------------------------------------------------------------------+
//| URL encode helper                                                |
//+------------------------------------------------------------------+
string CAlertManager::UrlEncode(const string value) const
  {
   string encoded="";
   const int length=StringLen(value);
   for(int i=0;i<length;i++)
     {
      const ushort ch=StringGetCharacter(value,i);
      const bool safe=(ch>='0' && ch<='9') || (ch>='A' && ch<='Z') || (ch>='a' && ch<='z') || ch=='-' || ch=='_' || ch=='.' || ch=='~';
      if(safe)
         encoded+=CharToString(ch);
      else if(ch==' ')
         encoded+="+";
      else
         encoded+=StringFormat("%%%02X",ch);
     }

   return(encoded);
  }

//+------------------------------------------------------------------+
//| Global helper instance                                           |
//+------------------------------------------------------------------+
CAlertManager g_AlertManager;

void ConfigureDefaultAlerts()
  {
   g_AlertManager.ConfigurePopup(true);
   g_AlertManager.ConfigureEmail("EA","alerts@example.com",false);
   g_AlertManager.ConfigurePush("MT5",false);
  }

//+------------------------------------------------------------------+
