#pragma once
//+------------------------------------------------------------------+
//| Utility to read AI-generated signals from CSV files             |
//+------------------------------------------------------------------+

struct AISignal
  {
   datetime          timestamp;
   string            direction;
   double            confidence;
   double            expected_return;
   double            volatility;
   double            prob_short;
   double            prob_flat;
   double            prob_long;
  };

class AISignalBridge
  {
private:
   string            m_filename;
   datetime          m_lastTimestamp;

   datetime          ParseTimestamp(const string raw) const
     {
      string normalized=raw;
      StringReplace(normalized,"T"," ");
      StringReplace(normalized,"Z","");
      return(StringToTime(normalized));
     }

public:
                     AISignalBridge(const string filename="ai_signals.csv")
     {
      m_filename=filename;
      m_lastTimestamp=0;
     }

   bool              Refresh(AISignal &signal)
     {
      ResetLastError();
      int handle=FileOpen(m_filename,FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle==INVALID_HANDLE)
         return(false);

      string line="";
      string last_line="";
      if(!FileIsEnding(handle))
         FileReadString(handle); // header

      while(!FileIsEnding(handle))
        {
         line=FileReadString(handle);
         if(StringLen(line)>0)
            last_line=line;
        }
      FileClose(handle);

      if(StringLen(last_line)==0)
         return(false);

      string parts[];
      int count=StringSplit(last_line,',',parts);
      if(count<8)
         return(false);

      datetime ts=ParseTimestamp(parts[0]);
      if(ts==0 || ts<=m_lastTimestamp)
         return(false);

      signal.timestamp=ts;
      signal.direction=parts[1];
      signal.confidence=StrToDouble(parts[2]);
      signal.expected_return=StrToDouble(parts[3]);
      signal.volatility=StrToDouble(parts[4]);
      signal.prob_short=StrToDouble(parts[5]);
      signal.prob_flat=StrToDouble(parts[6]);
      signal.prob_long=StrToDouble(parts[7]);
      m_lastTimestamp=ts;
      return(true);
     }
  };
