#pragma once

#include <Math\Stat.mqh>

struct StrategyPerformance
  {
   string  name;
   double  winRate;
   double  avgProfit;
   double  avgLoss;
   int     tradesToday;
   double  bestTrade;
   double  worstTrade;
  };

class PerformanceDashboard
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
   int      m_lastHeight;

   string   m_bgName;
   string   m_textName;

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

   string            ColorToHex(const color clr) const
     {
      return(StringFormat("#%02X%02X%02X",GetRValue(clr),GetGValue(clr),GetBValue(clr)));
     }

   string            FormatPnL(const double value) const
     {
      color useColor = (value >= 0.0 ? m_positiveColor : m_negativeColor);
      return(StringFormat("<color=%s>%s</color>",ColorToHex(useColor),DoubleToString(value,2)));
     }

   void              SyncVisibility()
     {
      ObjectSetInteger(m_chartId,m_bgName,OBJPROP_HIDDEN,!m_visible);
      ObjectSetInteger(m_chartId,m_textName,OBJPROP_HIDDEN,!m_visible);
     }

public:
                     PerformanceDashboard()
                     : m_chartId(0),
                       m_prefix(""),
                       m_ready(false),
                       m_visible(true),
                       m_corner(CORNER_RIGHT_UPPER),
                       m_offsetX(0),
                       m_offsetY(0),
                       m_width(320),
                       m_fontSize(10),
                       m_textColor(clrWhite),
                       m_positiveColor(clrLime),
                       m_negativeColor(clrTomato),
                       m_backgroundColor(clrBlack),
                       m_lastHeight(200)
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
      m_bgName  = m_prefix + "_PERF_BG";
      m_textName= m_prefix + "_PERF_TEXT";
      if(!CreateObjects())
         return(false);
      m_ready   = true;
      return(true);
     }

   void              Update(const StrategyPerformance &stats[])
     {
      if(!m_ready)
         return;

      if(!m_visible)
         return;

      CreateObjects();

      string buffer = "PERFORMANCE DASHBOARD\n";

      if(ArraySize(stats) == 0)
        {
         buffer += "No closed trades today\n";
        }
      else
        {
         buffer += "STR | WIN% | AVG+ | AVG- | TRD | BEST | WORST\n";
         buffer += "------------------------------------------------\n";
         for(int i=0;i<ArraySize(stats);i++)
           {
            buffer += StringFormat("%s | %.1f%% | %s | %s | %d | %s | %s\n",
                                   stats[i].name,
                                   stats[i].winRate,
                                   FormatPnL(stats[i].avgProfit),
                                   FormatPnL(-MathAbs(stats[i].avgLoss)),
                                   stats[i].tradesToday,
                                   FormatPnL(stats[i].bestTrade),
                                   FormatPnL(stats[i].worstTrade));
           }
        }

      ObjectSetString(m_chartId,m_textName,OBJPROP_TEXT,buffer);
      string lines[];
      int lineCount = StringSplit(buffer,'\n',lines);
      if(lineCount <= 0)
         lineCount = 1;
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
