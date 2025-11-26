#property copyright "MT5 Trading Bot"
#property link      "https://example.com/mt5-trading-bot"
#property version   "1.00"
#property strict

/**
 *  PerformanceAnalyzer.mq5
 *
 *  Collects Strategy Tester statistics such as Sharpe ratio, max drawdown,
 *  profit factor, win rate, recovery factor, and provides helpers for
 *  exporting trade history as CSV so it can be graphed inside Python tooling.
 *
 *  The analyzer is intentionally standalone so it can be included by
 *  any Expert Advisor or test harness.
 */

#include <Trade\DealInfo.mqh>

#ifndef __PERFORMANCE_ANALYZER__
#define __PERFORMANCE_ANALYZER__

struct STradeSnapshot
  {
   datetime  time;
   double    profit;
   double    equity;
   double    drawdown;
   ulong     ticket;
   string    symbol;
   long      type;
  };

class CPerformanceAnalyzer
  {
private:
   double    m_risk_free;
   double    m_equity;
   double    m_peak_equity;
   double    m_max_drawdown;
   double    m_total_profit;
   double    m_total_loss;
   double    m_profit_sum;
   double    m_profit_sum_sq;
   int       m_win_count;
   int       m_loss_count;
   int       m_total_trades;
   double    m_net_profit;
   datetime  m_from;
   datetime  m_to;
   string    m_symbol_filter;

   STradeSnapshot m_samples[];

public:
            CPerformanceAnalyzer(void)
            {
               Reset();
            }

   void     Reset(void)
            {
               m_risk_free    = 0.0;
               m_equity       = 0.0;
               m_peak_equity  = 0.0;
               m_max_drawdown = 0.0;
               m_total_profit = 0.0;
               m_total_loss   = 0.0;
               m_profit_sum   = 0.0;
               m_profit_sum_sq= 0.0;
               m_win_count    = 0;
               m_loss_count   = 0;
               m_total_trades = 0;
               m_net_profit   = 0.0;
               m_from         = 0;
               m_to           = 0;
               m_symbol_filter= "";
               ArrayResize(m_samples,0);
            }

   void     SetRiskFreeRate(const double rate)
            {
               m_risk_free = rate;
            }

   /**
    *  Loads trade history between two dates. An empty symbol filter means
    *  the analyzer will evaluate multi-currency performance.
    */
   bool     Analyze(const datetime from,
                    const datetime to,
                    const string symbol_filter = "")
            {
               string filters[];
               int filter_count = 0;
               if(symbol_filter != "")
               {
                  ArrayResize(filters, 1);
                  filters[0] = symbol_filter;
                  filter_count = 1;
               }

               return AnalyzeMulti(from, to, filters, filter_count);
            }

   /**
    *  Convenience helper for multi-currency analysis.
    */
   bool     AnalyzeMulti(const datetime from,
                         const datetime to,
                         const string &symbols[],
                         const int symbol_count)
            {
               Reset();
               m_from = from;
               m_to   = to;

               if(!HistorySelect(from, to))
               {
                  PrintFormat("PerformanceAnalyzer: failed to select history (%d - %d)", from, to);
                  return false;
               }

               const int total_deals = HistoryDealsTotal();
               for(int i = 0; i < total_deals; i++)
               {
                  const ulong ticket = HistoryDealGetTicket(i);
                  if(ticket == 0)
                     continue;

                  const long entry = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY);
                  if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
                     continue;

                  const string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
                  if(symbol_count > 0 && !IsSymbolAllowed(symbols, symbol_count, symbol))
                     continue;

                  const double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                                        HistoryDealGetDouble(ticket, DEAL_SWAP) +
                                        HistoryDealGetDouble(ticket, DEAL_COMMISSION);

                  const datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                  const long type     = (long)HistoryDealGetInteger(ticket, DEAL_TYPE);

                  PushSample(ticket, symbol, type, time, profit);
               }
               return (m_total_trades > 0);
            }

   double   SharpeRatio(void) const
            {
               if(m_total_trades < 2)
                  return 0.0;

               const double avg = m_profit_sum / (double)m_total_trades;
               const double variance = (m_profit_sum_sq - (m_profit_sum * m_profit_sum) / (double)m_total_trades) /
                                       MathMax(1, m_total_trades - 1);
               const double stddev = MathSqrt(MathMax(0.0, variance));
               if(stddev == 0.0)
                  return 0.0;

               const double excess_return = avg - m_risk_free;
               return excess_return / stddev;
            }

   double   MaxDrawdown(void) const
            {
               return m_max_drawdown;
            }

   double   WinRate(void) const
            {
               if(m_total_trades == 0)
                  return 0.0;
               return (double)m_win_count / (double)m_total_trades;
            }

   double   ProfitFactor(void) const
            {
               if(m_total_loss == 0.0)
                  return 0.0;
               return m_total_profit / MathAbs(m_total_loss);
            }

   double   RecoveryFactor(void) const
            {
               if(m_max_drawdown == 0.0)
                  return 0.0;
               return m_net_profit / m_max_drawdown;
            }

   /**
    *  Exports trade history to CSV for charting and reporting.
    */
   bool     ExportHistory(const string file_name) const
            {
               const int total = ArraySize(m_samples);
               if(total == 0)
                  return false;

               const int file_handle = FileOpen(file_name, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
               if(file_handle == INVALID_HANDLE)
               {
                  PrintFormat("PerformanceAnalyzer: failed to open %s", file_name);
                  return false;
               }

               FileWrite(file_handle,
                         "time", "ticket", "symbol", "type",
                         "profit", "equity", "drawdown");

               for(int i = 0; i < total; i++)
               {
                  const STradeSnapshot sample = m_samples[i];
                  FileWrite(file_handle,
                            TimeToString(sample.time, TIME_DATE|TIME_SECONDS),
                            (long)sample.ticket,
                            sample.symbol,
                            EnumToString((ENUM_DEAL_TYPE)sample.type),
                            DoubleToString(sample.profit, 2),
                            DoubleToString(sample.equity, 2),
                            DoubleToString(sample.drawdown, 2));
               }

               FileClose(file_handle);
               PrintFormat("PerformanceAnalyzer: exported %d rows to %s", total, file_name);
               return true;
            }

   /**
    *  Provides equity curve arrays so Strategy Tester can draw comparisons between parameter sets.
    */
   bool     BuildEquitySeries(double &equity[], datetime &time[]) const
            {
               const int total = ArraySize(m_samples);
               if(total == 0)
                  return false;

               ArrayResize(equity, total);
               ArrayResize(time, total);
               for(int i = 0; i < total; i++)
               {
                  equity[i] = m_samples[i].equity;
                  time[i]   = m_samples[i].time;
               }
               return true;
            }

   /**
    *  Returns a unified score that can be fed into OnTester for custom optimization.
    */
   double   CompositeScore(void) const
            {
               // Balanced weighting between return, drawdown, stability, and hit rate.
               const double sharpe = SharpeRatio();
               const double dd     = m_max_drawdown;
               const double wr     = WinRate();
               const double pf     = ProfitFactor();

               return sharpe * 0.4 +
                      wr     * 0.2 +
                      pf     * 0.2 +
                      RecoveryFactor() * 0.2 -
                      (dd > 0.0 ? (dd / 100000.0) : 0.0);
            }

private:
   void     PushSample(const ulong ticket,
                       const string symbol,
                       const long type,
                       const datetime time,
                       const double profit)
            {
               m_total_trades++;
               m_profit_sum    += profit;
               m_profit_sum_sq += profit * profit;
               m_net_profit    += profit;
               m_equity        += profit;
               if(m_equity > m_peak_equity)
                  m_peak_equity = m_equity;

               const double drawdown = m_peak_equity - m_equity;
               if(drawdown > m_max_drawdown)
                  m_max_drawdown = drawdown;

               if(profit >= 0.0)
               {
                  m_total_profit += profit;
                  m_win_count++;
               }
               else
               {
                  m_total_loss  += profit;
                  m_loss_count++;
               }

               const int index = ArraySize(m_samples);
               ArrayResize(m_samples, index + 1);
               m_samples[index].time     = time;
               m_samples[index].ticket   = ticket;
               m_samples[index].symbol   = symbol;
               m_samples[index].type     = type;
               m_samples[index].profit   = profit;
               m_samples[index].equity   = m_equity;
               m_samples[index].drawdown = drawdown;
            }
  private:
   bool     IsSymbolAllowed(const string &symbols[],
                            const int symbol_count,
                            const string symbol) const
            {
               if(symbol_count <= 0)
                  return true;
               for(int i = 0; i < symbol_count; i++)
               {
                  if(symbols[i] == symbol)
                     return true;
               }
               return false;
            }
  };

#endif // __PERFORMANCE_ANALYZER__
