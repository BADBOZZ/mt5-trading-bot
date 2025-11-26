#property copyright "MT5 Trading Bot"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

struct TradePerformanceStats
  {
   double  netProfit;
   double  grossProfit;
   double  grossLoss;
   double  sharpeRatio;
   double  maxDrawdown;
   double  maxDrawdownPct;
   double  winRate;
   double  profitFactor;
   double  recoveryFactor;
   double  riskFreeRate;
   double  sampleSize;
  };

class CPerformanceAnalyzer
  {
public:
   double Sharpe(const double &returns[], const int length, const double riskFreeRate = 0.0)
     {
      if(length < 2)
         return 0.0;

      double mean = 0.0;
      for(int i = 0; i < length; ++i)
         mean += returns[i];
      mean /= length;

      double variance = 0.0;
      for(int j = 0; j < length; ++j)
        {
         const double diff = returns[j] - mean;
         variance += diff * diff;
        }

      if(variance <= 0.0)
         return 0.0;

      const double stdev = MathSqrt(variance / (length - 1));
      if(stdev == 0.0)
         return 0.0;

      const double dailyRf = riskFreeRate / 252.0;
      const double excess = (mean - dailyRf);
      return excess / stdev * MathSqrt(252.0);
     }

   double MaxDrawdown(const double &equity[], const int length, double &maxPct)
     {
      if(length == 0)
        {
         maxPct = 0.0;
         return 0.0;
        }

      double peak = equity[0];
      double maxDD = 0.0;
      double maxDDPct = 0.0;
      for(int i = 0; i < length; ++i)
        {
         if(equity[i] > peak)
            peak = equity[i];

         const double dd = peak - equity[i];
         if(dd > maxDD)
           {
            maxDD = dd;
            if(peak > 0.0)
               maxDDPct = 100.0 * (dd / peak);
           }
        }

      maxPct = maxDDPct;
      return maxDD;
     }

   double WinRate(const double &tradeResults[], const int length)
     {
      int wins = 0;
      int trades = 0;
      for(int i = 0; i < length; ++i)
        {
         if(tradeResults[i] == 0.0)
            continue;
         trades++;
         if(tradeResults[i] > 0.0)
            wins++;
        }

      if(trades == 0)
         return 0.0;
      return 100.0 * (double)wins / (double)trades;
     }

   double ProfitFactor(const double grossProfit, const double grossLoss)
     {
      if(grossLoss >= 0.0)
         return 0.0;
      return grossProfit / MathAbs(grossLoss);
     }

   double RecoveryFactor(const double netProfit, const double maxDrawdown)
     {
      if(maxDrawdown == 0.0)
         return 0.0;
      return netProfit / maxDrawdown;
     }

   void Evaluate(const double &equityCurve[],
                 const int equityLen,
                 const double &tradeResults[],
                 const int tradeLen,
                 const double riskFreeRate,
                 TradePerformanceStats &stats)
     {
      stats.netProfit = 0.0;
      stats.grossProfit = 0.0;
      stats.grossLoss = 0.0;
      stats.sharpeRatio = 0.0;
      stats.maxDrawdown = 0.0;
      stats.maxDrawdownPct = 0.0;
      stats.winRate = 0.0;
      stats.profitFactor = 0.0;
      stats.recoveryFactor = 0.0;
      stats.riskFreeRate = riskFreeRate;
      stats.sampleSize = tradeLen;

      stats.sharpeRatio = Sharpe(tradeResults, tradeLen, riskFreeRate);
      stats.maxDrawdown = MaxDrawdown(equityCurve, equityLen, stats.maxDrawdownPct);
      stats.winRate = WinRate(tradeResults, tradeLen);

      stats.grossProfit = 0.0;
      stats.grossLoss = 0.0;
      for(int i = 0; i < tradeLen; ++i)
        {
         if(tradeResults[i] > 0.0)
            stats.grossProfit += tradeResults[i];
         else
            stats.grossLoss += tradeResults[i];
        }

      stats.netProfit = stats.grossProfit + stats.grossLoss;
      stats.profitFactor = ProfitFactor(stats.grossProfit, stats.grossLoss);
      stats.recoveryFactor = RecoveryFactor(stats.netProfit, stats.maxDrawdown);
     }

   bool ExportHistory(const string filename)
     {
      const datetime from = 0;
      const datetime to = TimeCurrent();
      if(!HistorySelect(from, to))
         return false;

      const int deals = HistoryDealsTotal();
      if(deals == 0)
         return false;

      ResetLastError();
      const int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ";");
      if(fileHandle == INVALID_HANDLE)
        {
         PrintFormat("Failed to open report file %s. Error %d", filename, GetLastError());
         return false;
        }

      FileWrite(fileHandle, "Ticket", "Type", "Volume", "Price", "Profit", "Swap", "Commission", "Time");
      for(int i = 0; i < deals; ++i)
        {
         const ulong ticket = HistoryDealGetTicket(i);
         const double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         const double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         const double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         const double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
         const double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
         const ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         const datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

         FileWrite(fileHandle, (string)ticket, EnumToString(type), DoubleToString(volume, 2), DoubleToString(price, _Digits),
                   DoubleToString(profit, 2), DoubleToString(swap, 2), DoubleToString(commission, 2), TimeToString(time, TIME_DATE|TIME_MINUTES));
        }

      FileClose(fileHandle);
      return true;
     }
  };
