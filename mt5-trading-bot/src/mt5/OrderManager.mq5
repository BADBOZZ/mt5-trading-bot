#property strict

#include <Trade\Trade.mqh>
#include <stderror.mqh>

struct OrderHistoryEntry
{
   datetime    timestamp;
   ulong       ticket;
   string      context;
   ENUM_ORDER_TYPE order_type;
   double      volume;
   double      price;
   bool        success;
   int         error_code;
   string      comment;
};

class OrderManager
{
private:
   CTrade   m_trade;
   string   m_defaultSymbol;
   uint     m_magic;
   int      m_retryDelay;
   int      m_maxRetries;
   OrderHistoryEntry m_history[];

public:
   void Init(const string symbol, const uint magic = 0, const int retries = 3, const int retryDelayMs = 500)
   {
      m_defaultSymbol = symbol;
      m_magic         = (magic == 0 ? (uint)GetTickCount() : magic);
      m_trade.SetExpertMagicNumber(m_magic);
      m_maxRetries    = MathMax(1, retries);
      m_retryDelay    = MathMax(100, retryDelayMs);
   }

   // --- Market orders ---
   bool Buy(const double volume, double sl = 0.0, double tp = 0.0, const string symbol = NULL, const string comment = "")
   {
      return ExecuteWithRetry(ORDER_TYPE_BUY, volume, 0.0, sl, tp, symbol, comment);
   }

   bool Sell(const double volume, double sl = 0.0, double tp = 0.0, const string symbol = NULL, const string comment = "")
   {
      return ExecuteWithRetry(ORDER_TYPE_SELL, volume, 0.0, sl, tp, symbol, comment);
   }

   // --- Pending orders ---
   bool BuyLimit(const double volume, const double price, double sl = 0.0, double tp = 0.0, const string symbol = NULL, const string comment = "")
   {
      return ExecuteWithRetry(ORDER_TYPE_BUY_LIMIT, volume, price, sl, tp, symbol, comment);
   }

   bool SellLimit(const double volume, const double price, double sl = 0.0, double tp = 0.0, const string symbol = NULL, const string comment = "")
   {
      return ExecuteWithRetry(ORDER_TYPE_SELL_LIMIT, volume, price, sl, tp, symbol, comment);
   }

   bool BuyStop(const double volume, const double price, double sl = 0.0, double tp = 0.0, const string symbol = NULL, const string comment = "")
   {
      return ExecuteWithRetry(ORDER_TYPE_BUY_STOP, volume, price, sl, tp, symbol, comment);
   }

   bool SellStop(const double volume, const double price, double sl = 0.0, double tp = 0.0, const string symbol = NULL, const string comment = "")
   {
      return ExecuteWithRetry(ORDER_TYPE_SELL_STOP, volume, price, sl, tp, symbol, comment);
   }

   // --- Modifications ---
   bool UpdatePositionStops(const ulong ticket, const double sl, const double tp)
   {
      if(!EnsureConnection("UpdatePositionStops"))
         return false;

      ResetLastError();
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.PositionSelectByTicket(ticket))
         {
            double priceCurrent = PositionGetDouble(POSITION_PRICE_CURRENT);
            if(m_trade.PositionModify(ticket, sl, tp))
            {
               RecordHistory(ticket, "PositionModify", (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE),
                              PositionGetDouble(POSITION_VOLUME), priceCurrent, true, 0, "SL/TP update");
               return true;
            }
         }
         LogTradeError("UpdatePositionStops");
      }

      RecordHistory(ticket, "PositionModify", ORDER_TYPE_BUY, 0.0, 0.0, false, _LastError, "Failed SL/TP update");
      return false;
   }

   bool UpdatePendingOrder(const ulong ticket, const double price, const double sl, const double tp, datetime expiration = 0)
   {
      if(!EnsureConnection("UpdatePendingOrder"))
         return false;

      ResetLastError();
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.OrderSelect(ticket))
         {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(m_trade.OrderModify(ticket, price, sl, tp, expiration))
            {
               RecordHistory(ticket, "OrderModify", type, OrderGetDouble(ORDER_VOLUME_CURRENT), price, true, 0, "Pending update");
               return true;
            }
         }
         LogTradeError("UpdatePendingOrder");
      }

      RecordHistory(ticket, "OrderModify", ORDER_TYPE_BUY_LIMIT, 0.0, price, false, _LastError, "Failed pending update");
      return false;
   }

   // --- Closing positions ---
   bool ClosePosition(const ulong ticket, const double deviation = 10)
   {
      if(!EnsureConnection("ClosePosition"))
         return false;

      ResetLastError();
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.PositionClose(ticket, deviation))
         {
            RecordHistory(ticket, "PositionClose", ORDER_TYPE_CLOSE_BY, 0.0, 0.0, true, 0, "Closed position");
            return true;
         }
         LogTradeError("ClosePosition");
      }

      RecordHistory(ticket, "PositionClose", ORDER_TYPE_CLOSE_BY, 0.0, 0.0, false, _LastError, "Failed close");
      return false;
   }

   int CloseAll(const double deviation = 10)
   {
      int closed = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!PositionSelectByIndex(i))
            continue;

         ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
         if(ClosePosition(ticket, deviation))
            closed++;
      }
      return closed;
   }

   // --- History access ---
   int HistoryTotal() const
   {
      return ArraySize(m_history);
   }

   bool GetHistoryEntry(const int index, OrderHistoryEntry &entry) const
   {
      if(index < 0 || index >= ArraySize(m_history))
         return false;

      entry = m_history[index];
      return true;
   }

private:
   bool ExecuteWithRetry(const ENUM_ORDER_TYPE type, const double volume, const double price,
                         const double sl, const double tp, const string symbol, const string comment)
   {
      if(volume <= 0.0)
      {
         Print("OrderManager: volume must be greater than zero");
         return false;
      }

      if(!EnsureConnection("ExecuteWithRetry"))
         return false;

      ResetLastError();
      const string useSymbol = ResolveSymbol(symbol);
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         bool success = false;
         switch(type)
         {
            case ORDER_TYPE_BUY:        success = m_trade.Buy(volume, useSymbol, 0.0, sl, tp, comment);          break;
            case ORDER_TYPE_SELL:       success = m_trade.Sell(volume, useSymbol, 0.0, sl, tp, comment);         break;
            case ORDER_TYPE_BUY_LIMIT:  success = m_trade.BuyLimit(volume, useSymbol, price, sl, tp, comment);   break;
            case ORDER_TYPE_SELL_LIMIT: success = m_trade.SellLimit(volume, useSymbol, price, sl, tp, comment);  break;
            case ORDER_TYPE_BUY_STOP:   success = m_trade.BuyStop(volume, useSymbol, price, sl, tp, comment);    break;
            case ORDER_TYPE_SELL_STOP:  success = m_trade.SellStop(volume, useSymbol, price, sl, tp, comment);   break;
            default: Print("OrderManager: unsupported order type"); return false;
         }

         if(success)
         {
            ulong ticket = m_trade.ResultOrder();
            RecordHistory(ticket, "Trade", type, volume, (price == 0.0 ? SymbolInfoDouble(useSymbol, SYMBOL_BID) : price), true, 0, comment);
            return true;
         }

         LogTradeError("ExecuteWithRetry");
      }

      RecordHistory(0, "Trade", type, volume, price, false, _LastError, comment);
      return false;
   }

   void RecordHistory(const ulong ticket, const string context, const ENUM_ORDER_TYPE type,
                      const double volume, const double price, const bool success,
                      const int errorCode, const string comment)
   {
      OrderHistoryEntry entry;
      entry.timestamp  = TimeCurrent();
      entry.ticket     = ticket;
      entry.context    = context;
      entry.order_type = type;
      entry.volume     = volume;
      entry.price      = price;
      entry.success    = success;
      entry.error_code = errorCode;
      entry.comment    = comment;

      int sz = ArraySize(m_history);
      ArrayResize(m_history, sz + 1);
      m_history[sz] = entry;
   }

   void LogTradeError(const string context)
   {
      const int errorCode = _LastError;
      PrintFormat("OrderManager %s failed. Error %d - %s", context, errorCode, ErrorDescription(errorCode));
      Sleep(m_retryDelay);
      ResetLastError();
   }

   bool EnsureConnection(const string context) const
   {
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
         return true;

      PrintFormat("OrderManager %s waiting for terminal connection...", context);
      for(int attempt = 0; attempt < 5; attempt++)
      {
         Sleep(m_retryDelay);
         if(TerminalInfoInteger(TERMINAL_CONNECTED))
            return true;
      }

      PrintFormat("OrderManager %s aborted: terminal disconnected.", context);
      return false;
   }

   string ResolveSymbol(const string symbol) const
   {
      if(symbol == NULL || symbol == "")
         return m_defaultSymbol;
      return symbol;
   }
};
