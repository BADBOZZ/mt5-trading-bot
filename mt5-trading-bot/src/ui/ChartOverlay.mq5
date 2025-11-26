#property copyright "MetaTrader 5 Trading Bot"
#property link      "https://github.com/"
#property version   "1.00"
#property strict
#property description "Visual overlay controller for MT5 trading bot telemetry"

#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\Trade.mqh>
#include <Math\Stat.mqh>

#include "InfoPanel.mqh"
#include "PositionDisplay.mqh"
#include "SignalDisplay.mqh"
#include "PerformanceDashboard.mqh"

input bool   InpShowOverlay      = true;
input int    InpRefreshSeconds   = 1;
input int    InpFontSize         = 10;
input color  InpPrimaryColor     = clrWhite;
input color  InpPositiveColor    = clrLime;
input color  InpNegativeColor    = clrTomato;
input color  InpPanelBackground  = clrBlack;
input int    InpPanelWidth       = 300;
input int    InpPanelOffsetX     = 10;
input int    InpPanelOffsetY     = 10;
input int    InpPanelPadding     = 12;
input bool   InpShowPositionsPanel = true;
input bool   InpShowSignalsPanel   = true;
input bool   InpShowPerformancePanel = true;
input string InpSignalPrefix       = "MT5BOT_SIGNAL|";
input string InpStrategyPrefix     = "MT5BOT_STRATEGY|";

enum ENUM_OVERLAY_POSITION
  {
   OVERLAY_TOP_LEFT = 0,
   OVERLAY_TOP_RIGHT = 1,
   OVERLAY_BOTTOM_LEFT = 2,
   OVERLAY_BOTTOM_RIGHT = 3
  };

input ENUM_OVERLAY_POSITION InpOverlayPosition = OVERLAY_TOP_RIGHT;

class ChartOverlayController
  {
private:
   long     m_chartId;
   bool     m_initialized;
   ENUM_BASE_CORNER m_corner;

   InfoPanel        m_infoPanel;
   PositionDisplay  m_positionDisplay;
   SignalDisplay    m_signalDisplay;
   PerformanceDashboard m_performanceDashboard;
   RiskSnapshot     m_riskSnapshot;
   StrategyStatus   m_strategyStatuses[];
   PositionRow      m_positionRows[];
   SignalInfo       m_signalRows[];
   StrategyPerformance m_performanceRows[];

   struct PerfAccumulator
     {
      string name;
      int    wins;
      int    losses;
      double winSum;
      double lossSum;
      int    trades;
      double best;
      double worst;
     };

   bool             m_showPositions;
   bool             m_showSignals;
   bool             m_showPerformance;

public:
                     ChartOverlayController()
                     : m_chartId(0),
                       m_initialized(false),
                       m_corner(CORNER_RIGHT_UPPER),
                       m_showPositions(true),
                       m_showSignals(true),
                       m_showPerformance(true)
                       {}

   bool              Init(const long chartId)
     {
      m_chartId     = chartId;
      m_corner      = GetCornerFromInput();
      m_showPositions = InpShowPositionsPanel;
      m_showSignals   = InpShowSignalsPanel;
      m_showPerformance = InpShowPerformancePanel;

      if(!m_infoPanel.Init(
         m_chartId,
         "MT5BOT",
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY,
         InpPanelWidth,
         InpFontSize,
         InpPrimaryColor,
         InpPositiveColor,
         InpNegativeColor,
         InpPanelBackground))
         return(false);

      if(!m_positionDisplay.Init(
         m_chartId,
         "MT5BOT",
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY + m_infoPanel.Height() + InpPanelPadding,
         InpPanelWidth,
         InpFontSize,
         InpPrimaryColor,
         InpPositiveColor,
         InpNegativeColor,
         InpPanelBackground))
         return(false);
      m_positionDisplay.SetVisible(m_showPositions);

      if(!m_signalDisplay.Init(
         m_chartId,
         "MT5BOT",
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY + m_infoPanel.Height() + m_positionDisplay.Height() + (InpPanelPadding*2),
         InpPanelWidth,
         InpFontSize,
         InpPrimaryColor,
         InpPositiveColor,
         InpNegativeColor,
         InpPanelBackground))
         return(false);
      m_signalDisplay.SetVisible(m_showSignals);

      if(!m_performanceDashboard.Init(
         m_chartId,
         "MT5BOT",
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY + m_infoPanel.Height() + m_positionDisplay.Height() + m_signalDisplay.Height() + (InpPanelPadding*3),
         InpPanelWidth,
         InpFontSize,
         InpPrimaryColor,
         InpPositiveColor,
         InpNegativeColor,
         InpPanelBackground))
         return(false);
      m_performanceDashboard.SetVisible(m_showPerformance);

      m_initialized = true;
      return(true);
     }

   void              Refresh()
     {
      if(!m_initialized)
         return;

      CollectRiskSnapshot(m_riskSnapshot);
      CollectStrategyStatuses(m_strategyStatuses);
      m_infoPanel.Update(m_riskSnapshot,m_strategyStatuses);
      int nextOffset = InpPanelOffsetY + m_infoPanel.Height() + InpPanelPadding;

      if(m_showPositions)
        {
         CollectPositionRows(m_positionRows);
         m_positionDisplay.SetCorner(m_corner,InpPanelOffsetX,nextOffset);
         m_positionDisplay.SetVisible(true);
         m_positionDisplay.Update(m_positionRows);
         nextOffset += m_positionDisplay.Height() + InpPanelPadding;
        }
      else
         m_positionDisplay.SetVisible(false);

      if(m_showSignals)
        {
         CollectSignalInfo(m_signalRows);
         m_signalDisplay.SetCorner(m_corner,InpPanelOffsetX,nextOffset);
         m_signalDisplay.SetVisible(true);
         m_signalDisplay.Update(m_signalRows);
         nextOffset += m_signalDisplay.Height() + InpPanelPadding;
        }
      else
         m_signalDisplay.SetVisible(false);

      if(m_showPerformance)
        {
         CollectPerformanceStats(m_performanceRows);
         m_performanceDashboard.SetCorner(m_corner,InpPanelOffsetX,nextOffset);
         m_performanceDashboard.SetVisible(true);
         m_performanceDashboard.Update(m_performanceRows);
        }
      else
         m_performanceDashboard.SetVisible(false);
     }

   void              Shutdown()
     {
      m_initialized = false;
      m_infoPanel.Destroy();
      m_positionDisplay.Destroy();
      m_signalDisplay.Destroy();
      m_performanceDashboard.Destroy();
     }

   ENUM_BASE_CORNER  GetCornerFromInput() const
     {
      switch(InpOverlayPosition)
        {
         case OVERLAY_TOP_LEFT: return(CORNER_LEFT_UPPER);
         case OVERLAY_TOP_RIGHT: return(CORNER_RIGHT_UPPER);
         case OVERLAY_BOTTOM_LEFT: return(CORNER_LEFT_LOWER);
         case OVERLAY_BOTTOM_RIGHT: return(CORNER_RIGHT_LOWER);
        }
      return(CORNER_RIGHT_UPPER);
     }

   void              CollectRiskSnapshot(RiskSnapshot &snapshot)
     {
      snapshot.balance  = AccountInfoDouble(ACCOUNT_BALANCE);
      snapshot.equity   = AccountInfoDouble(ACCOUNT_EQUITY);
      snapshot.marginUsed = AccountInfoDouble(ACCOUNT_MARGIN);
      snapshot.drawdownPercent = (snapshot.balance == 0.0)
                                 ? 0.0
                                 : (snapshot.balance - snapshot.equity) / snapshot.balance * 100.0;
      snapshot.dailyPnL = CalculateDailyPnL();
     }

   double            CalculateDailyPnL() const
     {
      datetime now      = TimeCurrent();
      datetime dayStart = now - (now % 86400);
      if(!HistorySelect(dayStart,now))
         return(0.0);

      double pnl = 0.0;
      for(int i=HistoryDealsTotal()-1;i>=0;i--)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         datetime dealTime = (datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
         if(dealTime < dayStart)
            break;
         long entry = HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
            continue;
         double profit = HistoryDealGetDouble(ticket,DEAL_PROFIT)
                         + HistoryDealGetDouble(ticket,DEAL_SWAP)
                         + HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         pnl += profit;
        }
      return(pnl);
     }

   bool              ExtractKeyParts(const string name,const string prefix,string &first,string &second) const
     {
      if(StringFind(name,prefix) != 0)
         return(false);
      string payload = StringSubstr(name,StringLen(prefix));
      string parts[];
      int count = StringSplit(payload,'|',parts);
      if(count < 2)
         return(false);
      first  = parts[0];
      second = parts[1];
      return(true);
     }

   void              CollectStrategyStatuses(StrategyStatus &statuses[])
     {
      ArrayResize(statuses,0);
      int total = GlobalVariablesTotal();
      for(int i=0;i<total;i++)
        {
         string name = GlobalVariableName(i);
         string strategy,symbol;
         if(!ExtractKeyParts(name,InpStrategyPrefix,strategy,symbol))
            continue;
         StrategyStatus status;
         status.name    = strategy;
         status.symbol  = symbol;
         status.enabled = (GlobalVariableGet(name) >= 1.0);
         int newIndex = ArraySize(statuses);
         ArrayResize(statuses,newIndex+1);
         statuses[newIndex] = status;
        }
     }

   void              CollectPositionRows(PositionRow &rows[])
     {
      int total = PositionsTotal();
      ArrayResize(rows,total);
      CPositionInfo pos;
      for(int i=0;i<total;i++)
        {
         if(!pos.SelectByIndex(i))
            continue;
         rows[i].symbol    = pos.Symbol();
         rows[i].type      = pos.PositionType()==POSITION_TYPE_BUY ? "BUY" : "SELL";
         rows[i].volume    = pos.Volume();
         rows[i].profit    = pos.Profit();
         rows[i].stopLoss  = pos.StopLoss();
         rows[i].takeProfit= pos.TakeProfit();
        }
     }

   void              CollectSignalInfo(SignalInfo &signals[])
     {
      ArrayResize(signals,0);
      int total = GlobalVariablesTotal();
      for(int i=0;i<total;i++)
        {
         string name = GlobalVariableName(i);
         string strategy,symbol;
         if(!ExtractKeyParts(name,InpSignalPrefix,strategy,symbol))
            continue;
         SignalInfo info;
         info.strategy  = strategy;
         info.symbol    = symbol;
         double raw     = GlobalVariableGet(name);
         info.type      = (raw >= 0.0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
         info.confidence = MathMin(100.0,MathAbs(raw));
         info.timestamp  = (datetime)GlobalVariableTime(name);
         AppendSignal(signals,info);
        }

      if(ArraySize(signals) == 0)
         CollectSignalsFromOrders(signals);
     }

   void              CollectSignalsFromOrders(SignalInfo &signals[])
     {
      ArrayResize(signals,0);
      int total = OrdersTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
            continue;
         SignalInfo info;
         info.strategy = OrderGetString(ORDER_COMMENT);
         if(info.strategy == "")
            info.strategy = StringFormat("MAGIC-%d",(int)OrderGetInteger(ORDER_MAGIC));
         info.symbol   = OrderGetString(ORDER_SYMBOL);
         info.type     = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         info.confidence = MathMin(100.0,OrderGetDouble(ORDER_VOLUME_CURRENT)*100.0);
         info.timestamp  = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         AppendSignal(signals,info);
        }
     }

   void              AppendSignal(SignalInfo &signals,const SignalInfo &info)
     {
      int newIndex = ArraySize(signals);
      ArrayResize(signals,newIndex+1);
      signals[newIndex] = info;
     }

   void              CollectPerformanceStats(StrategyPerformance &stats[])
     {
      ArrayResize(stats,0);
      datetime now = TimeCurrent();
      datetime dayStart = now - (now % 86400);
      if(!HistorySelect(dayStart,now))
         return;

      PerfAccumulator acc[];

      for(int i=HistoryDealsTotal()-1;i>=0;i--)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         datetime dealTime = (datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
         if(dealTime < dayStart)
            break;
         long entry = HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
            continue;
         double profit = HistoryDealGetDouble(ticket,DEAL_PROFIT)
                         + HistoryDealGetDouble(ticket,DEAL_SWAP)
                         + HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         string strategy = ResolveStrategyName(ticket);
         int idx = FindPerfIndex(acc,strategy);
         if(idx < 0)
           {
            idx = ArraySize(acc);
            ArrayResize(acc,idx+1);
            acc[idx].name   = strategy;
            acc[idx].wins   = 0;
            acc[idx].losses = 0;
            acc[idx].winSum = 0.0;
            acc[idx].lossSum= 0.0;
            acc[idx].trades = 0;
            acc[idx].best   = -DBL_MAX;
            acc[idx].worst  = DBL_MAX;
           }

         acc[idx].trades++;
         if(profit >= 0.0)
           {
            acc[idx].wins++;
            acc[idx].winSum += profit;
           }
         else
           {
            acc[idx].losses++;
            acc[idx].lossSum += profit;
           }

         if(profit > acc[idx].best)
            acc[idx].best = profit;
         if(profit < acc[idx].worst)
            acc[idx].worst = profit;
        }

      int total = ArraySize(acc);
      ArrayResize(stats,total);
      for(int i=0;i<total;i++)
        {
         StrategyPerformance perf;
         perf.name        = acc[i].name;
         perf.tradesToday = acc[i].trades;
         perf.winRate     = (acc[i].trades == 0) ? 0.0 : (double)acc[i].wins / acc[i].trades * 100.0;
         perf.avgProfit   = (acc[i].wins == 0) ? 0.0 : acc[i].winSum / acc[i].wins;
         perf.avgLoss     = (acc[i].losses == 0) ? 0.0 : acc[i].lossSum / acc[i].losses;
         perf.bestTrade   = (acc[i].best == -DBL_MAX ? 0.0 : acc[i].best);
         perf.worstTrade  = (acc[i].worst == DBL_MAX ? 0.0 : acc[i].worst);
         stats[i] = perf;
        }
     }

   int               FindPerfIndex(PerfAccumulator &acc[],const string strategy) const
     {
      for(int i=0;i<ArraySize(acc);i++)
        {
         if(acc[i].name == strategy)
            return(i);
        }
      return(-1);
     }

   string            ResolveStrategyName(const ulong dealTicket) const
     {
      string comment = HistoryDealGetString(dealTicket,DEAL_COMMENT);
      if(comment != "")
         return(comment);
      long magic = HistoryDealGetInteger(dealTicket,DEAL_MAGIC);
      if(magic != 0)
         return(StringFormat("MAGIC-%d",(int)magic));
      return(HistoryDealGetString(dealTicket,DEAL_SYMBOL));
     }
  };

ChartOverlayController g_overlay;

int OnInit()
  {
   if(!InpShowOverlay)
      return(INIT_SUCCEEDED);

   if(!g_overlay.Init(ChartID()))
      return(INIT_FAILED);

   if(InpRefreshSeconds > 0)
      EventSetTimer(InpRefreshSeconds);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_overlay.Shutdown();
  }

void OnTick()
  {
   g_overlay.Refresh();
  }

void OnTimer()
  {
   g_overlay.Refresh();
  }
