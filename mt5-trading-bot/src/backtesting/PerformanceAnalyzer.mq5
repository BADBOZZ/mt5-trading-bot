#property strict

struct SPerformanceMetrics
  {
   double sharpe;
   double max_drawdown;
   double win_rate;
   double profit_factor;
   double recovery_factor;
  };

class CPerformanceAnalyzer
  {
private:
   double            m_returns[];
   double            m_equity_curve[];
   double            m_risk_free_rate;
   double            m_gross_profit;
   double            m_gross_loss;
   double            m_max_drawdown;
   double            m_peak_equity;
   double            m_net_profit;
   int               m_win_trades;
   int               m_total_trades;

public:
                     CPerformanceAnalyzer(void)
                     {
                        Reset();
                     }

   void              Reset(void)
                     {
                        ArrayFree(m_returns);
                        ArrayFree(m_equity_curve);
                        m_risk_free_rate = 0.0;
                        m_gross_profit = 0.0;
                        m_gross_loss = 0.0;
                        m_max_drawdown = 0.0;
                        m_peak_equity = 0.0;
                        m_net_profit = 0.0;
                        m_win_trades = 0;
                        m_total_trades = 0;
                     }

   void              SetRiskFreeRate(const double annual_rate)
                     {
                        m_risk_free_rate = annual_rate;
                     }

   void              RegisterDeal(const double profit, const double balance_after)
                     {
                        double balance = balance_after;
                        if(balance == 0.0 && ArraySize(m_equity_curve) > 0)
                           balance = m_equity_curve[ArraySize(m_equity_curve) - 1] + profit;
                        m_total_trades++;
                        if(profit >= 0.0)
                           m_win_trades++;
                        if(profit > 0.0)
                           m_gross_profit += profit;
                        else
                           m_gross_loss += MathAbs(profit);
                        m_net_profit += profit;

                        ArrayResize(m_equity_curve, m_total_trades);
                        m_equity_curve[m_total_trades - 1] = balance;

                        double balance_before = balance - profit;
                        double pct_return = (balance_before != 0.0) ? profit / balance_before : 0.0;
                        ArrayResize(m_returns, m_total_trades);
                        m_returns[m_total_trades - 1] = pct_return;

                        if(balance > m_peak_equity)
                           m_peak_equity = balance;
                        double drawdown = m_peak_equity - balance;
                        if(drawdown > m_max_drawdown)
                           m_max_drawdown = drawdown;
                     }

   void              ProcessTesterHistory(void)
                     {
                        ulong deals = HistoryDealsTotal();
                        for(uint i = 0; i < deals; i++)
                          {
                             ulong ticket = HistoryDealGetTicket(i);
                             if(ticket == 0)
                                continue;
                             double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                             double balance = HistoryDealGetDouble(ticket, DEAL_BALANCE);
                             RegisterDeal(profit, balance);
                          }
                     }

   void              ProcessTesterHistory(const datetime from_date, const datetime to_date)
                     {
                        if(!HistorySelect(from_date, to_date))
                          {
                             PrintFormat("HistorySelect failed, error %d", GetLastError());
                             return;
                          }
                        ProcessTesterHistory();
                     }

   double            SharpeRatio(void) const
                     {
                        if(m_total_trades < 2)
                           return 0.0;
                        double mean = 0.0;
                        for(int i = 0; i < m_total_trades; i++)
                           mean += m_returns[i];
                        mean /= m_total_trades;

                        double variance = 0.0;
                        for(int i = 0; i < m_total_trades; i++)
                          {
                             double diff = m_returns[i] - mean;
                             variance += diff * diff;
                          }
                        variance /= (m_total_trades - 1);
                        double stdev = MathSqrt(MathMax(variance, 0.0));
                        if(stdev == 0.0)
                           return 0.0;
                        double risk_free_per_trade = m_risk_free_rate / 252.0;
                        return (mean - risk_free_per_trade) / stdev;
                     }

   double            MaxDrawdown(void) const
                     {
                        return m_max_drawdown;
                     }

   double            WinRate(void) const
                     {
                        if(m_total_trades == 0)
                           return 0.0;
                        return (double)m_win_trades / (double)m_total_trades;
                     }

   double            ProfitFactor(void) const
                     {
                        if(m_gross_loss == 0.0)
                           return 0.0;
                        return m_gross_profit / m_gross_loss;
                     }

   double            RecoveryFactor(void) const
                     {
                        if(m_max_drawdown == 0.0)
                           return 0.0;
                        return m_net_profit / m_max_drawdown;
                     }

   void              CalculateMetrics(SPerformanceMetrics &metrics) const
                     {
                        metrics.sharpe = SharpeRatio();
                        metrics.max_drawdown = MaxDrawdown();
                        metrics.win_rate = WinRate();
                        metrics.profit_factor = ProfitFactor();
                        metrics.recovery_factor = RecoveryFactor();
                     }

   string            ToJson(void) const
                     {
                        SPerformanceMetrics metrics;
                        CalculateMetrics(metrics);
                        string json = "{";
                        json += StringFormat("\"sharpe\":%.6f,", metrics.sharpe);
                        json += StringFormat("\"max_drawdown\":%.2f,", metrics.max_drawdown);
                        json += StringFormat("\"win_rate\":%.4f,", metrics.win_rate);
                        json += StringFormat("\"profit_factor\":%.4f,", metrics.profit_factor);
                        json += StringFormat("\"recovery_factor\":%.4f", metrics.recovery_factor);
                        json += "}";
                        return json;
                     }
  };
