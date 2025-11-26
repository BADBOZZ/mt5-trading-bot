#ifndef __ALERTS_MONITORING_MQH__
#define __ALERTS_MONITORING_MQH__

#define ALERT_DEFAULT_PREFIX "MT5Bot"

enum AlertSeverity
  {
   ALERT_SEVERITY_INFO     = 0,
   ALERT_SEVERITY_WARNING  = 1,
   ALERT_SEVERITY_CRITICAL = 2
  };

enum AlertChannelFlag
  {
   ALERT_CHANNEL_TERMINAL    = 1,
   ALERT_CHANNEL_NOTIFICATION= 2,
   ALERT_CHANNEL_EMAIL       = 4
  };

struct AlertThrottleEntry
  {
   string   code;
   datetime lastSent;
  };

class AlertManager
  {
private:
   int                m_channels;
   int                m_throttleSeconds;
   int                m_historyLimit;
   string             m_prefix;
   bool               m_enabled;
   AlertThrottleEntry m_history[];

public:
                     AlertManager(void);
   void              Configure(const int channels        = ALERT_CHANNEL_TERMINAL,
                               const int throttleSeconds = 15,
                               const string prefix       = ALERT_DEFAULT_PREFIX,
                               const int historyLimit    = 64);
   void              Enable(const bool enabled);
   bool              Raise(const string code,
                           const string message,
                           const AlertSeverity severity = ALERT_SEVERITY_INFO);
   bool              PulseMetric(const string code,
                                 const double value,
                                 const double warnThreshold,
                                 const double critThreshold,
                                 const string metricLabel);
   void              ClearHistory(void);

private:
   bool              ShouldThrottle(const string code) const;
   void              RecordSend(const string code);
   int               FindHistoryIndex(const string code) const;
   string            FormatMessage(const string code,
                                   const string message,
                                   const AlertSeverity severity) const;
   string            SeverityLabel(const AlertSeverity severity) const;
   void              PushTerminal(const string message) const;
   void              PushNotification(const string message) const;
   void              PushEmail(const string subject, const string body) const;
  };

AlertManager::AlertManager(void)
  {
   m_channels        = ALERT_CHANNEL_TERMINAL;
   m_throttleSeconds = 15;
   m_historyLimit    = 64;
   m_prefix          = ALERT_DEFAULT_PREFIX;
   m_enabled         = true;
   ArrayResize(m_history, 0);
  }

void AlertManager::Configure(const int channels,
                             const int throttleSeconds,
                             const string prefix,
                             const int historyLimit)
  {
   m_channels        = channels;
   m_throttleSeconds = MathMax(throttleSeconds, 0);
   m_prefix          = (StringLen(prefix) == 0 ? ALERT_DEFAULT_PREFIX : prefix);
   m_historyLimit    = MathMax(historyLimit, 1);
  }

void AlertManager::Enable(const bool enabled)
  {
   m_enabled = enabled;
  }

bool AlertManager::Raise(const string code,
                         const string message,
                         const AlertSeverity severity)
  {
   if(!m_enabled)
      return false;

   if(m_throttleSeconds > 0 && ShouldThrottle(code))
      return false;

   string formatted = FormatMessage(code, message, severity);
   string subject   = m_prefix + " " + SeverityLabel(severity) + " " + code;

   if((m_channels & ALERT_CHANNEL_TERMINAL) > 0)
      PushTerminal(formatted);

   if((m_channels & ALERT_CHANNEL_NOTIFICATION) > 0)
      PushNotification(formatted);

   if((m_channels & ALERT_CHANNEL_EMAIL) > 0)
      PushEmail(subject, formatted);

   RecordSend(code);
   return true;
  }

bool AlertManager::PulseMetric(const string code,
                               const double value,
                               const double warnThreshold,
                               const double critThreshold,
                               const string metricLabel)
  {
   AlertSeverity severity = ALERT_SEVERITY_INFO;

   if(value >= critThreshold)
      severity = ALERT_SEVERITY_CRITICAL;
   else if(value >= warnThreshold)
      severity = ALERT_SEVERITY_WARNING;
   else
      return false;

   string label = (StringLen(metricLabel) == 0 ? "metric" : metricLabel);
   string message = StringFormat("%s=%.4f (warn %.4f / crit %.4f)", label, value, warnThreshold, critThreshold);
   return Raise(code, message, severity);
  }

void AlertManager::ClearHistory(void)
  {
   ArrayResize(m_history, 0);
  }

bool AlertManager::ShouldThrottle(const string code) const
  {
   int index = FindHistoryIndex(code);
   if(index < 0)
      return false;

   datetime last = m_history[index].lastSent;
   if(last == 0)
      return false;

   return (TimeCurrent() - last) < m_throttleSeconds;
  }

void AlertManager::RecordSend(const string code)
  {
   datetime now = TimeCurrent();
   int index = FindHistoryIndex(code);

   if(index >= 0)
     {
      m_history[index].lastSent = now;
      return;
     }

   AlertThrottleEntry entry;
   entry.code     = code;
   entry.lastSent = now;

   int size = ArraySize(m_history);
   if(size >= m_historyLimit && size > 0)
     {
      for(int i = 1; i < size; i++)
         m_history[i - 1] = m_history[i];
      ArrayResize(m_history, size - 1);
      size = ArraySize(m_history);
     }

   ArrayResize(m_history, size + 1);
   m_history[size] = entry;
  }

int AlertManager::FindHistoryIndex(const string code) const
  {
   int size = ArraySize(m_history);
   for(int i = 0; i < size; i++)
     {
      if(m_history[i].code == code)
         return i;
     }
   return -1;
  }

string AlertManager::FormatMessage(const string code,
                                   const string message,
                                   const AlertSeverity severity) const
  {
   string prefix = "[" + SeverityLabel(severity) + "]";
   if(StringLen(code) > 0)
      prefix += " (" + code + ")";

   return prefix + " " + message;
  }

string AlertManager::SeverityLabel(const AlertSeverity severity) const
  {
   switch(severity)
     {
      case ALERT_SEVERITY_WARNING : return "WARN";
      case ALERT_SEVERITY_CRITICAL: return "CRIT";
      default:                      return "INFO";
     }
  }

void AlertManager::PushTerminal(const string message) const
  {
   Alert(message);
   Print(message);
  }

void AlertManager::PushNotification(const string message) const
  {
   if(!SendNotification(message))
      PrintFormat("AlertManager: push notification failed (%d)", GetLastError());
  }

void AlertManager::PushEmail(const string subject, const string body) const
  {
   if(!SendMail(subject, body))
      PrintFormat("AlertManager: email dispatch failed (%d)", GetLastError());
  }

#endif // __ALERTS_MONITORING_MQH__
