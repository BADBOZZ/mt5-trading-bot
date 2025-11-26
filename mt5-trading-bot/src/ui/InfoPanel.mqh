#pragma once

#include <ChartObjects\ChartObjectsTxtControls.mqh>

struct StrategyStatus
  {
   string  name;
   string  symbol;
   bool    enabled;
  };

struct RiskSnapshot
  {
   double  dailyPnL;
   double  drawdownPercent;
   double  marginUsed;
   double  balance;
   double  equity;
  };

class InfoPanel
  {
private:
   long     m_chartId;
   string   m_prefix;
   bool     m_ready;
   bool     m_visible;
   ENUM_BASE_CORNER m_corner;
   int      m_offsetX;
   int      m_offsetY;
   int      m_width;
   int      m_fontSize;
   color    m_textColor;
   color    m_positiveColor;
   color    m_negativeColor;
   color    m_backgroundColor;

   string   m_bgName;
   string   m_textName;
   int      m_lastHeight;

   bool              CreateObjects()
     {
      if(ObjectFind(m_chartId,m_bgName) == -1)
        {
         if(!ObjectCreate(m_chartId,m_bgName,OBJ_RECTANGLE_LABEL,0,0,0))
            return(false);
        }

      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_CORNER,m_corner);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_XDISTANCE,m_offsetX);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_YDISTANCE,m_offsetY);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_XSIZE,m_width);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_YSIZE,200);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_BGCOLOR,m_backgroundColor);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_COLOR,m_backgroundColor);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_BACK,true);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_SELECTED,false);

      if(ObjectFind(m_chartId,m_textName) == -1)
        {
         if(!ObjectCreate(m_chartId,m_textName,OBJ_LABEL,0,0,0))
            return(false);
        }

      ObjectSetInteger(m_chartId,m_textName,OBJPROP_CORNER,m_corner);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_XDISTANCE,m_offsetX+8);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_YDISTANCE,m_offsetY+6);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_FONTSIZE,m_fontSize);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_COLOR,m_textColor);
      ObjectSetString(m_chartId,m_textName,OBJPROP_FONT,"Segoe UI");
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_SELECTED,false);
      return(true);
     }

   string            FormatColoredDouble(const double value) const
     {
      color selected = (value >= 0.0 ? m_positiveColor : m_negativeColor);
      return(StringFormat("<color=%s>%s</color>",ColorToHex(selected),DoubleToString(value,2)));
     }

   string            ColorToHex(const color clr) const
     {
      return(StringFormat("#%02X%02X%02X",GetRValue(clr),GetGValue(clr),GetBValue(clr)));
     }

   void              SyncVisibility()
     {
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_HIDDEN,!m_visible);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_HIDDEN,!m_visible);
     }

public:
                     InfoPanel()
                     : m_chartId(0),
                       m_prefix(""),
                       m_ready(false),
                       m_visible(true),
                       m_corner(CORNER_LEFT_LOWER),
                       m_offsetX(5),
                       m_offsetY(5),
                       m_width(280),
                       m_fontSize(10),
                       m_textColor(clrWhite),
                       m_positiveColor(clrLime),
                       m_negativeColor(clrTomato),
                       m_backgroundColor(clrBlack),
                       m_lastHeight(220)
                       {}

   bool              Init(const long chartId,
                          const string prefix,
                          const ENUM_BASE_CORNER corner,
                          const int offsetX,
                          const int offsetY,
                          const int width,
                          const int fontSize,
                          const color textColor,
                          const color positiveColor,
                          const color negativeColor,
                          const color backgroundColor)
     {
      m_chartId = chartId;
      m_prefix  = prefix;
      m_corner  = corner;
      m_offsetX = offsetX;
      m_offsetY = offsetY;
      m_width   = width;
      m_fontSize = fontSize;
      m_textColor = textColor;
      m_positiveColor = positiveColor;
      m_negativeColor = negativeColor;
      m_backgroundColor = backgroundColor;
      m_bgName  = m_prefix + "_INFO_BG";
      m_textName = m_prefix + "_INFO_TEXT";

      if(!CreateObjects())
         return(false);

      m_ready   = true;
      return(true);
     }

   void              Update(const RiskSnapshot &snapshot,const StrategyStatus &statuses[])
     {
      if(!m_ready)
         return;

      if(!m_visible)
         return;

      CreateObjects();

      string content;
      content = "ACCOUNT OVERVIEW\n";
      content += StringFormat("Balance: %s\n",FormatColoredDouble(snapshot.balance));
      content += StringFormat("Equity: %s\n",FormatColoredDouble(snapshot.equity));
      content += StringFormat("Daily P&L: %s\n",FormatColoredDouble(snapshot.dailyPnL));
      content += StringFormat("Drawdown: %s%%\n",FormatColoredDouble(snapshot.drawdownPercent));
      content += StringFormat("Margin Used: %s\n\n",FormatColoredDouble(snapshot.marginUsed));

      content += "STRATEGIES\n";
      if(ArraySize(statuses) == 0)
         content += "- no registered strategies\n";
      else
        {
         for(int i=0;i<ArraySize(statuses);i++)
           {
            string state = statuses[i].enabled ? "<color=#5CFF5C>ENABLED</color>" : "<color=#FF5C5C>DISABLED</color>";
            content += StringFormat("- %s (%s) %s\n",statuses[i].name,statuses[i].symbol,state);
           }
        }

      ObjectSetString(m_chartId,m_textName,OBJPROP_TEXT,content);

      int lineCount = 1;
      string lines[];
      if(StringSplit(content,'\n',lines) > 0)
         lineCount = ArraySize(lines);
      m_lastHeight = lineCount*(m_fontSize+6)+10;
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_YSIZE,m_lastHeight);
      SyncVisibility();
     }

   void              SetVisible(const bool visible)
     {
      m_visible = visible;
      if(!m_ready)
         return;
      SyncVisibility();
     }

   void              SetCorner(const ENUM_BASE_CORNER corner,const int offsetX,const int offsetY)
     {
      m_corner  = corner;
      m_offsetX = offsetX;
      m_offsetY = offsetY;
      if(!m_ready)
         return;
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_CORNER,m_corner);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_XDISTANCE,m_offsetX);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_YDISTANCE,m_offsetY);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_CORNER,m_corner);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_XDISTANCE,m_offsetX+8);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_YDISTANCE,m_offsetY+6);
     }

   void              SetTheme(const int fontSize,const color textColor,const color positiveColor,const color negativeColor,const color bgColor)
     {
      m_fontSize       = fontSize;
      m_textColor      = textColor;
      m_positiveColor  = positiveColor;
      m_negativeColor  = negativeColor;
      m_backgroundColor = bgColor;
      if(!m_ready)
         return;
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_FONTSIZE,m_fontSize);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_COLOR,m_textColor);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_BGCOLOR,m_backgroundColor);
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_COLOR,m_backgroundColor);
     }

   void              Destroy()
     {
      m_ready = false;
      ObjectDelete(m_chartId,m_bgName);
      ObjectDelete(m_chartId,m_textName);
     }

   int               Height() const
     {
      return(m_lastHeight);
     }
  };
