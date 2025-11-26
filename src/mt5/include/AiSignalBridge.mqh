#pragma once

struct AiSignal
  {
   datetime          timestamp;
   double            buy_score;
   double            sell_score;
   double            trend;
   double            volatility;
   string            action;
  };

class AiSignalBridge
  {
private:
   AiSignal          m_latest;
   string            m_file_name;
public:
                     AiSignalBridge(const string file_name="ai_signals.csv")
     {
      m_file_name=file_name;
      ResetSignal();
     }

   void              ResetSignal()
     {
      m_latest.timestamp=0;
      m_latest.buy_score=0.5;
      m_latest.sell_score=0.5;
      m_latest.trend=0;
      m_latest.volatility=0;
      m_latest.action="HOLD";
     }

   bool              LoadLatest()
     {
      int handle=FileOpen(m_file_name,FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle==INVALID_HANDLE)
         return(false);

      string last_line="";
      while(!FileIsEnding(handle))
        {
         string line=FileReadString(handle);
         if(StringLen(line)==0 || StringFind(line,"timestamp")>=0)
            continue;
         last_line=line;
        }
      FileClose(handle);
      if(StringLen(last_line)==0)
         return(false);

      string parts[];
      int parts_total=StringSplit(last_line,',',parts);
      if(parts_total<6)
         return(false);

      m_latest.timestamp=StringToTime(parts[0]);
      m_latest.buy_score=(double)StringToDouble(parts[1]);
      m_latest.sell_score=(double)StringToDouble(parts[2]);
      m_latest.trend=(double)StringToDouble(parts[3]);
      m_latest.volatility=(double)StringToDouble(parts[4]);
      m_latest.action=parts[5];
      return(true);
     }

   AiSignal          Latest() const
     {
      return(m_latest);
     }

   void              SetFile(const string file_name)
     {
      m_file_name=file_name;
     }
  };
