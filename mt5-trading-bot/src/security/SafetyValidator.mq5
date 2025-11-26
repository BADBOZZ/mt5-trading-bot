#property strict
#property script_show_inputs

input double InpMaxDrawdownPct   = 20.0;   // Maximum allowed drawdown in percent
input double InpDailyLossPct     = 5.0;    // Daily realized loss limit in percent
input double InpRiskPerTradePct  = 2.0;    // Risk per trade as percent of balance
input double InpMaxExposurePct   = 50.0;   // Maximum total exposure relative to equity
input double InpMaxPositionPct   = 10.0;   // Maximum position value relative to balance
input double InpMinMarginLevel   = 150.0;  // Minimum acceptable margin level
input int    InpCooldownMinutes  = 60;     // Cooldown minutes after a loss

double   g_peakEquity      = 0.0;
datetime g_lastLossTime    = 0;
bool     g_cooldownActive  = false;

int OnInit()
{
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
}

void OnStart()
{
   if(!RunSafetyAudit())
      Print("SafetyValidator: environment is NOT safe for trading.");
   else
      Print("SafetyValidator: all safety checks passed.");
}

bool RunSafetyAudit()
{
   bool ok = true;

   ok &= CheckMarginLevel();
   ok &= CheckDrawdown();
   ok &= CheckDailyLoss();
   ok &= CheckExposure();
   ok &= CheckCooldown();

   return ok;
}

bool CheckMarginLevel()
{
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel == 0.0 || marginLevel < InpMinMarginLevel)
   {
      PrintFormat("SafetyValidator: margin level %.2f%% below minimum %.2f%%.", marginLevel, InpMinMarginLevel);
      return false;
   }
   return true;
}

bool CheckDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
   {
      Print("SafetyValidator: equity unavailable, drawdown cannot be evaluated.");
      return false;
   }

   if(equity > g_peakEquity)
      g_peakEquity = equity;

   if(g_peakEquity == 0.0)
      return true;

   double drawdownPct = 100.0 * (g_peakEquity - equity) / g_peakEquity;
   if(drawdownPct > InpMaxDrawdownPct)
   {
      PrintFormat("SafetyValidator: drawdown %.2f%% exceeds limit %.2f%%.", drawdownPct, InpMaxDrawdownPct);
      return false;
   }
   return true;
}

bool CheckDailyLoss()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
   {
      Print("SafetyValidator: invalid account balance for daily loss check.");
      return false;
   }

   double realized = CalculateDailyRealizedPnL();
   double limit = balance * InpDailyLossPct / 100.0;

   if(realized < -limit)
   {
      PrintFormat("SafetyValidator: daily PnL %.2f breaches loss limit %.2f.", realized, -limit);
      return false;
   }
   return true;
}

double CalculateDailyRealizedPnL()
{
   datetime now = TimeCurrent();
   datetime dayStart = StringToTime(TimeToString(now, TIME_DATE));

   if(!HistorySelect(dayStart, now))
      return 0.0;

   double pnl = 0.0;
   int deals = HistoryDealsTotal();

   for(int i = 0; i < deals; ++i)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(!HistoryDealSelect(ticket))
         continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
         continue;

      pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
   }

   return pnl;
}

bool CheckExposure()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
   {
      Print("SafetyValidator: equity unavailable for exposure calculation.");
      return false;
   }

   double totalNotional = 0.0;
   int positions = PositionsTotal();

   for(int i = 0; i < positions; ++i)
   {
      if(!PositionSelectByIndex(i))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double contract = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contract == 0.0)
         contract = 100000.0;

      totalNotional += volume * contract * price;
   }

   double exposurePct = 100.0 * totalNotional / equity;
   if(exposurePct > InpMaxExposurePct)
   {
      PrintFormat("SafetyValidator: exposure %.2f%% exceeds limit %.2f%%.", exposurePct, InpMaxExposurePct);
      return false;
   }
   return true;
}

bool CheckCooldown()
{
   if(!g_cooldownActive)
      return true;

   int elapsedMinutes = (int)((TimeCurrent() - g_lastLossTime) / 60);
   if(elapsedMinutes < InpCooldownMinutes)
   {
      int remaining = InpCooldownMinutes - elapsedMinutes;
      PrintFormat("SafetyValidator: cooldown active. %d minute(s) remaining.", remaining);
      return false;
   }

   g_cooldownActive = false;
   return true;
}

void RegisterLoss(double profit)
{
   if(profit < 0.0)
   {
      g_cooldownActive = true;
      g_lastLossTime = TimeCurrent();
   }
}

bool ValidateTrade(
   const string symbol,
   const ENUM_ORDER_TYPE orderType,
   const double entryPrice,
   const double stopLoss,
   const double takeProfit,
   const double lots
)
{
   if(entryPrice <= 0.0 || stopLoss <= 0.0 || lots <= 0.0)
   {
      Print("SafetyValidator: invalid pricing or lot size.");
      return false;
   }

   if(!CheckPositionSize(symbol, lots))
      return false;

   if(!CheckRiskPerTrade(entryPrice, stopLoss))
      return false;

   double priceDiff = MathAbs(entryPrice - stopLoss);
   if(orderType == ORDER_TYPE_BUY && stopLoss >= entryPrice)
   {
      Print("SafetyValidator: stop loss must be below entry for buy orders.");
      return false;
   }
   if(orderType == ORDER_TYPE_SELL && stopLoss <= entryPrice)
   {
      Print("SafetyValidator: stop loss must be above entry for sell orders.");
      return false;
   }

   if(takeProfit > 0.0)
   {
      double reward = MathAbs(takeProfit - entryPrice);
      if(priceDiff == 0.0 || reward / priceDiff < 2.0)
      {
         Print("SafetyValidator: reward/risk ratio is below 2:1.");
         return false;
      }
   }

   return true;
}

bool CheckPositionSize(const string symbol, const double lots)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return false;

   double contract = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(price == 0.0)
      price = SymbolInfoDouble(symbol, SYMBOL_ASK);

   double positionValue = lots * contract * price;
   double maxPositionValue = balance * InpMaxPositionPct / 100.0;

   if(positionValue > maxPositionValue)
   {
      PrintFormat("SafetyValidator: position value %.2f exceeds max %.2f.", positionValue, maxPositionValue);
      return false;
   }

   return true;
}

bool CheckRiskPerTrade(const double entryPrice, const double stopLoss)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return false;

   double priceDiff = MathAbs(entryPrice - stopLoss);
   if(priceDiff == 0.0)
      return false;

   double maxLoss = balance * InpRiskPerTradePct / 100.0;
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contract == 0.0)
      contract = 100000.0;

   double impliedLots = maxLoss / (priceDiff * contract);
   if(impliedLots <= 0.0)
   {
      Print("SafetyValidator: unable to calculate risk-based lot size.");
      return false;
   }

   return true;
}
