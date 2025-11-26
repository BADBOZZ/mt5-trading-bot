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
input bool   InpEnableConfigPanel = true;
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

   string           m_prefix;
   string           m_markerPrefix;
   int              m_fontSizeSetting;
   color            m_primaryColor;
   color            m_positiveColor;
   color            m_negativeColor;
   color            m_panelBackground;
   color            m_basePrimaryColor;
   color            m_basePositiveColor;
   color            m_baseNegativeColor;
   color            m_baseBackgroundColor;
   int              m_refreshSeconds;
   bool             m_overlayVisible;
   bool             m_themeDark;
   bool             m_configPanelEnabled;
   string           m_cfgBgName;
   string           m_btnToggle;
   string           m_btnCorner;
   string           m_btnFontUp;
   string           m_btnFontDown;
   string           m_btnTheme;
   string           m_btnRefreshFast;
   string           m_btnRefreshSlow;
   string           m_btnShowPositions;
   string           m_btnShowSignals;
   string           m_btnShowPerformance;

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
                       m_showPerformance(true),
                       m_prefix("MT5BOT"),
                       m_markerPrefix("MT5BOT_MARKER_"),
                       m_fontSizeSetting(InpFontSize),
                       m_primaryColor(InpPrimaryColor),
                       m_positiveColor(InpPositiveColor),
                       m_negativeColor(InpNegativeColor),
                       m_panelBackground(InpPanelBackground),
                       m_basePrimaryColor(InpPrimaryColor),
                       m_basePositiveColor(InpPositiveColor),
                       m_baseNegativeColor(InpNegativeColor),
                       m_baseBackgroundColor(InpPanelBackground),
                       m_refreshSeconds(MathMax(1,InpRefreshSeconds)),
                       m_overlayVisible(true),
                       m_themeDark(true),
                       m_configPanelEnabled(false),
                       m_cfgBgName(m_prefix+"_CFG_BG"),
                       m_btnToggle(m_prefix+"_BTN_VIS"),
                       m_btnCorner(m_prefix+"_BTN_CORNER"),
                       m_btnFontUp(m_prefix+"_BTN_FONT_UP"),
                       m_btnFontDown(m_prefix+"_BTN_FONT_DN"),
                       m_btnTheme(m_prefix+"_BTN_THEME"),
                       m_btnRefreshFast(m_prefix+"_BTN_FAST"),
                       m_btnRefreshSlow(m_prefix+"_BTN_SLOW"),
                       m_btnShowPositions(m_prefix+"_BTN_POS"),
                       m_btnShowSignals(m_prefix+"_BTN_SIG"),
                       m_btnShowPerformance(m_prefix+"_BTN_PERF")
                       {}

   bool              Init(const long chartId)
     {
      m_chartId     = chartId;
      m_corner      = GetCornerFromInput();
      m_showPositions = InpShowPositionsPanel;
      m_showSignals   = InpShowSignalsPanel;
      m_showPerformance = InpShowPerformancePanel;
      m_fontSizeSetting = InpFontSize;
      m_primaryColor    = InpPrimaryColor;
      m_positiveColor   = InpPositiveColor;
      m_negativeColor   = InpNegativeColor;
      m_panelBackground = InpPanelBackground;
      m_basePrimaryColor   = InpPrimaryColor;
      m_basePositiveColor  = InpPositiveColor;
      m_baseNegativeColor  = InpNegativeColor;
      m_baseBackgroundColor= InpPanelBackground;
      m_refreshSeconds = MathMax(1,InpRefreshSeconds);
      m_themeDark      = true;
      m_configPanelEnabled = InpEnableConfigPanel;

      if(!m_infoPanel.Init(
         m_chartId,
         m_prefix,
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY,
         InpPanelWidth,
         m_fontSizeSetting,
         m_primaryColor,
         m_positiveColor,
         m_negativeColor,
         m_panelBackground))
         return(false);

      if(!m_positionDisplay.Init(
         m_chartId,
         m_prefix,
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY + m_infoPanel.Height() + InpPanelPadding,
         InpPanelWidth,
         m_fontSizeSetting,
         m_primaryColor,
         m_positiveColor,
         m_negativeColor,
         m_panelBackground))
         return(false);
      m_positionDisplay.SetVisible(m_showPositions);

      if(!m_signalDisplay.Init(
         m_chartId,
         m_prefix,
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY + m_infoPanel.Height() + m_positionDisplay.Height() + (InpPanelPadding*2),
         InpPanelWidth,
         m_fontSizeSetting,
         m_primaryColor,
         m_positiveColor,
         m_negativeColor,
         m_panelBackground))
         return(false);
      m_signalDisplay.SetVisible(m_showSignals);

      if(!m_performanceDashboard.Init(
         m_chartId,
         m_prefix,
         m_corner,
         InpPanelOffsetX,
         InpPanelOffsetY + m_infoPanel.Height() + m_positionDisplay.Height() + m_signalDisplay.Height() + (InpPanelPadding*3),
         InpPanelWidth,
         m_fontSizeSetting,
         m_primaryColor,
         m_positiveColor,
         m_negativeColor,
         m_panelBackground))
         return(false);
      m_performanceDashboard.SetVisible(m_showPerformance);

      InitConfigPanel();
      SetOverlayVisible(InpShowOverlay);
      ApplyPanelThemes();
      UpdateConfigPanelState();
      ApplyRefreshRate();

      m_initialized = true;
      return(true);
     }

   void              Refresh()
     {
      if(!m_initialized)
         return;

      if(!m_overlayVisible)
        {
         string none[];
         CleanupMarkerObjects(none);
         return;
        }

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

      DrawVisualMarkers();
     }

   void              Shutdown()
     {
      m_initialized = false;
      m_infoPanel.Destroy();
      m_positionDisplay.Destroy();
      m_signalDisplay.Destroy();
      m_performanceDashboard.Destroy();
      DestroyConfigPanel();
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
      ArrayResize(rows,0);
      CPositionInfo pos;
      for(int i=0;i<PositionsTotal();i++)
        {
         if(!pos.SelectByIndex(i))
            continue;
         int idx = ArraySize(rows);
         ArrayResize(rows,idx+1);
         rows[idx].symbol    = pos.Symbol();
         rows[idx].type      = pos.PositionType()==POSITION_TYPE_BUY ? "BUY" : "SELL";
         rows[idx].volume    = pos.Volume();
         rows[idx].profit    = pos.Profit();
         rows[idx].stopLoss  = pos.StopLoss();
         rows[idx].takeProfit= pos.TakeProfit();
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

   void              SetOverlayVisible(const bool visible)
     {
      m_overlayVisible = visible;
      m_infoPanel.SetVisible(visible);
      m_positionDisplay.SetVisible(visible && m_showPositions);
      m_signalDisplay.SetVisible(visible && m_showSignals);
      m_performanceDashboard.SetVisible(visible && m_showPerformance);
      if(!visible)
        {
         string none[];
         CleanupMarkerObjects(none);
        }

      if(m_configPanelEnabled)
         UpdateConfigPanelState();
     }

   void              ApplyPanelThemes()
     {
      m_infoPanel.SetTheme(m_fontSizeSetting,m_primaryColor,m_positiveColor,m_negativeColor,m_panelBackground);
      m_positionDisplay.SetTheme(m_fontSizeSetting,m_primaryColor,m_positiveColor,m_negativeColor,m_panelBackground);
      m_signalDisplay.SetTheme(m_fontSizeSetting,m_primaryColor,m_positiveColor,m_negativeColor,m_panelBackground);
      m_performanceDashboard.SetTheme(m_fontSizeSetting,m_primaryColor,m_positiveColor,m_negativeColor,m_panelBackground);
     }

   void              InitConfigPanel()
     {
      if(!m_configPanelEnabled)
         return;

      if(ObjectFind(m_chartId,m_cfgBgName) == -1)
         ObjectCreate(m_chartId,m_cfgBgName,OBJ_RECTANGLE_LABEL,0,0,0);

      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_XDISTANCE,5);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_YDISTANCE,5);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_XSIZE,330);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_YSIZE,150);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_BGCOLOR,clrBlack);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_COLOR,clrDimGray);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_BACK,true);
      ObjectSetInteger(m_chartId,m_cfgBgName,OBJPROP_SELECTABLE,false);

      CreateConfigButton(m_btnToggle,"Overlay",0,0);
      CreateConfigButton(m_btnCorner,"Corner",1,0);
      CreateConfigButton(m_btnTheme,"Theme",2,0);
      CreateConfigButton(m_btnFontDown,"Font -",0,1);
      CreateConfigButton(m_btnFontUp,"Font +",1,1);
      CreateConfigButton(m_btnRefreshFast,"Faster",2,1);
      CreateConfigButton(m_btnRefreshSlow,"Slower",2,2);
      CreateConfigButton(m_btnShowPositions,"Positions",0,2);
      CreateConfigButton(m_btnShowSignals,"Signals",1,2);
      CreateConfigButton(m_btnShowPerformance,"Performance",0,3);
     }

   void              DestroyConfigPanel()
     {
      if(!m_configPanelEnabled)
         return;
      string objs[] =
        {
         m_cfgBgName,
         m_btnToggle,
         m_btnCorner,
         m_btnFontDown,
         m_btnFontUp,
         m_btnTheme,
         m_btnRefreshFast,
         m_btnRefreshSlow,
         m_btnShowPositions,
         m_btnShowSignals,
         m_btnShowPerformance
        };
      for(int i=0;i<ArraySize(objs);i++)
        ObjectDelete(m_chartId,objs[i]);
     }

   void              CreateConfigButton(const string name,const string label,const int column,const int row)
     {
      if(!m_configPanelEnabled)
         return;
      if(ObjectFind(m_chartId,name) == -1)
         ObjectCreate(m_chartId,name,OBJ_BUTTON,0,0,0);
      int btnWidth = 100;
      int btnHeight = 20;
      int x = 10 + column*(btnWidth+5);
      int y = 15 + row*(btnHeight+5);
      ObjectSetInteger(m_chartId,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartId,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(m_chartId,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(m_chartId,name,OBJPROP_XSIZE,btnWidth);
      ObjectSetInteger(m_chartId,name,OBJPROP_YSIZE,btnHeight);
      ObjectSetInteger(m_chartId,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chartId,name,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(m_chartId,name,OBJPROP_BGCOLOR,clrDimGray);
      ObjectSetString(m_chartId,name,OBJPROP_TEXT,label);
     }

   void              UpdateConfigPanelState()
     {
      if(!m_configPanelEnabled)
         return;
      ObjectSetString(m_chartId,m_btnToggle,OBJPROP_TEXT,m_overlayVisible ? "Hide Overlay" : "Show Overlay");
      ObjectSetString(m_chartId,m_btnCorner,OBJPROP_TEXT,StringFormat("Corner %s",CornerToLabel()));
      ObjectSetString(m_chartId,m_btnTheme,OBJPROP_TEXT,m_themeDark ? "Theme Dark" : "Theme Light");
      ObjectSetString(m_chartId,m_btnFontUp,OBJPROP_TEXT,StringFormat("Font %d",m_fontSizeSetting));
      ObjectSetString(m_chartId,m_btnRefreshFast,OBJPROP_TEXT,StringFormat("Faster (%ds)",m_refreshSeconds));
      ObjectSetString(m_chartId,m_btnRefreshSlow,OBJPROP_TEXT,"Slower");
      ObjectSetString(m_chartId,m_btnShowPositions,OBJPROP_TEXT,m_showPositions ? "Positions ON" : "Positions OFF");
      ObjectSetString(m_chartId,m_btnShowSignals,OBJPROP_TEXT,m_showSignals ? "Signals ON" : "Signals OFF");
      ObjectSetString(m_chartId,m_btnShowPerformance,OBJPROP_TEXT,m_showPerformance ? "Perf ON" : "Perf OFF");
     }

   string            CornerToLabel() const
     {
      switch(m_corner)
        {
         case CORNER_LEFT_UPPER:  return("TL");
         case CORNER_RIGHT_UPPER: return("TR");
         case CORNER_LEFT_LOWER:  return("BL");
         case CORNER_RIGHT_LOWER: return("BR");
        }
      return("TR");
     }

   void              ToggleOverlay()
     {
      SetOverlayVisible(!m_overlayVisible);
     }

   void              CycleCorner()
     {
      switch(m_corner)
        {
         case CORNER_LEFT_UPPER:  m_corner = CORNER_RIGHT_UPPER; break;
         case CORNER_RIGHT_UPPER: m_corner = CORNER_RIGHT_LOWER; break;
         case CORNER_RIGHT_LOWER: m_corner = CORNER_LEFT_LOWER; break;
         default:                 m_corner = CORNER_LEFT_UPPER; break;
        }
      UpdatePanelAnchors();
     }

   void              AdjustFont(const int delta)
     {
      m_fontSizeSetting = (int)MathMax(8,MathMin(22,m_fontSizeSetting + delta));
      ApplyPanelThemes();
     }

   void              CycleTheme()
     {
      m_themeDark = !m_themeDark;
      if(m_themeDark)
        {
         m_primaryColor    = m_basePrimaryColor;
         m_positiveColor   = m_basePositiveColor;
         m_negativeColor   = m_baseNegativeColor;
         m_panelBackground = m_baseBackgroundColor;
        }
      else
        {
         m_primaryColor    = clrBlack;
         m_positiveColor   = clrDodgerBlue;
         m_negativeColor   = clrCrimson;
         m_panelBackground = clrWhite;
        }
      ApplyPanelThemes();
     }

   void              AdjustRefresh(const int delta)
     {
      m_refreshSeconds = (int)MathMax(1,MathMin(60,m_refreshSeconds + delta));
      ApplyRefreshRate();
     }

   void              TogglePositions()
     {
      m_showPositions = !m_showPositions;
      m_positionDisplay.SetVisible(m_overlayVisible && m_showPositions);
      UpdatePanelAnchors();
     }

   void              ToggleSignals()
     {
      m_showSignals = !m_showSignals;
      m_signalDisplay.SetVisible(m_overlayVisible && m_showSignals);
      UpdatePanelAnchors();
     }

   void              TogglePerformance()
     {
      m_showPerformance = !m_showPerformance;
      m_performanceDashboard.SetVisible(m_overlayVisible && m_showPerformance);
      UpdatePanelAnchors();
     }

   void              UpdatePanelAnchors()
     {
      m_infoPanel.SetCorner(m_corner,InpPanelOffsetX,InpPanelOffsetY);
      int nextOffset = InpPanelOffsetY + m_infoPanel.Height() + InpPanelPadding;
      if(m_showPositions)
        {
         m_positionDisplay.SetCorner(m_corner,InpPanelOffsetX,nextOffset);
         nextOffset += m_positionDisplay.Height() + InpPanelPadding;
        }
      if(m_showSignals)
        {
         m_signalDisplay.SetCorner(m_corner,InpPanelOffsetX,nextOffset);
         nextOffset += m_signalDisplay.Height() + InpPanelPadding;
        }
      if(m_showPerformance)
         m_performanceDashboard.SetCorner(m_corner,InpPanelOffsetX,nextOffset);
     }

   void              ApplyRefreshRate()
     {
      EventKillTimer();
      if(m_refreshSeconds > 0)
         EventSetTimer(m_refreshSeconds);
     }

   void              OnChartEvent(const int id,const string &objectName)
     {
      if(!m_configPanelEnabled || id != CHARTEVENT_OBJECT_CLICK)
         return;
      if(objectName == m_btnToggle)
         ToggleOverlay();
      else if(objectName == m_btnCorner)
         CycleCorner();
      else if(objectName == m_btnFontUp)
         AdjustFont(+1);
      else if(objectName == m_btnFontDown)
         AdjustFont(-1);
      else if(objectName == m_btnTheme)
         CycleTheme();
      else if(objectName == m_btnRefreshFast)
         AdjustRefresh(-1);
      else if(objectName == m_btnRefreshSlow)
         AdjustRefresh(+1);
      else if(objectName == m_btnShowPositions)
         TogglePositions();
      else if(objectName == m_btnShowSignals)
         ToggleSignals();
      else if(objectName == m_btnShowPerformance)
         TogglePerformance();

      UpdateConfigPanelState();
     }

   void              DrawVisualMarkers()
     {
      string activeObjects[];
      DrawPositionMarkers(activeObjects);
      DrawSignalMarkers(activeObjects);
      DrawExitMarkers(activeObjects);
      CleanupMarkerObjects(activeObjects);
     }

   void              DrawPositionMarkers(string &activeObjects[])
     {
      CPositionInfo pos;
      for(int i=0;i<PositionsTotal();i++)
        {
         if(!pos.SelectByIndex(i))
            continue;
         ulong ticket = pos.Ticket();
         datetime entryTime = pos.Time();
         double entryPrice  = pos.PriceOpen();
         string entryName = StringFormat("%sENTRY_%I64u",m_markerPrefix,ticket);
         ENUM_OBJECT arrowType = pos.PositionType()==POSITION_TYPE_BUY ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
         color arrowColor = pos.PositionType()==POSITION_TYPE_BUY ? m_positiveColor : m_negativeColor;
         if(EnsureObject(entryName,arrowType))
           {
            ObjectSetInteger(m_chartId,entryName,OBJPROP_TIME,0,entryTime);
            ObjectSetDouble(m_chartId,entryName,OBJPROP_PRICE,0,entryPrice);
            ObjectSetInteger(m_chartId,entryName,OBJPROP_COLOR,arrowColor);
            ObjectSetInteger(m_chartId,entryName,OBJPROP_WIDTH,2);
            ObjectSetInteger(m_chartId,entryName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(m_chartId,entryName,OBJPROP_SELECTED,false);
            ObjectSetString(m_chartId,entryName,OBJPROP_TOOLTIP,
                            StringFormat("%s entry %.5f",pos.Symbol(),entryPrice));
            RegisterActiveObject(activeObjects,entryName);
           }

         if(pos.StopLoss() > 0)
           {
            string slName = StringFormat("%sSL_%I64u",m_markerPrefix,ticket);
            if(EnsureObject(slName,OBJ_HLINE))
              {
               ObjectSetDouble(m_chartId,slName,OBJPROP_PRICE,0,pos.StopLoss());
               ObjectSetInteger(m_chartId,slName,OBJPROP_COLOR,InpNegativeColor);
               ObjectSetInteger(m_chartId,slName,OBJPROP_STYLE,STYLE_DOT);
               ObjectSetInteger(m_chartId,slName,OBJPROP_WIDTH,1);
               ObjectSetInteger(m_chartId,slName,OBJPROP_SELECTABLE,false);
               RegisterActiveObject(activeObjects,slName);
              }
           }

         if(pos.TakeProfit() > 0)
           {
            string tpName = StringFormat("%sTP_%I64u",m_markerPrefix,ticket);
            if(EnsureObject(tpName,OBJ_HLINE))
              {
               ObjectSetDouble(m_chartId,tpName,OBJPROP_PRICE,0,pos.TakeProfit());
               ObjectSetInteger(m_chartId,tpName,OBJPROP_COLOR,m_positiveColor);
               ObjectSetInteger(m_chartId,tpName,OBJPROP_STYLE,STYLE_DASH);
               ObjectSetInteger(m_chartId,tpName,OBJPROP_WIDTH,1);
               ObjectSetInteger(m_chartId,tpName,OBJPROP_SELECTABLE,false);
               RegisterActiveObject(activeObjects,tpName);
              }
           }
        }
     }

   void              DrawSignalMarkers(string &activeObjects[])
     {
      datetime now = TimeCurrent();
      for(int i=0;i<ArraySize(m_signalRows);i++)
        {
         double price = ResolveSignalPrice(m_signalRows[i]);
         if(price <= 0.0)
            continue;

         datetime markerTime = (m_signalRows[i].timestamp == 0 ? now : m_signalRows[i].timestamp) + (i*60);
         string sanitized = SanitizeName(m_signalRows[i].strategy + "_" + m_signalRows[i].symbol + "_" + IntegerToString(i));
         string sigName = StringFormat("%sSIG_%s",m_markerPrefix,sanitized);
         ENUM_OBJECT arrowType = (m_signalRows[i].type==ORDER_TYPE_BUY ? OBJ_ARROW_BUY : OBJ_ARROW_SELL);
         color arrowColor = (m_signalRows[i].type==ORDER_TYPE_BUY ? m_positiveColor : m_negativeColor);
         if(EnsureObject(sigName,arrowType))
           {
            ObjectSetInteger(m_chartId,sigName,OBJPROP_TIME,0,markerTime);
            ObjectSetDouble(m_chartId,sigName,OBJPROP_PRICE,0,price);
            ObjectSetInteger(m_chartId,sigName,OBJPROP_COLOR,arrowColor);
            ObjectSetInteger(m_chartId,sigName,OBJPROP_WIDTH,1);
            ObjectSetInteger(m_chartId,sigName,OBJPROP_SELECTABLE,false);
            ObjectSetString(m_chartId,sigName,OBJPROP_TOOLTIP,
                            StringFormat("Signal %s %s conf %.1f",
                                         m_signalRows[i].strategy,
                                         m_signalRows[i].symbol,
                                         m_signalRows[i].confidence));
            RegisterActiveObject(activeObjects,sigName);
           }
        }
     }

   void              DrawExitMarkers(string &activeObjects[])
     {
      datetime now = TimeCurrent();
      datetime dayStart = now - (now % 86400);
      int drawn = 0;
      for(int i=HistoryDealsTotal()-1;i>=0 && drawn<10;i--)
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
         double price = HistoryDealGetDouble(ticket,DEAL_PRICE);
         double profit = HistoryDealGetDouble(ticket,DEAL_PROFIT)
                         + HistoryDealGetDouble(ticket,DEAL_SWAP)
                         + HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         string exitName = StringFormat("%sEXIT_%I64u",m_markerPrefix,ticket);
         if(EnsureObject(exitName,OBJ_ARROW))
           {
            ObjectSetInteger(m_chartId,exitName,OBJPROP_TIME,0,dealTime);
            ObjectSetDouble(m_chartId,exitName,OBJPROP_PRICE,0,price);
            ObjectSetInteger(m_chartId,exitName,OBJPROP_ARROWCODE,159);
            ObjectSetInteger(m_chartId,exitName,OBJPROP_COLOR,(profit >= 0.0 ? m_positiveColor : m_negativeColor));
            ObjectSetInteger(m_chartId,exitName,OBJPROP_WIDTH,1);
            ObjectSetInteger(m_chartId,exitName,OBJPROP_SELECTABLE,false);
            ObjectSetString(m_chartId,exitName,OBJPROP_TOOLTIP,
                            StringFormat("Exit PnL %.2f",profit));
            RegisterActiveObject(activeObjects,exitName);
           }
         drawn++;
        }
     }

   double            ResolveSignalPrice(const SignalInfo &signal) const
     {
      if(!SymbolSelect(signal.symbol,true))
         return(0.0);
      double bid = 0.0, ask = 0.0;
      if(!SymbolInfoDouble(signal.symbol,SYMBOL_BID,bid) ||
         !SymbolInfoDouble(signal.symbol,SYMBOL_ASK,ask))
         return(0.0);
      return(signal.type==ORDER_TYPE_BUY ? ask : bid);
     }

   void              RegisterActiveObject(string &list[],const string name) const
     {
      int newIndex = ArraySize(list);
      ArrayResize(list,newIndex+1);
      list[newIndex] = name;
     }

   bool              ContainsObject(const string &list[],const string name) const
     {
      for(int i=0;i<ArraySize(list);i++)
        {
         if(list[i] == name)
            return(true);
        }
      return(false);
     }

   void              CleanupMarkerObjects(const string &activeObjects[])
     {
      int total = ObjectsTotal(m_chartId,0,-1);
      for(int i=total-1;i>=0;i--)
        {
         string objName = ObjectName(m_chartId,i,0,-1);
         if(StringFind(objName,m_markerPrefix) != 0)
            continue;
         if(!ContainsObject(activeObjects,objName))
            ObjectDelete(m_chartId,objName);
        }
     }

   bool              EnsureObject(const string name,const ENUM_OBJECT type)
     {
      if(ObjectFind(m_chartId,name) != -1)
         return(true);
      return(ObjectCreate(m_chartId,name,type,0,0,0));
     }

   string            SanitizeName(string value) const
     {
      StringReplace(value," ","_");
      StringReplace(value,"|","_");
      StringReplace(value,":","_");
      StringReplace(value,"/","_");
      return(value);
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
   if(!g_overlay.Init(ChartID()))
      return(INIT_FAILED);
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

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   g_overlay.OnChartEvent(id,sparam);
  }
