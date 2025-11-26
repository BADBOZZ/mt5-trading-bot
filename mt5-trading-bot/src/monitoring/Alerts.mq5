#property strict

#define TELEGRAM_API_HOST   "https://api.telegram.org/bot"

class CAlertingService
  {
private:
   bool              m_usePopup;
   bool              m_useEmail;
   bool              m_usePush;
   string            m_emailSubjectPrefix;
   string            m_strategy;
   string            m_telegramToken;
   string            m_telegramChatId;
   datetime          m_lastDailyReport;

public:
                     CAlertingService(void)
     {
      m_usePopup            = true;
      m_useEmail            = false;
      m_usePush             = false;
      m_emailSubjectPrefix  = "MT5 Alert";
      m_strategy            = "Strategy";
      m_telegramToken       = "";
      m_telegramChatId      = "";
      m_lastDailyReport     = 0;
     }

   void              Configure(const bool popupEnabled,
                               const bool emailEnabled,
                               const bool pushEnabled,
                               const string subjectPrefix,
                               const string strategyName)
     {
      m_usePopup           = popupEnabled;
      m_useEmail           = emailEnabled;
      m_usePush            = pushEnabled;
      m_emailSubjectPrefix = subjectPrefix;
      m_strategy           = strategyName;
     }

   void              ConfigureTelegram(const string token, const string chatId)
     {
      m_telegramToken = token;
      m_telegramChatId = chatId;
     }

   // --- Trade execution alerts -------------------------------------------------
   void              NotifyTradeExecution(const ulong ticket,
                                          const string symbol,
                                          const ENUM_ORDER_TYPE type,
                                          const double volume,
                                          const double price,
                                          const string reason)
     {
      string title = StringFormat("%s | Trade %s", m_strategy, EnumToString(type));
      string body  = StringFormat("Ticket %I64u %s %.2f @ %s. %s",
                                  ticket,
                                  symbol,
                                  volume,
                                  DoubleToString(price, (int)_Digits),
                                  reason);
      Dispatch(title, body, true);
     }

   // --- Risk alerts ------------------------------------------------------------
   void              NotifyRiskLimitBreach(const string limitName,
                                           const double currentValue,
                                           const double limitValue,
                                           const string action)
     {
      string subject = StringFormat("%s | Risk limit", m_strategy);
      string body    = StringFormat("%s breached. Current %.2f vs limit %.2f. Action: %s",
                                    limitName,
                                    currentValue,
                                    limitValue,
                                    action);
      Dispatch(subject, body, true);
     }

   // --- Strategy signal alerts -------------------------------------------------
   void              NotifyStrategySignal(const string strategy,
                                          const string signalName,
                                          const ENUM_ORDER_TYPE direction,
                                          const double score,
                                          const string context)
     {
      string subject = StringFormat("%s | Signal %s", strategy, signalName);
      string body    = StringFormat("Direction %s score %.2f. %s",
                                    EnumToString(direction),
                                    score,
                                    context);
      Dispatch(subject, body, false);
     }

   // --- Telegram specific helpers ---------------------------------------------
   void              SendTelegramTradeDigest(const string summary)
     {
      if(summary == "")
         return;
      SendTelegramMessage("Trade digest:\n" + summary);
     }

   void              SendTelegramRiskWarning(const string warning)
     {
      if(warning == "")
         return;
      SendTelegramMessage("⚠️ Risk warning\n" + warning);
     }

   void              SendTelegramDailyPerformance(const double pnl,
                                                  const double winRate,
                                                  const double maxDrawdown)
     {
      datetime today = DateOfDay(TimeCurrent());
      if(m_lastDailyReport == today)
         return;

      m_lastDailyReport = today;
      string message = StringFormat("Daily report (%s)\nPnL: %.2f\nWin rate: %.2f%%\nMax DD: %.2f%%",
                                    TimeToString(TimeCurrent(), TIME_DATE),
                                    pnl,
                                    winRate,
                                    maxDrawdown);
      SendTelegramMessage(message);
     }

private:
   void              Dispatch(const string subject, const string body, const bool highPriority)
     {
      string composed = subject + ": " + body;

      if(m_usePopup)
         Alert(composed);

      if(m_usePush)
         SendNotification(composed);

      if(m_useEmail && TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
        {
         string emailSubject = m_emailSubjectPrefix + " - " + subject;
         SendMail(emailSubject, body);
        }

      SendTelegramMessage(composed);

      if(highPriority)
         Print("ALERT: ", composed);
     }

   datetime          DateOfDay(const datetime value) const
     {
      MqlDateTime ts;
      TimeToStruct(value, ts);
      ts.hour   = 0;
      ts.min    = 0;
      ts.sec    = 0;
      return StructToTime(ts);
     }

   bool              SendTelegramMessage(const string message)
     {
      if(m_telegramToken == "" || m_telegramChatId == "")
         return false;

      string url = TELEGRAM_API_HOST + m_telegramToken + "/sendMessage";
      string payload = "chat_id=" + m_telegramChatId + "&text=" + UrlEncode(message);

      uchar data[];
      StringToCharArray(payload, data);
      ResetLastError();

      uchar result[];
      string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
      string resultHeaders;
      int status = WebRequest("POST",
                              url,
                              headers,
                              10000,
                              data,
                              ArraySize(data) - 1,
                              result,
                              resultHeaders);

      if(status != 200)
        {
         PrintFormat("Telegram alert failed. Status %d, error %d", status, GetLastError());
         return false;
        }

      return true;
     }

   string            UrlEncode(const string value) const
     {
      string encoded = "";
      const int length = StringLen(value);

      for(int i = 0; i < length; i++)
        {
         ushort ch = (ushort)StringGetCharacter(value, i);

         if((ch >= 'A' && ch <= 'Z') ||
            (ch >= 'a' && ch <= 'z') ||
            (ch >= '0' && ch <= '9') ||
            ch == '-' || ch == '_' || ch == '.' || ch == '~')
           {
            encoded += (string)CharToString((uchar)ch);
           }
         else if(ch == ' ')
           {
            encoded += "+";
           }
         else
           {
            encoded += StringFormat("%%%02X", ch);
           }
        }

      return encoded;
     }
  };
