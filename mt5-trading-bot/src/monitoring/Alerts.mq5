#property strict
#ifndef __ALERTS_MQ5__
#define __ALERTS_MQ5__

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Configuration for alert and notification delivery               |
//+------------------------------------------------------------------+
struct AlertServiceConfig
  {
   bool              EnablePopup;
   bool              EnableEmail;
   bool              EnablePush;
   bool              EnableTelegram;
   string            EmailSubjectPrefix;
   string            TelegramBotToken;
   string            TelegramChatId;
   int               TelegramTimeoutMs;
   int               TradeThrottleSec;
   int               RiskThrottleSec;
   int               SignalThrottleSec;
   int               PerfThrottleSec;

                     AlertServiceConfig(void)
     {
      EnablePopup=true;
      EnableEmail=false;
      EnablePush=false;
      EnableTelegram=false;
      EmailSubjectPrefix="MT5 Bot | ";
      TelegramBotToken="";
      TelegramChatId="";
      TelegramTimeoutMs=5000;
      TradeThrottleSec=3;
      RiskThrottleSec=1;
      SignalThrottleSec=1;
      PerfThrottleSec=300;
     }
  };

//+------------------------------------------------------------------+
//| Alerting and notification service                               |
//+------------------------------------------------------------------+
class AlertService
  {
private:
   AlertServiceConfig m_cfg;
   datetime           m_lastTradeAlert;
   datetime           m_lastRiskAlert;
   datetime           m_lastSignalAlert;
   datetime           m_lastPerfAlert;
   int                m_failedAttempts;

   bool ShouldThrottle(const datetime lastAlert,const int throttleSec) const
     {
      if(throttleSec<=0 || lastAlert==0)
         return false;
      datetime now=TimeCurrent();
      return (now-lastAlert)<throttleSec;
     }

   string NormalizeNote(const string text)
     {
      if(StringLen(text)>0)
         return text;
      return "n/a";
     }

   bool Dispatch(const string category,const string payload)
     {
      bool delivered=false;
      string message=StringFormat("[%s] %s",category,payload);

      if(m_cfg.EnablePopup)
        {
         Alert(message);
         delivered=true;
        }

      if(m_cfg.EnablePush)
        {
         if(SendNotification(message))
            delivered=true;
        }

      if(m_cfg.EnableEmail)
        {
         ResetLastError();
         string subject=m_cfg.EmailSubjectPrefix+category;
         if(SendMail(subject,payload))
            delivered=true;
         else
           {
            int err=GetLastError();
            PrintFormat("[Alerts] SendMail failed (%d)",err);
           }
        }

      if(m_cfg.EnableTelegram)
        {
         if(SendTelegram(category,payload))
            delivered=true;
        }

      if(!delivered)
         PrintFormat("[Alerts] No channels delivered message: %s",message);

      return delivered;
     }

   string UrlEncode(const string value)
     {
      string encoded="";
      ushort buffer[];
      int total=StringToCharArray(value,buffer);
      if(total<=0)
         return encoded;
      int limit=total-1;
      for(int i=0;i<limit;i++)
        {
         ushort c=buffer[i];
         if((c>='0' && c<='9') || (c>='A' && c<='Z') || (c>='a' && c<='z') || c=='-' || c=='_' || c=='.')
            encoded+=CharToString((uchar)c);
         else if(c==' ')
            encoded+="+";
         else
            encoded+=StringFormat("%%%02X",c);
        }
      return encoded;
     }

   bool SendTelegram(const string category,const string payload)
     {
      if(!m_cfg.EnableTelegram || StringLen(m_cfg.TelegramBotToken)==0 || StringLen(m_cfg.TelegramChatId)==0)
         return false;

      string url=StringFormat("https://api.telegram.org/bot%s/sendMessage",m_cfg.TelegramBotToken);
      string body=StringFormat("chat_id=%s&parse_mode=HTML&text=%s",
                               m_cfg.TelegramChatId,
                               UrlEncode(StringFormat("<b>%s</b>\n%s",category,payload)));

      char data[];
      int copied=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8);
      if(copied>0)
         ArrayResize(data,copied-1);

      ResetLastError();
      string response="";
      int status=WebRequest("POST",url,"Content-Type: application/x-www-form-urlencoded\r\n",m_cfg.TelegramTimeoutMs,data,response);
      if(status==-1)
        {
         int err=GetLastError();
         PrintFormat("[Alerts] Telegram request failed (%d). Allow the domain in terminal settings.",err);
         m_failedAttempts++;
         return false;
        }

      bool ok=(status>=200 && status<300);
      if(!ok)
         PrintFormat("[Alerts] Telegram returned status %d, response: %s",status,response);
      return ok;
     }

public:
                     AlertService(void)
     {
      m_cfg=AlertServiceConfig();
      m_lastTradeAlert=0;
      m_lastRiskAlert=0;
      m_lastSignalAlert=0;
      m_lastPerfAlert=0;
      m_failedAttempts=0;
     }

   void             Configure(const AlertServiceConfig &config)
     {
      m_cfg=config;
     }

   bool             NotifyTradeExecution(const string strategyId,const string symbol,const ENUM_ORDER_TYPE orderType,
                                         const double volume,const double price,const double profit,const ulong ticket,
                                         const double balance,const double equity,const string note="",const bool forceSend=false)
     {
      if(!forceSend && ShouldThrottle(m_lastTradeAlert,m_cfg.TradeThrottleSec))
         return false;

      int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      if(digits<=0)
         digits=(int)_Digits;
      string priceStr=DoubleToString(price,digits);

      string payload=StringFormat("Strategy %s executed %s %s @ %s (%s lots) profit %.2f (ticket %I64u) | bal %.2f eq %.2f | %s",
                                  strategyId,
                                  EnumToString(orderType),
                                  symbol,
                                  priceStr,
                                  DoubleToString(volume,2),
                                  profit,
                                  ticket,
                                  balance,
                                  equity,
                                  NormalizeNote(note));

      bool delivered=Dispatch("TRADE",payload);
      if(delivered)
         m_lastTradeAlert=TimeCurrent();
      return delivered;
     }

   bool             NotifyRiskLimit(const string limitName,const string symbol,const double currentValue,
                                    const double limitValue,const string direction,const string note="",const bool forceSend=false)
     {
      if(!forceSend && ShouldThrottle(m_lastRiskAlert,m_cfg.RiskThrottleSec))
         return false;

      string payload=StringFormat("%s on %s breached %s limit %.2f vs %.2f | %s",
                                  direction,
                                  symbol,
                                  limitName,
                                  currentValue,
                                  limitValue,
                                  NormalizeNote(note));
      bool delivered=Dispatch("RISK",payload);
      if(delivered)
         m_lastRiskAlert=TimeCurrent();
      return delivered;
     }

   bool             NotifyStrategySignal(const string strategyId,const string symbol,const string signalType,
                                         const double score,const double confidence,const string note="",const bool forceSend=false)
     {
      if(!forceSend && ShouldThrottle(m_lastSignalAlert,m_cfg.SignalThrottleSec))
         return false;

      string payload=StringFormat("%s signalled %s on %s | score %.2f conf %.2f | %s",
                                  strategyId,
                                  signalType,
                                  symbol,
                                  score,
                                  confidence,
                                  NormalizeNote(note));
      bool delivered=Dispatch("SIGNAL",payload);
      if(delivered)
         m_lastSignalAlert=TimeCurrent();
      return delivered;
     }

   bool             SendPerformanceReport(const string title,const string summary,const double dailyReturn,
                                          const double maxDrawdown,const double equity,const bool forceSend=false)
     {
      if(!forceSend && ShouldThrottle(m_lastPerfAlert,m_cfg.PerfThrottleSec))
         return false;

      string payload=StringFormat("%s | Return %.2f%% | DD %.2f%% | Equity %.2f | %s",
                                  title,
                                  dailyReturn,
                                  maxDrawdown,
                                  equity,
                                  summary);
      bool delivered=Dispatch("PERFORMANCE",payload);
      if(delivered)
         m_lastPerfAlert=TimeCurrent();
      return delivered;
     }

   bool             SendTelegramMessage(const string category,const string payload)
     {
      return SendTelegram(category,payload);
     }

   int              FailureCount(void) const
     {
      return m_failedAttempts;
     }
  };

#endif // __ALERTS_MQ5__
