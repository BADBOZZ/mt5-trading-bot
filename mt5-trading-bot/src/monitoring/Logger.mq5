#property strict

#define LOGGER_SEPARATOR ";"

enum ENUM_LOG_LEVEL
  {
   LOG_LEVEL_INFO = 0,
   LOG_LEVEL_WARNING,
   LOG_LEVEL_ERROR
  };

class CTradeLogger
  {
private:
   string            m_prefix;
   string            m_tradeFile;
   string            m_errorFile;
   string            m_performanceFile;
   string            m_signalFile;
   string            m_folder;

public:
                     CTradeLogger(void)
     {
      m_prefix        = "EA";
      m_folder        = "monitoring";
      m_tradeFile     = "";
      m_errorFile     = "";
      m_performanceFile = "";
      m_signalFile    = "";
     }

   void              Init(const string prefix = "EA", const string folder = "monitoring")
     {
      m_prefix = prefix;
      m_folder = folder;

      string dateSuffix = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(dateSuffix, ".", "-");

      m_tradeFile       = BuildFileName("trades_" + dateSuffix + ".csv");
      m_errorFile       = BuildFileName("errors_" + dateSuffix + ".csv");
      m_performanceFile = BuildFileName("performance_" + dateSuffix + ".csv");
      m_signalFile      = BuildFileName("signals_" + dateSuffix + ".csv");
     }

   bool              LogTrade(const ulong ticket,
                              const string symbol,
                              const ENUM_ORDER_TYPE orderType,
                              const double volume,
                              const double price,
                              const double stopLoss,
                              const double takeProfit,
                              const string comment = "")
     {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(digits <= 0)
         digits = (int)_Digits;

      string columns[];
      ArrayResize(columns, 9);
      columns[0] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      columns[1] = LongToString(ticket);
      columns[2] = symbol;
      columns[3] = EnumToString(orderType);
      columns[4] = DoubleToString(volume, 2);
      columns[5] = DoubleToString(price, digits);
      columns[6] = DoubleToString(stopLoss, digits);
      columns[7] = DoubleToString(takeProfit, digits);
      columns[8] = comment;

      return AppendCsv(m_tradeFile,
                       "timestamp;ticket;symbol;type;volume;price;sl;tp;comment",
                       columns);
     }

   bool              LogError(const string location, const int errorCode, const string message, const ENUM_LOG_LEVEL level = LOG_LEVEL_ERROR)
     {
      string columns[];
      ArrayResize(columns, 5);
      columns[0] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      columns[1] = location;
      columns[2] = IntegerToString(errorCode);
      columns[3] = EnumToString(level);
      columns[4] = message;

      PrintFormat("Logger[%s]: (%d) %s - %s", location, errorCode, EnumToString(level), message);
      return AppendCsv(m_errorFile, "timestamp;location;code;level;message", columns);
     }

   bool              LogPerformance(const double balance,
                                    const double equity,
                                    const double netProfit,
                                    const double drawdown,
                                    const double winRate,
                                    const double sharpe,
                                    const double profitFactor)
     {
      string columns[];
      ArrayResize(columns, 8);
      columns[0] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      columns[1] = DoubleToString(balance, 2);
      columns[2] = DoubleToString(equity, 2);
      columns[3] = DoubleToString(netProfit, 2);
      columns[4] = DoubleToString(drawdown, 2);
      columns[5] = DoubleToString(winRate, 2);
      columns[6] = DoubleToString(sharpe, 2);
      columns[7] = DoubleToString(profitFactor, 2);

      return AppendCsv(m_performanceFile,
                       "timestamp;balance;equity;net_profit;drawdown;win_rate;sharpe;profit_factor",
                       columns);
     }

   bool              LogSignal(const string strategy,
                               const string signalName,
                               const ENUM_ORDER_TYPE expectedDirection,
                               const double strength,
                               const string notes = "")
     {
      string columns[];
      ArrayResize(columns, 6);
      columns[0] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      columns[1] = strategy;
      columns[2] = signalName;
      columns[3] = EnumToString(expectedDirection);
      columns[4] = DoubleToString(strength, 2);
      columns[5] = notes;

      return AppendCsv(m_signalFile,
                       "timestamp;strategy;signal;direction;strength;notes",
                       columns);
     }

private:
   string            BuildFileName(const string suffix) const
     {
      if(StringLen(m_folder) == 0)
         return m_prefix + "_" + suffix;

      return m_folder + "/" + m_prefix + "_" + suffix;
     }

   bool              AppendCsv(const string filename, const string header, string &columns[])
     {
      ResetLastError();
      int handle = FileOpen(filename, FILE_TXT | FILE_READ | FILE_WRITE | FILE_ANSI);
      if(handle == INVALID_HANDLE)
        {
         PrintFormat("Logger: failed to open %s. Error %d", filename, GetLastError());
         return false;
        }

      bool needsHeader = (FileSize(handle) == 0);
      FileSeek(handle, 0, SEEK_END);

      if(needsHeader && header != "")
        {
         FileWriteString(handle, header + "\r\n");
        }

      const int total = ArraySize(columns);
      string row = "";

      for(int i = 0; i < total; i++)
        {
         string cell = columns[i];
         StringReplace(cell, "\"", "\"\"");
         row += "\"" + cell + "\"";

         if(i < total - 1)
            row += LOGGER_SEPARATOR;
        }

      FileWriteString(handle, row + "\r\n");
      FileClose(handle);
      return true;
     }
  };
