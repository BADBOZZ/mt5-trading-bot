//+------------------------------------------------------------------+
//| Logger.mq5                                                      |
//| Monitoring logger utilities for MT5 Expert Advisors              |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Message categories handled by the logger                         |
//+------------------------------------------------------------------+
enum ENUM_LOGGER_CHANNEL
  {
   LOGGER_TRADE = 0,
   LOGGER_ERROR,
   LOGGER_PERFORMANCE,
   LOGGER_SIGNAL,
   LOGGER_CUSTOM
  };

//+------------------------------------------------------------------+
//| Snapshot for performance logging                                 |
//+------------------------------------------------------------------+
struct SPerformanceSnapshot
  {
   datetime timestamp;
   double   balance;
   double   equity;
   double   drawdown;
   double   win_rate;
   double   profit_factor;
  };

//+------------------------------------------------------------------+
//| Monitoring logger class                                          |
//+------------------------------------------------------------------+
class CMonitoringLogger
  {
private:
   string   m_directory;
   string   m_file_prefix;
   bool     m_initialized;
   int      m_max_file_size;

   bool     EnsureDirectory();
   string   BuildPath(const string suffix) const;
   bool     WriteLine(const string suffix,const string line);
   void     RotateIfNeeded(const string suffix);
   string   Timestamp() const;
   string   OrderTypeToString(const ENUM_ORDER_TYPE type) const;

public:
   CMonitoringLogger();
   bool   Init(const string directory="Monitoring",const string prefix="monitor",const int maxFileSizeKb=5120);
   void   Shutdown();
   void   LogTrade(const ulong ticket,const string symbol,const ENUM_ORDER_TYPE type,const double lots,const double price,const double sl,const double tp,const string comment="");
   void   LogError(const int errorCode,const string details);
   void   LogPerformance(const SPerformanceSnapshot &snapshot);
   void   LogSignal(const string strategy,const string symbol,const ENUM_ORDER_TYPE direction,const double price,const string reason);
   void   LogCustom(const string suffix,const string payload);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMonitoringLogger::CMonitoringLogger()
  {
   m_directory="Monitoring";
   m_file_prefix="monitor";
   m_initialized=false;
   m_max_file_size=5120;
  }

//+------------------------------------------------------------------+
//| Initialize directory / settings                                  |
//+------------------------------------------------------------------+
bool CMonitoringLogger::Init(const string directory,const string prefix,const int maxFileSizeKb)
  {
   m_directory=directory;
   if(StringLen(m_directory)==0)
      m_directory="Monitoring";

   m_file_prefix=prefix;
   if(StringLen(m_file_prefix)==0)
      m_file_prefix="monitor";

   m_max_file_size=MathMax(512,maxFileSizeKb); // guard minimum

   m_initialized=EnsureDirectory();
   if(!m_initialized)
     {
      PrintFormat("[Logger] Failed to prepare directory '%s' (error=%d)",m_directory,GetLastError());
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Release resources                                                |
//+------------------------------------------------------------------+
void CMonitoringLogger::Shutdown()
  {
   m_initialized=false;
  }

//+------------------------------------------------------------------+
//| Ensure directory exists inside MQL5/Files                        |
//+------------------------------------------------------------------+
bool CMonitoringLogger::EnsureDirectory()
  {
   ResetLastError();
   if(FolderCreate(m_directory))
      return(true);

   const int err=GetLastError();
   if(err==5010) // already exists
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
//| Build full relative path                                         |
//+------------------------------------------------------------------+
string CMonitoringLogger::BuildPath(const string suffix) const
  {
   string fileName=m_file_prefix+"_"+suffix+".log";
   if(StringLen(m_directory)==0)
      return(fileName);

   return(m_directory+"\\"+fileName);
  }

//+------------------------------------------------------------------+
//| Rotate file when exceeding max size                              |
//+------------------------------------------------------------------+
void CMonitoringLogger::RotateIfNeeded(const string suffix)
  {
   const string path=BuildPath(suffix);
   if(!FileIsExist(path))
      return;

   int handle=FileOpen(path,FILE_READ|FILE_BIN|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE)
      return;

   const long size=FileSize(handle);
   FileClose(handle);

   if(size<m_max_file_size*1024)
      return;

   const string rotated=path+"."+TimeToString(TimeLocal(),TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   if(!FileMove(path,rotated,FILE_REWRITE))
      PrintFormat("[Logger] Failed to rotate %s -> %s (error=%d)",path,rotated,GetLastError());
  }

//+------------------------------------------------------------------+
//| Generic write helper                                             |
//+------------------------------------------------------------------+
bool CMonitoringLogger::WriteLine(const string suffix,const string line)
  {
   if(!m_initialized)
      return(false);

   RotateIfNeeded(suffix);

   const string path=BuildPath(suffix);
   const int handle=FileOpen(path,FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("[Logger] Unable to open %s (error=%d)",path,GetLastError());
      return(false);
     }

   FileSeek(handle,0,SEEK_END);
   FileWriteString(handle,line+"\r\n");
   FileClose(handle);
   return(true);
  }

//+------------------------------------------------------------------+
//| Timestamp helper                                                 |
//+------------------------------------------------------------------+
string CMonitoringLogger::Timestamp() const
  {
   return(TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
//| Convert order type                                               |
//+------------------------------------------------------------------+
string CMonitoringLogger::OrderTypeToString(const ENUM_ORDER_TYPE type) const
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
//| Log trade executions                                             |
//+------------------------------------------------------------------+
void CMonitoringLogger::LogTrade(const ulong ticket,const string symbol,const ENUM_ORDER_TYPE type,const double lots,const double price,const double sl,const double tp,const string comment)
  {
   string payload=StringFormat("%s | ticket=%I64u symbol=%s type=%s lots=%.2f price=%.5f sl=%.5f tp=%.5f comment=%s",
                               Timestamp(),ticket,symbol,OrderTypeToString(type),lots,price,sl,tp,comment);
   WriteLine("trades",payload);
  }

//+------------------------------------------------------------------+
//| Log errors                                                       |
//+------------------------------------------------------------------+
void CMonitoringLogger::LogError(const int errorCode,const string details)
  {
   string payload=StringFormat("%s | error=%d details=%s",Timestamp(),errorCode,details);
   WriteLine("errors",payload);
  }

//+------------------------------------------------------------------+
//| Log performance snapshots                                        |
//+------------------------------------------------------------------+
void CMonitoringLogger::LogPerformance(const SPerformanceSnapshot &snapshot)
  {
   string payload=StringFormat("%s | balance=%.2f equity=%.2f dd=%.2f win_rate=%.2f profit_factor=%.2f",
                               TimeToString(snapshot.timestamp,TIME_DATE|TIME_SECONDS),
                               snapshot.balance,
                               snapshot.equity,
                               snapshot.drawdown,
                               snapshot.win_rate,
                               snapshot.profit_factor);
   WriteLine("performance",payload);
  }

//+------------------------------------------------------------------+
//| Log strategy signals                                             |
//+------------------------------------------------------------------+
void CMonitoringLogger::LogSignal(const string strategy,const string symbol,const ENUM_ORDER_TYPE direction,const double price,const string reason)
  {
   string payload=StringFormat("%s | strategy=%s symbol=%s direction=%s price=%.5f reason=%s",
                               Timestamp(),strategy,symbol,OrderTypeToString(direction),price,reason);
   WriteLine("signals",payload);
  }

//+------------------------------------------------------------------+
//| Custom log helper                                                |
//+------------------------------------------------------------------+
void CMonitoringLogger::LogCustom(const string suffix,const string payload)
  {
   WriteLine(suffix,payload);
  }

//+------------------------------------------------------------------+
//| Global instance helper (optional)                                |
//+------------------------------------------------------------------+
CMonitoringLogger g_MonitorLogger;

bool InitMonitoringLogger()
  {
   return(g_MonitorLogger.Init());
  }

void ShutdownMonitoringLogger()
  {
   g_MonitorLogger.Shutdown();
  }

//+------------------------------------------------------------------+
