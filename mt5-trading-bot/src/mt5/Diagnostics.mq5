#property strict
#property script_show_inputs

#include "Mt5Common.mqh"
#include "OrderManager.mq5"
#include "MarketData.mq5"
#include "AccountManager.mq5"
#include "PositionTracker.mq5"

input string         InpSymbol          = _Symbol;
input ENUM_TIMEFRAMES InpTimeframe      = PERIOD_M5;
input uint           InpMagicNumber     = 202501;
input int            InpHistoryMinutes  = 120;

OrderManager    g_orderManager;
MarketData      g_marketData;
AccountManager  g_accountManager;
PositionTracker g_positionTracker;

int OnInit()
{
   if(!Mt5Common::EnsureConnection("Diagnostics OnInit", 5, 250))
      return INIT_FAILED;

   g_marketData.Init(InpSymbol, InpTimeframe);
   g_orderManager.Init(InpSymbol, InpMagicNumber);
   g_accountManager.Init();
   g_positionTracker.Init(InpMagicNumber);

   return INIT_SUCCEEDED;
}

void OnStart()
{
   if(!RunDiagnostics())
      Print("MT5 Diagnostics: Issues detected. Check previous log lines.");
   else
      Print("MT5 Diagnostics: Environment healthy.");
}

bool RunDiagnostics()
{
   bool status = true;

   if(!g_accountManager.Refresh())
   {
      Print("Diagnostics: account refresh failed.");
      status = false;
   }

   if(g_positionTracker.Refresh() == 0)
      Print("Diagnostics: no open positions detected.");

   MqlTick tick;
   if(!g_marketData.GetLastTick(tick))
   {
      Print("Diagnostics: failed to receive latest tick.");
      status = false;
   }
   else
   {
      PrintFormat("Diagnostics: last tick bid=%.5f ask=%.5f volume=%.2f", tick.bid, tick.ask, tick.volume);
   }

   MqlRates rates[];
   const int copied = g_marketData.CopyBars(rates, 5);
   if(copied <= 0)
   {
      Print("Diagnostics: unable to copy recent bars.");
      status = false;
   }
   else
   {
      const int idx = copied - 1;
      PrintFormat("Diagnostics: latest bar close=%.5f high=%.5f low=%.5f", rates[idx].close, rates[idx].high, rates[idx].low);
   }

   const datetime toTime   = TimeCurrent();
   const datetime fromTime = toTime - InpHistoryMinutes * 60;
   g_positionTracker.RefreshHistory(fromTime, toTime);

   PrintFormat("Diagnostics summary: positions=%d history=%d equity=%.2f free_margin=%.2f floating_pnl=%.2f",
               g_positionTracker.PositionsCount(),
               g_positionTracker.HistoryCount(),
               g_accountManager.Equity(),
               g_accountManager.FreeMargin(),
               g_positionTracker.TotalFloatingPnL());

   return status;
}
