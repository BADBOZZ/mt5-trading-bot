//+------------------------------------------------------------------+
//| UltimateEA.mq5                                                   |
//| The Ultimate MetaTrader 5 Expert Advisor                        |
//| Multi-strategy, multi-pair trading with visual overlay          |
//+------------------------------------------------------------------+
#property copyright "MetaTrader 5 Trading Bot"
#property link      "https://github.com/BADBOZZ/mt5-trading-bot"
#property version   "1.00"
#property strict
#property description "Ultimate MQL5 EA: Multi-strategy, multi-pair trading with visual overlay"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

// Include risk management modules
#include "src\\config\\risk-config.mqh"
#include "src\\risk\\RiskManager.mq5"
#include "src\\risk\\RiskLimits.mq5"
#include "src\\risk\\SafetyChecks.mq5"

// Include UI overlay
#include "src\\ui\\ChartOverlay.mq5"

// Input parameters
input group "=== Symbol Configuration ==="
input string InpSymbolsMasterList = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,NZDUSD,USDCHF";
input string InpTrendSymbols = "";
input string InpMeanRevSymbols = "";
input string InpBreakoutSymbols = "";

input group "=== Strategy Configuration ==="
input bool InpEnableTrendStrategy = true;
input bool InpEnableMeanReversion = true;
input bool InpEnableBreakout = true;
input bool InpEnableAIStrategy = false;

input group "=== Risk Management ==="
input double InpRiskPercentPerTrade = 1.0;
input double InpMaxDrawdownPercent = 20.0;
input double InpDailyLossLimitPercent = 5.0;
input int InpMaxPositionsPerSymbol = 2;
input int InpMaxTotalPositions = 10;
input double InpMaxLotPerTrade = 1.0;
input double InpMaxTotalExposureLots = 5.0;

input group "=== Visual Overlay ==="
input bool InpShowOverlay = true;
input int InpOverlayRefreshSeconds = 1;
input int InpOverlayFontSize = 10;
input color InpOverlayPrimaryColor = clrWhite;
input color InpOverlayPositiveColor = clrLime;
input color InpOverlayNegativeColor = clrTomato;

input group "=== Trading Settings ==="
input int InpMagicNumber = 123456;
input int InpSlippage = 10;
input string InpTradeComment = "UltimateEA";

// Global objects
CTrade trade;
ChartOverlayController g_overlay;
string g_symbols[];
bool g_initialized = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade parameters
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   // Parse symbol list
   if(!ParseSymbolList(InpSymbolsMasterList, g_symbols))
   {
      Print("ERROR: Failed to parse symbol list");
      return INIT_FAILED;
   }
   
   Print("UltimateEA initialized with ", ArraySize(g_symbols), " symbols");
   
   // Initialize overlay
   if(InpShowOverlay)
   {
      if(!g_overlay.Init(ChartID()))
      {
         Print("WARNING: Overlay initialization failed, continuing without overlay");
      }
      else
      {
         Print("Visual overlay initialized successfully");
      }
   }
   
   // Initialize risk limits
   RiskLimits::EnsureDailyContext();
   
   // Set up timer for periodic updates
   EventSetTimer(InpOverlayRefreshSeconds);
   
   g_initialized = true;
   Print("UltimateEA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_overlay.Shutdown();
   Print("UltimateEA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized)
      return;
   
   // Refresh overlay
   if(InpShowOverlay)
      g_overlay.Refresh();
   
   // Process each symbol
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      string symbol = g_symbols[i];
      
      if(!SymbolSelect(symbol, true))
         continue;
      
      // Check if we can trade this symbol
      if(!CanTradeSymbol(symbol))
         continue;
      
      // Process strategies
      if(InpEnableTrendStrategy && IsSymbolInList(symbol, InpTrendSymbols))
      {
         ProcessTrendStrategy(symbol);
      }
      
      if(InpEnableMeanReversion && IsSymbolInList(symbol, InpMeanRevSymbols))
      {
         ProcessMeanReversionStrategy(symbol);
      }
      
      if(InpEnableBreakout && IsSymbolInList(symbol, InpBreakoutSymbols))
      {
         ProcessBreakoutStrategy(symbol);
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_initialized)
      return;
   
   // Refresh overlay
   if(InpShowOverlay)
      g_overlay.Refresh();
   
   // Update risk limits
   RiskLimits::EnsureDailyContext();
   RiskLimits::UpdatePeakEquity();
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(InpShowOverlay)
      g_overlay.OnChartEvent(id, sparam);
}

//+------------------------------------------------------------------+
//| Parse comma-separated symbol list                                |
//+------------------------------------------------------------------+
bool ParseSymbolList(string symbolList, string &symbols[])
{
   ArrayResize(symbols, 0);
   
   if(symbolList == "")
      return false;
   
   string parts[];
   int count = StringSplit(symbolList, ',', parts);
   
   if(count == 0)
      return false;
   
   ArrayResize(symbols, count);
   for(int i = 0; i < count; i++)
   {
      StringTrimLeft(parts[i]);
      StringTrimRight(parts[i]);
      symbols[i] = parts[i];
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if symbol is in list (or use master list if empty)         |
//+------------------------------------------------------------------+
bool IsSymbolInList(string symbol, string symbolList)
{
   if(symbolList == "")
      return true; // Use master list
   
   string parts[];
   int count = StringSplit(symbolList, ',', parts);
   for(int i = 0; i < count; i++)
   {
      StringTrimLeft(parts[i]);
      StringTrimRight(parts[i]);
      if(parts[i] == symbol)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if we can trade a symbol                                   |
//+------------------------------------------------------------------+
bool CanTradeSymbol(string symbol)
{
   // Safety checks
   if(!SafetyChecks::PreTradeValidation(symbol, ORDER_TYPE_BUY, 0.01, 0.0))
      return false;
   
   // Check position limits
   if(CountPositionsForSymbol(symbol) >= InpMaxPositionsPerSymbol)
      return false;
   
   if(CountTotalPositions() >= InpMaxTotalPositions)
      return false;
   
   // Check risk limits
   if(RiskLimits::IsEmergencyStopActive())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Count positions for a symbol                                    |
//+------------------------------------------------------------------+
int CountPositionsForSymbol(string symbol)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count total positions                                            |
//+------------------------------------------------------------------+
int CountTotalPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Process Trend Following Strategy                                 |
//+------------------------------------------------------------------+
void ProcessTrendStrategy(string symbol)
{
   // Simple EMA crossover strategy
   int emaFastHandle = iMA(symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlowHandle = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE)
      return;
   
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) < 2)
      return;
   if(CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) < 2)
      return;
   
   // Buy signal: fast EMA crosses above slow EMA
   if(emaFast[1] > emaSlow[1] && emaFast[0] <= emaSlow[0])
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double stopLoss = ask - 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double takeProfit = ask + 100 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      double lotSize = RiskManager::CalculateLotSize(symbol, ask, stopLoss);
      
      if(lotSize > 0 && RiskManager::CanOpenPosition(symbol, lotSize))
      {
         trade.Buy(lotSize, symbol, ask, stopLoss, takeProfit, InpTradeComment);
      }
   }
   
   // Sell signal: fast EMA crosses below slow EMA
   if(emaFast[1] < emaSlow[1] && emaFast[0] >= emaSlow[0])
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double stopLoss = bid + 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double takeProfit = bid - 100 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      double lotSize = RiskManager::CalculateLotSize(symbol, bid, stopLoss);
      
      if(lotSize > 0 && RiskManager::CanOpenPosition(symbol, lotSize))
      {
         trade.Sell(lotSize, symbol, bid, stopLoss, takeProfit, InpTradeComment);
      }
   }
   
   IndicatorRelease(emaFastHandle);
   IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
//| Process Mean Reversion Strategy                                  |
//+------------------------------------------------------------------+
void ProcessMeanReversionStrategy(string symbol)
{
   // RSI-based mean reversion
   int rsiHandle = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   
   if(rsiHandle == INVALID_HANDLE)
      return;
   
   double rsi[];
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) < 1)
   {
      IndicatorRelease(rsiHandle);
      return;
   }
   
   // Oversold: RSI < 30, buy signal
   if(rsi[0] < 30)
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double stopLoss = ask - 30 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double takeProfit = ask + 60 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      double lotSize = RiskManager::CalculateLotSize(symbol, ask, stopLoss);
      
      if(lotSize > 0 && RiskManager::CanOpenPosition(symbol, lotSize))
      {
         trade.Buy(lotSize, symbol, ask, stopLoss, takeProfit, InpTradeComment);
      }
   }
   
   // Overbought: RSI > 70, sell signal
   if(rsi[0] > 70)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double stopLoss = bid + 30 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double takeProfit = bid - 60 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      double lotSize = RiskManager::CalculateLotSize(symbol, bid, stopLoss);
      
      if(lotSize > 0 && RiskManager::CanOpenPosition(symbol, lotSize))
      {
         trade.Sell(lotSize, symbol, bid, stopLoss, takeProfit, InpTradeComment);
      }
   }
   
   IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Process Breakout Strategy                                         |
//+------------------------------------------------------------------+
void ProcessBreakoutStrategy(string symbol)
{
   // Simple breakout: price breaks above/below recent high/low
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(symbol, PERIOD_CURRENT, 0, 20, high) < 20)
      return;
   if(CopyLow(symbol, PERIOD_CURRENT, 0, 20, low) < 20)
      return;
   
   double highestHigh = high[ArrayMaximum(high, 0, 20)];
   double lowestLow = low[ArrayMinimum(low, 0, 20)];
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // Breakout above: buy
   if(ask > highestHigh)
   {
      double stopLoss = ask - 40 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double takeProfit = ask + 80 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      double lotSize = RiskManager::CalculateLotSize(symbol, ask, stopLoss);
      
      if(lotSize > 0 && RiskManager::CanOpenPosition(symbol, lotSize))
      {
         trade.Buy(lotSize, symbol, ask, stopLoss, takeProfit, InpTradeComment);
      }
   }
   
   // Breakout below: sell
   if(currentPrice < lowestLow)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double stopLoss = bid + 40 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double takeProfit = bid - 80 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      double lotSize = RiskManager::CalculateLotSize(symbol, bid, stopLoss);
      
      if(lotSize > 0 && RiskManager::CanOpenPosition(symbol, lotSize))
      {
         trade.Sell(lotSize, symbol, bid, stopLoss, takeProfit, InpTradeComment);
      }
   }
}

//+------------------------------------------------------------------+

