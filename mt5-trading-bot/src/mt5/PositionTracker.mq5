#property strict

#include <Trade\Trade.mqh>
#include "Mt5Common.mqh"

struct PositionInfo
{
   ulong            ticket;
   string           symbol;
   ENUM_POSITION_TYPE type;
   double           volume;
   double           price_open;
   double           price_current;
   double           sl;
   double           tp;
   double           profit;
   double           swap;
   double           commission;
   datetime         time_open;
};

struct PositionHistoryEntry
{
   ulong            ticket;
   string           symbol;
   ENUM_POSITION_TYPE type;
   double           volume;
   double           profit;
   double           swap;
   double           commission;
   datetime         closed_at;
};

class PositionTracker
{
private:
   CTrade              m_trade;
   uint                m_magic;
   int                 m_retryDelay;
   int                 m_maxRetries;
   PositionInfo        m_positions[];
   PositionHistoryEntry m_history[];

public:
   void Init(const uint magic = 0, const int retries = 3, const int retryDelayMs = 250)
   {
      m_magic      = magic;
      m_trade.SetExpertMagicNumber(magic);
      m_maxRetries = MathMax(1, retries);
      m_retryDelay = Mt5Common::NormalizeDelay(retryDelayMs, 50);
      Refresh();
   }

   int Refresh()
   {
      if(!EnsureConnection("Refresh"))
         return 0;

      ArrayFree(m_positions);
      const int total = PositionsTotal();

      for(int i = 0; i < total; i++)
      {
         if(!PositionSelectByIndex(i))
            continue;

         if(m_magic != 0 && (uint)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         PositionInfo info;
         FillCurrentPosition(info);
         AppendPosition(info);
      }
      return ArraySize(m_positions);
   }

   bool GetPositionByTicket(const ulong ticket, PositionInfo &info)
   {
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].ticket == ticket)
         {
            info = m_positions[i];
            return true;
         }
      }
      return false;
   }

   double CalculatePositionPnL(const ulong ticket)
   {
      PositionInfo info;
      if(!GetPositionByTicket(ticket, info))
         return 0.0;
      return info.profit + info.swap - info.commission;
   }

   double TotalFloatingPnL()
   {
      double total = 0.0;
      for(int i = 0; i < ArraySize(m_positions); i++)
         total += (m_positions[i].profit + m_positions[i].swap - m_positions[i].commission);
      return total;
   }

   bool ModifyPosition(const ulong ticket, const double sl, const double tp)
   {
      if(!EnsureConnection("ModifyPosition"))
         return false;

      ResetLastError();
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.PositionSelectByTicket(ticket) && m_trade.PositionModify(ticket, sl, tp))
         {
            Refresh();
            return true;
         }
         LogTrackerError("ModifyPosition");
      }
      return false;
   }

   bool ClosePosition(const ulong ticket, const double deviation = 10)
   {
      if(!EnsureConnection("ClosePosition"))
         return false;

      ResetLastError();
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.PositionClose(ticket, deviation))
         {
            Refresh();
            return true;
         }
         LogTrackerError("ClosePosition");
      }
      return false;
   }

   int RefreshHistory(datetime from_time, datetime to_time)
   {
      if(to_time <= from_time)
      {
         Print("PositionTracker RefreshHistory: invalid range");
         return 0;
      }

      if(!EnsureConnection("RefreshHistory"))
         return 0;

      if(!HistorySelect(from_time, to_time))
      {
         LogTrackerError("HistorySelect");
         return 0;
      }

      ArrayFree(m_history);
      const int totalDeals = HistoryDealsTotal();
      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(entryType != DEAL_ENTRY_OUT)
            continue;

         ulong positionTicket = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(positionTicket == 0)
            continue;

         PositionHistoryEntry entry;
         entry.ticket     = positionTicket;
         entry.symbol     = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         entry.type       = (ENUM_POSITION_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         entry.volume     = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         entry.profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         entry.swap       = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         entry.commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         entry.closed_at  = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         AppendHistory(entry);
      }

      return ArraySize(m_history);
   }

   int PositionsCount() const
   {
      return ArraySize(m_positions);
   }

   int HistoryCount() const
   {
      return ArraySize(m_history);
   }

   bool GetHistoryEntry(const int index, PositionHistoryEntry &entry) const
   {
      if(index < 0 || index >= ArraySize(m_history))
         return false;
      entry = m_history[index];
      return true;
   }

private:
   void FillCurrentPosition(PositionInfo &info) const
   {
      info.ticket        = (ulong)PositionGetInteger(POSITION_TICKET);
      info.symbol        = PositionGetString(POSITION_SYMBOL);
      info.type          = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      info.volume        = PositionGetDouble(POSITION_VOLUME);
      info.price_open    = PositionGetDouble(POSITION_PRICE_OPEN);
      info.price_current = PositionGetDouble(POSITION_PRICE_CURRENT);
      info.sl            = PositionGetDouble(POSITION_SL);
      info.tp            = PositionGetDouble(POSITION_TP);
      info.profit        = PositionGetDouble(POSITION_PROFIT);
      info.swap          = PositionGetDouble(POSITION_SWAP);
      info.commission    = PositionGetDouble(POSITION_COMMISSION);
      info.time_open     = (datetime)PositionGetInteger(POSITION_TIME);
   }

   void AppendPosition(const PositionInfo &info)
   {
      int sz = ArraySize(m_positions);
      ArrayResize(m_positions, sz + 1);
      m_positions[sz] = info;
   }

   void AppendHistory(const PositionHistoryEntry &entry)
   {
      int sz = ArraySize(m_history);
      ArrayResize(m_history, sz + 1);
      m_history[sz] = entry;
   }

   void LogTrackerError(const string context) const
   {
      int err = _LastError;
      Mt5Common::LogError("PositionTracker", context, err);
      ResetLastError();
      Sleep(m_retryDelay);
   }

   bool EnsureConnection(const string context) const
   {
      return Mt5Common::EnsureConnection("PositionTracker " + context, m_maxRetries, m_retryDelay);
   }
};
