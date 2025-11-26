#property copyright "Monitoring Toolkit"
#property link      "https://example.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Logger configuration structure                                   |
//+------------------------------------------------------------------+
struct LoggerConfig
  {
   string  directory;        // base folder under MQL5/Files/
   bool    echo_to_terminal; // mirror to experts log
   bool    echo_to_chart;    // mirror to Comment()
  };

//+------------------------------------------------------------------+
//| Logger class definition                                          |
//+------------------------------------------------------------------+
class Logger
  {
private:
   LoggerConfig m_cfg;

   string BuildPath(const string category) const
     {
      string today=TimeToString(TimeLocal(),TIME_DATE);
      return(StringFormat("%s\\%s_%s.csv",m_cfg.directory,category,today));
     }

   void EnsureDirectory() const
     {
      if(m_cfg.directory=="")
         return;
      if(!FolderCreate(m_cfg.directory))
        {
         PrintFormat("Logger: unable to create directory %s (error %d)",m_cfg.directory,GetLastError());
        }
     }

public:
                     Logger()
     {
      m_cfg.directory="MonitoringLogs";
      m_cfg.echo_to_terminal=true;
      m_cfg.echo_to_chart=false;
      EnsureDirectory();
     }

   void Configure(const LoggerConfig &cfg)
     {
      m_cfg=cfg;
      if(m_cfg.directory=="")
         m_cfg.directory="MonitoringLogs";
      EnsureDirectory();
     }

   void WriteRow(const string category,
                 const string severity,
                 const string context,
                 const string field1="",
                 const string field2="",
                 const string field3="") const
     {
      string path=BuildPath(category);
      int handle=FileOpen(path,FILE_WRITE|FILE_READ|FILE_TXT|FILE_COMMON|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
        {
         PrintFormat("Logger: FileOpen failed for %s (error %d)",path,GetLastError());
         return;
        }

      FileSeek(handle,0,SEEK_END);
      string timestamp=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      FileWrite(handle,timestamp,severity,context,field1,field2,field3);
      FileFlush(handle);
      FileClose(handle);

      if(m_cfg.echo_to_terminal)
         PrintFormat("[LOG][%s][%s] %s",category,severity,context);
      if(m_cfg.echo_to_chart)
        {
         string existing=Comment();
         Comment(StringFormat("%s\n[%s][%s] %s",existing,category,severity,context));
        }
     }

   void LogTrade(const ulong ticket,
                 const string action,
                 const double volume,
                 const double price,
                 const string status,
                 const string comment="") const
     {
      string context=StringFormat("Trade %s ticket %I64u",action,ticket);
      string vol=DoubleToString(volume,2);
      string prc=DoubleToString(price,_Digits);
      WriteRow("trade","INFO",context,StringFormat("price=%s",prc),StringFormat("volume=%s",vol),StringFormat("status=%s %s",status,comment));
     }

   void LogError(const string source,
                 const string message,
                 const int error_code=0) const
     {
      int code=(error_code==0 ? GetLastError():error_code);
      WriteRow("error","ERROR",source,message,StringFormat("code=%d",code));
     }

   void LogPerformance(const string metric,
                       const double value,
                       const string strategy="global",
                       const string period="session") const
     {
      WriteRow("performance","INFO",metric,StringFormat("value=%s",DoubleToString(value,4)),StringFormat("strategy=%s",strategy),StringFormat("period=%s",period));
     }

   void LogSignal(const string strategy,
                  const string signal,
                  const double strength,
                  const string timeframe) const
     {
      WriteRow("signal","INFO",StringFormat("%s -> %s",strategy,signal),StringFormat("strength=%.2f",strength),StringFormat("tf=%s",timeframe));
     }
  };

// Global instance for quick usage
Logger g_logger;

// Helper initialization call for EAs/Indicators
void InitializeLogger(const string directory="MonitoringLogs",
                      const bool echo_terminal=true,
                      const bool echo_chart=false)
  {
   LoggerConfig cfg;
   cfg.directory=directory;
   cfg.echo_to_terminal=echo_terminal;
   cfg.echo_to_chart=echo_chart;
   g_logger.Configure(cfg);
  }

// Convenience wrappers -------------------------------------------------
void LogTradeEvent(const ulong ticket,const string action,const double volume,const double price,const string status,const string comment="")
  {
   g_logger.LogTrade(ticket,action,volume,price,status,comment);
  }

void LogStrategySignal(const string strategy,const string signal,const double strength,const string timeframe)
  {
   g_logger.LogSignal(strategy,signal,strength,timeframe);
  }

void LogPerformanceMetric(const string metric,const double value,const string strategy="global",const string period="session")
  {
   g_logger.LogPerformance(metric,value,strategy,period);
  }

void LogErrorEvent(const string source,const string message,const int code=0)
  {
   g_logger.LogError(source,message,code);
  }
