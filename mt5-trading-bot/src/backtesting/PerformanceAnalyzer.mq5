#property strict

//+------------------------------------------------------------------+
//| Performance Analyzer                                             |
//| Collects Strategy Tester statistics directly from MT5 history.   |
//+------------------------------------------------------------------+
class PerformanceAnalyzer
  {
private:
   double            m_initial;
   double            m_equity;
   double            m_peak;
   double            m_max_drawdown;
   double            m_gross_profit;
   double            m_gross_loss;
   int               m_win_count;
   int               m_loss_count;
   double            m_return_sum;
   double            m_return_sq_sum;
   int               m_return_samples;
   datetime          m_first_deal;
   datetime          m_last_deal;

public:
                     PerformanceAnalyzer(void)
     {
      Reset(0.0);
     }

   void              Reset(const double initial_balance)
     {
      m_initial        = initial_balance;
      m_equity         = initial_balance;
      m_peak           = initial_balance;
      m_max_drawdown   = 0.0;
      m_gross_profit   = 0.0;
      m_gross_loss     = 0.0;
      m_win_count      = 0;
      m_loss_count     = 0;
      m_return_sum     = 0.0;
      m_return_sq_sum  = 0.0;
      m_return_samples = 0;
      m_first_deal     = 0;
      m_last_deal      = 0;
     }

   void              FeedDeal(const double profit, const datetime deal_time)
     {
      m_equity += profit;
      if(m_equity > m_peak)
         m_peak = m_equity;
      if(m_peak > 0.0)
        {
         const double dd = (m_peak - m_equity) / m_peak;
         if(dd > m_max_drawdown)
            m_max_drawdown = dd;
        }

      if(profit >= 0.0)
        {
         m_gross_profit += profit;
         m_win_count++;
        }
      else
        {
         m_gross_loss += -profit;
         m_loss_count++;
        }

      if(m_initial > 0.0)
        {
         const double ret = profit / m_initial;
         m_return_sum    += ret;
         m_return_sq_sum += ret * ret;
         m_return_samples++;
        }

      if(m_first_deal == 0 || deal_time < m_first_deal)
         m_first_deal = deal_time;
      if(deal_time > m_last_deal)
         m_last_deal = deal_time;
     }

   bool              AnalyzeHistory(const datetime from_time,
                                    const datetime to_time,
                                    const double initial_balance)
     {
      Reset(initial_balance);
      if(!HistorySelect(from_time, to_time))
        {
         PrintFormat("PerformanceAnalyzer: HistorySelect failed (%d)", GetLastError());
         return(false);
        }

      const uint total = HistoryDealsTotal();
      for(uint i = 0; i < total; ++i)
        {
         const ulong ticket = HistoryDealGetTicket(i);
         const ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
            continue;

         const double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                             + HistoryDealGetDouble(ticket, DEAL_SWAP)
                             + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         const datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         FeedDeal(profit, deal_time);
        }
      return(true);
     }

   double            MaxDrawdown(void)const
     {
      return(m_max_drawdown);
     }

   double            ProfitFactor(void)const
     {
      if(m_gross_loss == 0.0)
         return(m_gross_profit > 0.0 ? DBL_MAX : 0.0);
      return(m_gross_profit / m_gross_loss);
     }

   double            WinRate(void)const
     {
      const int total = m_win_count + m_loss_count;
      if(total == 0)
         return(0.0);
      return((double)m_win_count / (double)total);
     }

   double            SharpeRatio(const double risk_free = 0.0)const
     {
      if(m_return_samples < 2)
         return(0.0);
      const double mean = (m_return_sum / m_return_samples) - risk_free;
      const double variance = (m_return_sq_sum / m_return_samples) - MathPow(m_return_sum / m_return_samples, 2.0);
      if(variance <= 0.0)
         return(0.0);
      return(mean / MathSqrt(variance) * MathSqrt(252.0));
     }

   double            CAGR(void)const
     {
      if(m_first_deal == 0 || m_last_deal <= m_first_deal || m_initial <= 0.0)
         return(0.0);
      double years = (double)(m_last_deal - m_first_deal) / (365.0 * 24.0 * 60.0 * 60.0);
      if(years <= 0.0)
         years = 1.0 / 365.0;
      const double terminal = m_initial > 0.0 ? m_equity / m_initial : 0.0;
      if(terminal <= 0.0)
         return(-1.0);
      return(MathPow(terminal, 1.0 / years) - 1.0);
     }

   double            TotalReturn(void)const
     {
      if(m_initial == 0.0)
         return(0.0);
      return(m_equity / m_initial - 1.0);
     }

   void              LogSummary(void)const
     {
      PrintFormat("Performance => return %.2f%%, maxDD %.2f%%, PF %.2f, winRate %.2f%%, Sharpe %.2f",
                  TotalReturn() * 100.0,
                  m_max_drawdown * 100.0,
                  ProfitFactor(),
                  WinRate() * 100.0,
                  SharpeRatio());
     }
  };
