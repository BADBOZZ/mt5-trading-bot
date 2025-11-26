#property strict
#ifndef __LOGGER_MQ5__
#define __LOGGER_MQ5__

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Configuration structure for the monitoring logger               |
//+------------------------------------------------------------------+
class LoggerSettings
  {
public:
   string            RootFolder;
   string            FilePrefix;
   bool              UseDateFolders;
   bool              MirrorToJournal;
   bool              IncludeMilliseconds;

                     LoggerSettings(void)
     {
      RootFolder="monitoring";
      FilePrefix="session";
      UseDateFolders=true;
      MirrorToJournal=true;
      IncludeMilliseconds=false;
     }
  };

//+------------------------------------------------------------------+
//| Central logging utility for monitoring signals and performance  |
//+------------------------------------------------------------------+
class MonitoringLogger
  {
private:
   LoggerSettings    m_cfg;
   datetime          m_sessionStart;
   string            m_cachedFolder;

   string NormalizePath(const string value)
     {
      string path=value;
      if(StringLen(path)==0)
         path="monitoring";
      StringReplace(path,"/","\\");
      while(StringFind(path,"\\\\")>=0)
         StringReplace(path,"\\\\","\\");
      return path;
     }

   string ComposeFolder(void)
     {
      string folder=NormalizePath(m_cfg.RootFolder);
      if(m_cfg.UseDateFolders)
        {
         string dateStr=TimeToString(m_sessionStart,TIME_DATE);
         folder=folder+"\\"+dateStr;
        }
      m_cachedFolder=folder;
      return folder;
     }

   string ComposeFilePath(const string suffix)
     {
      string folder=(StringLen(m_cachedFolder)>0)?m_cachedFolder:ComposeFolder();
      string fileName=m_cfg.FilePrefix+"_"+suffix;
      return folder+"\\"+fileName;
     }

   bool EnsureFolder(void)
     {
      string folder=(StringLen(m_cachedFolder)>0)?m_cachedFolder:ComposeFolder();
      if(FileIsExist(folder,FILE_COMMON))
         return true;
      if(FolderCreate(folder,FILE_COMMON))
         return true;
      int err=GetLastError();
      PrintFormat("[Logger] Failed to create folder %s (error %d)",folder,err);
      return false;
     }

   string FormatCsvField(string value)
     {
      if(StringLen(value)==0)
         return "";
      StringReplace(value,"\"","\"\"");
      if(StringFind(value,",")>=0 || StringFind(value,";")>=0 || StringFind(value,"\n")>=0)
         return "\""+value+"\"";
      return value;
     }

   string BuildCsv(string &fields[])
     {
      string row="";
      int count=ArraySize(fields);
      for(int i=0;i<count;i++)
        {
         if(i>0)
            row+=",";
         row+=FormatCsvField(fields[i]);
        }
      row+="\r\n";
      return row;
     }

   string FormatTimestamp(void)
     {
      datetime now=TimeCurrent();
      if(!m_cfg.IncludeMilliseconds)
         return TimeToString(now,TIME_DATE|TIME_SECONDS);

      MqlDateTime dt;
      TimeToStruct(now,dt);
      int millis=(int)(GetMicrosecondCount()%1000);
      return StringFormat("%04d-%02d-%02d %02d:%02d:%02d.%03d",dt.year,dt.mon,dt.day,dt.hour,dt.min,dt.sec,millis);
     }

   bool WriteRecord(const string suffix,string &fields[])
     {
      if(!EnsureFolder())
         return false;

      string path=ComposeFilePath(suffix);
      ResetLastError();
      int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
      if(handle==INVALID_HANDLE)
        {
         int err=GetLastError();
         PrintFormat("[Logger] Unable to open %s (error %d)",path,err);
         return false;
        }
      FileSeek(handle,0,SEEK_END);
      string row=BuildCsv(fields);
      bool ok=(FileWriteString(handle,row)>0);
      FileClose(handle);
      if(!ok)
        {
         int err=GetLastError();
         PrintFormat("[Logger] Failed to write row to %s (error %d)",path,err);
        }
      return ok;
     }

   void MirrorToJournal(const string category,const string payload)
     {
      if(!m_cfg.MirrorToJournal)
         return;
      PrintFormat("[Logger][%s] %s",category,payload);
     }

   int DetectDigits(const string symbol)
     {
      int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      if(digits<=0)
         digits=(int)_Digits;
      if(digits<0)
         digits=5;
      return digits;
     }

   string SeverityLabel(const int code) const
     {
      if(code==0)
         return "INFO";
      if(code>0 && code<1000)
         return "WARN";
      return "ERROR";
     }

public:
                     MonitoringLogger(void)
     {
      m_sessionStart=TimeCurrent();
      m_cfg=LoggerSettings();
      m_cachedFolder="";
     }

   void             Configure(const LoggerSettings &settings)
     {
      m_cfg=settings;
      if(StringLen(m_cfg.RootFolder)==0)
         m_cfg.RootFolder="monitoring";
      if(StringLen(m_cfg.FilePrefix)==0)
         m_cfg.FilePrefix="session";
      m_sessionStart=TimeCurrent();
      m_cachedFolder="";
      EnsureFolder();
     }

   bool             LogTrade(const string strategyId,const string symbol,const ENUM_ORDER_TYPE orderType,
                             const double volume,const double price,const double sl,const double tp,
                             const ulong ticket,const double profit,const double balanceAfter,
                             const double equityAfter,const string comment)
     {
      string row[];
      if(ArrayResize(row,13)!=13)
         return false;
      int digits=DetectDigits(symbol);
      row[0]=FormatTimestamp();
      row[1]=strategyId;
      row[2]=symbol;
      row[3]=EnumToString(orderType);
      row[4]=DoubleToString(volume,2);
      row[5]=DoubleToString(price,digits);
      row[6]=DoubleToString(sl,digits);
      row[7]=DoubleToString(tp,digits);
      row[8]=(string)ticket;
      row[9]=DoubleToString(profit,2);
      row[10]=DoubleToString(balanceAfter,2);
      row[11]=DoubleToString(equityAfter,2);
      row[12]=comment;
      bool ok=WriteRecord("trades.csv",row);
      if(ok)
         MirrorToJournal("TRADE",StringFormat("%s %s %s vol %.2f profit %.2f",strategyId,symbol,row[3],volume,profit));
      return ok;
     }

   bool             LogError(const string source,const string message,const int code=GetLastError())
     {
      string row[];
      if(ArrayResize(row,5)!=5)
         return false;
      row[0]=FormatTimestamp();
      row[1]=source;
      row[2]=(string)code;
      row[3]=message;
      row[4]=SeverityLabel(code);
      bool ok=WriteRecord("errors.csv",row);
      MirrorToJournal("ERROR",StringFormat("%s (%d): %s",source,code,message));
      return ok;
     }

   bool             LogPerformance(const string strategyId,const double netProfit,const double balance,
                                   const double equity,const double winRate,const double maxDrawdown,
                                   const double sharpe,const double profitFactor)
     {
      string row[];
      if(ArrayResize(row,10)!=10)
         return false;
      row[0]=FormatTimestamp();
      row[1]=strategyId;
      row[2]=DoubleToString(netProfit,2);
      row[3]=DoubleToString(balance,2);
      row[4]=DoubleToString(equity,2);
      row[5]=DoubleToString(winRate,2);
      row[6]=DoubleToString(maxDrawdown,2);
      row[7]=DoubleToString(sharpe,2);
      row[8]=DoubleToString(profitFactor,2);
      row[9]=DoubleToString((equity-balance),2);
      bool ok=WriteRecord("performance.csv",row);
      if(ok)
         MirrorToJournal("PERF",StringFormat("%s net %.2f win %.2f%% PF %.2f",strategyId,netProfit,winRate,profitFactor));
      return ok;
     }

   bool             LogSignal(const string strategyId,const string symbol,const string signalType,
                              const double score,const double price,const double confidence,const string note)
     {
      string row[];
      if(ArrayResize(row,8)!=8)
         return false;
      int digits=DetectDigits(symbol);
      row[0]=FormatTimestamp();
      row[1]=strategyId;
      row[2]=symbol;
      row[3]=signalType;
      row[4]=DoubleToString(score,2);
      row[5]=DoubleToString(price,digits);
      row[6]=DoubleToString(confidence,2);
      row[7]=note;
      bool ok=WriteRecord("signals.csv",row);
      if(ok)
         MirrorToJournal("SIGNAL",StringFormat("%s %s score %.2f",strategyId,signalType,score));
      return ok;
     }
  };

#endif // __LOGGER_MQ5__
