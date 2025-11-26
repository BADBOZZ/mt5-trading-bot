//+------------------------------------------------------------------+
//|  PerformanceAnalyzer.mq5                                         |
//|  Consolidated MT5 Strategy Tester analytics helper.              |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

struct TradeSnapshot
  {
   double   profit;
   double   balance;
   bool     is_win;
  };

//+------------------------------------------------------------------+
//| Utility: collect closed-trade snapshots                           |
//+------------------------------------------------------------------+
bool CollectClosedTrades(TradeSnapshot &buffer[])
  {
   if(!HistorySelect(0,TimeCurrent()))
      return false;

   int total=HistoryDealsTotal();
   if(total<=0)
      return false;

   ArrayResize(buffer,0);
   ArrayResize(buffer,total);
   double running_balance=AccountInfoDouble(ACCOUNT_BALANCE);

   int idx=0;
   for(int i=0;i<total;i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
         continue;

      long entry_type=HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(entry_type!=DEAL_ENTRY_OUT)
         continue;

      double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      running_balance+=profit;

      buffer[idx].profit=profit;
      buffer[idx].balance=running_balance;
      buffer[idx].is_win=(profit>0.0);
      idx++;
     }

   ArrayResize(buffer,idx);
   return (idx>0);
  }

//+------------------------------------------------------------------+
//| Metric: Sharpe ratio                                              |
//+------------------------------------------------------------------+
double CalculateSharpeRatio(const double &returns[],double risk_free=0.0)
  {
   int total=ArraySize(returns);
   if(total<=1)
      return 0.0;

   double mean=0.0;
   for(int i=0;i<total;i++)
      mean+=returns[i]-risk_free;
   mean/=total;

   double variance=0.0;
   for(int j=0;j<total;j++)
     {
      double diff=(returns[j]-risk_free)-mean;
      variance+=diff*diff;
     }
   variance/=(total-1);

   if(variance<=0.0)
      return 0.0;

   double std_dev=MathSqrt(variance);
   return mean/std_dev*MathSqrt(252.0);
  }

//+------------------------------------------------------------------+
//| Metric: Maximum drawdown                                          |
//+------------------------------------------------------------------+
double CalculateMaxDrawdown(const TradeSnapshot &series[])
  {
   double peak=-DBL_MAX;
   double max_dd=0.0;
   for(int i=0;i<ArraySize(series);i++)
     {
      double point=series[i].balance;
      if(point>peak)
         peak=point;
      double dd=peak-point;
      if(dd>max_dd)
         max_dd=dd;
     }
   return max_dd;
  }

//+------------------------------------------------------------------+
//| Metric: Win rate                                                  |
//+------------------------------------------------------------------+
double CalculateWinRate(const TradeSnapshot &series[])
  {
   int total=ArraySize(series);
   if(total==0)
      return 0.0;
   int wins=0;
   for(int i=0;i<total;i++)
     {
      if(series[i].is_win)
         wins++;
     }
   return (double)wins/(double)total;
  }

//+------------------------------------------------------------------+
//| Metric: Profit factor                                             |
//+------------------------------------------------------------------+
double CalculateProfitFactor(const TradeSnapshot &series[])
  {
   double gross_profit=0.0;
   double gross_loss=0.0;
   for(int i=0;i<ArraySize(series);i++)
     {
      if(series[i].profit>0.0)
         gross_profit+=series[i].profit;
      else
         gross_loss+=series[i].profit;
     }
   if(gross_loss>=0.0)
      return (gross_profit>0.0) ? DBL_MAX : 0.0;
   return MathAbs(gross_profit/gross_loss);
  }

//+------------------------------------------------------------------+
//| Metric: Recovery factor                                           |
//+------------------------------------------------------------------+
double CalculateRecoveryFactor(const TradeSnapshot &series[])
  {
   double net_profit=0.0;
   for(int i=0;i<ArraySize(series);i++)
      net_profit+=series[i].profit;

   double mdd=CalculateMaxDrawdown(series);
   if(mdd<=0.0)
      return (net_profit>0.0) ? DBL_MAX : 0.0;
   return net_profit/mdd;
  }

//+------------------------------------------------------------------+
//| Aggregate all metrics for display                                 |
//+------------------------------------------------------------------+
void PrintPerformanceReport()
  {
   TradeSnapshot trades[];
   if(!CollectClosedTrades(trades))
     {
      Print("PerformanceAnalyzer: no closed trades detected");
      return;
     }

   double returns[];
   ArrayResize(returns,ArraySize(trades));
   for(int i=0;i<ArraySize(trades);i++)
      returns[i]=trades[i].profit;

   double sharpe=NormalizeDouble(CalculateSharpeRatio(returns),4);
   double max_dd=NormalizeDouble(CalculateMaxDrawdown(trades),2);
   double win_rate=NormalizeDouble(CalculateWinRate(trades),4);
   double profit_factor=NormalizeDouble(CalculateProfitFactor(trades),4);
   double recovery_factor=NormalizeDouble(CalculateRecoveryFactor(trades),4);

   PrintFormat("Sharpe=%.4f | MDD=%.2f | Win%%=%.2f | PF=%.4f | RF=%.4f",
               sharpe,max_dd,win_rate*100.0,profit_factor,recovery_factor);
  }

//+------------------------------------------------------------------+
//| Script entry point (Strategy Tester friendly)                     |
//+------------------------------------------------------------------+
void OnStart()
  {
   PrintPerformanceReport();
  }
