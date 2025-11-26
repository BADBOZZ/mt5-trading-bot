#property copyright "MetaTrader 5 Trading Bot"
#property link      "https://github.com/"
#property version   "1.00"
#property strict
#property description "Visual overlay controller for MT5 trading bot telemetry"

#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>

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
   RiskSnapshot     m_riskSnapshot;
   StrategyStatus   m_strategyStatuses[];

public:
                     ChartOverlayController()
                     : m_chartId(0),
                       m_initialized(false),
                       m_corner(CORNER_RIGHT_UPPER)
                       {}

   bool              Init(const long chartId)
     {
      m_chartId     = chartId;
      m_corner      = GetCornerFromInput();

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
     }

   void              Shutdown()
     {
      m_initialized = false;
      m_infoPanel.Destroy();
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

   void              CollectStrategyStatuses(StrategyStatus &statuses[])
     {
      ArrayResize(statuses,0);
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
