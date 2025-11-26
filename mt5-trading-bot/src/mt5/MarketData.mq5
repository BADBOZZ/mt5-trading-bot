#include "Mt5Common.mqh"

#property strict

class MarketData
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_defaultTimeframe;
   int             m_retryDelay;
   int             m_maxRetries;

public:
   void Init(const string symbol, const ENUM_TIMEFRAMES timeframe = PERIOD_M1, const int retries = 3, const int retryDelayMs = 250)
   {
      m_symbol           = symbol;
      m_defaultTimeframe = timeframe;
      m_maxRetries       = MathMax(1, retries);
      m_retryDelay       = Mt5Common::NormalizeDelay(retryDelayMs, 50);
   }

   bool GetLastTick(MqlTick &tick) const
   {
      if(!EnsureConnection("GetLastTick"))
         return false;

      const string useSymbol = ResolveSymbol("");
      return SymbolInfoTick(useSymbol, tick);
   }

   int CopyRecentTicks(MqlTick &ticks[], const int requested, const ENUM_COPY_TICKS flags = COPY_TICKS_ALL) const
   {
      if(!EnsureConnection("CopyRecentTicks"))
         return 0;

      const string useSymbol = ResolveSymbol("");
      ResetLastError();
      int copied = CopyTicks(useSymbol, ticks, flags, 0, requested);
      if(copied <= 0)
         LogMarketError("CopyRecentTicks");
      return copied;
   }

   int CopyHistoricalTicks(MqlTick &ticks[], datetime from, const int requested, const ENUM_COPY_TICKS flags = COPY_TICKS_TRADE) const
   {
      if(!EnsureConnection("CopyHistoricalTicks"))
         return 0;

      const string useSymbol = ResolveSymbol("");
      ResetLastError();
      ulong start = (ulong)from;
      int copied = CopyTicks(useSymbol, ticks, flags, start, requested);
      if(copied <= 0)
         LogMarketError("CopyHistoricalTicks");
      return copied;
   }

   int CopyBars(MqlRates &rates[], const int count, const ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) const
   {
      if(!EnsureConnection("CopyBars"))
         return 0;

      const string useSymbol = ResolveSymbol("");
      const ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT ? m_defaultTimeframe : timeframe);

      ResetLastError();
      datetime timeStart = 0;
      int copied = CopyRates(useSymbol, tf, timeStart, count, rates);
      if(copied <= 0)
         LogMarketError("CopyBars");
      return copied;
   }

   int CopyBarsRange(MqlRates &rates[], datetime from, datetime to, const ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) const
   {
      if(from == 0 || to == 0 || to <= from)
      {
         Print("MarketData CopyBarsRange: invalid date range");
         return 0;
      }

      if(!EnsureConnection("CopyBarsRange"))
         return 0;

      const string useSymbol = ResolveSymbol("");
      const ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT ? m_defaultTimeframe : timeframe);

      ResetLastError();
      int copied = CopyRates(useSymbol, tf, from, to, rates);
      if(copied <= 0)
         LogMarketError("CopyBarsRange");
      return copied;
   }

   bool GetRateAt(const int shift, MqlRates &rate, const ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) const
   {
      if(!EnsureConnection("GetRateAt"))
         return false;

      MqlRates rates[];
      const int copied = CopyRates(ResolveSymbol(""), timeframe == PERIOD_CURRENT ? m_defaultTimeframe : timeframe, shift, 1, rates);
      if(copied <= 0)
      {
         LogMarketError("GetRateAt");
         return false;
      }
      rate = rates[0];
      return true;
   }

   bool GetSymbolInfo(MqlTick &tick, double &point, double &spread, double &lotStep) const
   {
      if(!EnsureConnection("GetSymbolInfo"))
         return false;

      const string useSymbol = ResolveSymbol("");
      if(!SymbolInfoTick(useSymbol, tick))
         return false;

      point   = SymbolInfoDouble(useSymbol, SYMBOL_POINT);
      spread  = SymbolInfoDouble(useSymbol, SYMBOL_SPREAD) * point;
      lotStep = SymbolInfoDouble(useSymbol, SYMBOL_VOLUME_STEP);
      return true;
   }

   bool GetOrderBook(MqlBookInfo &book[]) const
   {
      if(!EnsureConnection("GetOrderBook"))
         return false;

      ArrayFree(book);
      if(!MarketBookGet(ResolveSymbol(""), book))
      {
         LogMarketError("GetOrderBook");
         return false;
      }
      return true;
   }

   bool EnsureSymbolSelected(const string symbol = NULL) const
   {
      if(!EnsureConnection("EnsureSymbolSelected"))
         return false;

      const string useSymbol = ResolveSymbol(symbol);
      if(SymbolSelect(useSymbol, true))
         return true;

      LogMarketError("EnsureSymbolSelected");
      return false;
   }

private:
   string ResolveSymbol(const string symbol) const
   {
      if(symbol == NULL || symbol == "")
         return m_symbol;
      return symbol;
   }

   void LogMarketError(const string context) const
   {
      const int err = _LastError;
      Mt5Common::LogError("MarketData", context, err);
      ResetLastError();
      Sleep(m_retryDelay);
   }

   bool EnsureConnection(const string context) const
   {
      return Mt5Common::EnsureConnection("MarketData " + context, m_maxRetries, m_retryDelay);
   }
};
