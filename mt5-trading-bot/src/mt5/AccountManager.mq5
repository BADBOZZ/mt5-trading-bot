#property strict

struct AccountSnapshot
{
   datetime timestamp;
   double   balance;
   double   equity;
   double   margin;
   double   free_margin;
   double   margin_level;
   double   leverage;
};

class AccountManager
{
private:
   AccountSnapshot m_current;
   AccountSnapshot m_history[];
   int             m_retryDelay;
   int             m_maxRetries;

public:
   void Init(const int retries = 3, const int retryDelayMs = 250)
   {
      m_maxRetries = MathMax(1, retries);
      m_retryDelay = MathMax(50, retryDelayMs);
      Refresh();
   }

   bool Refresh()
   {
      bool ok = false;
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         ResetLastError();
         m_current.timestamp   = TimeCurrent();
         m_current.balance     = AccountInfoDouble(ACCOUNT_BALANCE);
         m_current.equity      = AccountInfoDouble(ACCOUNT_EQUITY);
         m_current.margin      = AccountInfoDouble(ACCOUNT_MARGIN);
         m_current.free_margin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
         m_current.margin_level= AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
         m_current.leverage    = AccountInfoDouble(ACCOUNT_LEVERAGE);

         if(_LastError == 0)
         {
            ok = true;
            break;
         }

         LogAccountError("Refresh");
      }

      if(ok)
         PushSnapshot(m_current);

      return ok;
   }

   double Balance() const      { return m_current.balance; }
   double Equity() const       { return m_current.equity; }
   double Margin() const       { return m_current.margin; }
   double FreeMargin() const   { return m_current.free_margin; }
   double MarginLevel() const  { return m_current.margin_level; }
   double Leverage() const     { return m_current.leverage; }

   ENUM_ACCOUNT_TRADE_MODE TradeMode() const
   {
      return (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   }

   ENUM_ACCOUNT_MARGIN_MODE MarginMode() const
   {
      return (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   }

   bool IsDemo() const
   {
      return AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_DEMO;
   }

   bool IsNetting() const
   {
      return AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING;
   }

   double CalculateRequiredMargin(const string symbol, const ENUM_ORDER_TYPE type, const double volume, const double price = 0.0)
   {
      double margin = 0.0;
      if(!OrderCalcMargin(type, symbol, volume, price, margin))
      {
         LogAccountError("CalculateRequiredMargin");
         return -1.0;
      }
      return margin;
   }

   double CalculateProfit(const string symbol, const ENUM_ORDER_TYPE type, const double volume, const double price_open, const double price_close)
   {
      double profit = 0.0;
      if(!OrderCalcProfit(type, symbol, volume, price_open, price_close, profit))
      {
         LogAccountError("CalculateProfit");
         return 0.0;
      }
      return profit;
   }

   bool HasSufficientMargin(const string symbol, const ENUM_ORDER_TYPE type, const double volume, const double price = 0.0, const double bufferPercent = 5.0)
   {
      double margin = CalculateRequiredMargin(symbol, type, volume, price);
      if(margin < 0.0)
         return false;

      double free = FreeMargin();
      double buffer = margin * (bufferPercent / 100.0);
      return (free - margin) > buffer;
   }

   int HistoryCount() const
   {
      return ArraySize(m_history);
   }

   bool GetSnapshot(const int index, AccountSnapshot &snapshot) const
   {
      if(index < 0 || index >= ArraySize(m_history))
         return false;
      snapshot = m_history[index];
      return true;
   }

private:
   void PushSnapshot(const AccountSnapshot &snapshot)
   {
      int sz = ArraySize(m_history);
      ArrayResize(m_history, sz + 1);
      m_history[sz] = snapshot;
   }

   void LogAccountError(const string context) const
   {
      const int err = _LastError;
      PrintFormat("AccountManager %s failed. Error %d", context, err);
      Sleep(m_retryDelay);
      ResetLastError();
   }
};
