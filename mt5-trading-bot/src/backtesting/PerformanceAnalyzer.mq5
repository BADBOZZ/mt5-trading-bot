#property strict

//+------------------------------------------------------------------+
//| PerformanceAnalyzer                                              |
//| Collects Strategy Tester statistics and exports MT5 reports.     |
//+------------------------------------------------------------------+
class PerformanceAnalyzer
  {
private:
   double            m_initial_balance;
   double            m_equity;
   double            m_peak_equity;
   double            m_max_drawdown_ratio;
   double            m_gross_profit;
   double            m_gross_loss;
   double            m_return_sum;
   double            m_return_squared_sum;
   ulong             m_trade_count;
   ulong             m_winning_trades;
   double            m_equity_points[];
   datetime          m_equity_times[];
   string            m_symbol_filter[];
   bool              m_filter_enabled;
   string            m_report_prefix;

   // Helper: trim whitespace
   string Trim(const string value) const
     {
      string copy=value;
      StringTrimLeft(copy);
      StringTrimRight(copy);
      return copy;
     }

   // Helper: check symbol filter
   bool SymbolAllowed(const string &symbol) const
     {
      if(!m_filter_enabled)
         return true;

      for(int i=0;i<ArraySize(m_symbol_filter);++i)
         if(StringCompare(m_symbol_filter[i],symbol,true)==0)
            return true;
      return false;
     }

   // Helper: append equity node for charting
   void AppendEquityPoint(const datetime time_value,const double equity_value)
     {
      int size=ArraySize(m_equity_points);
      ArrayResize(m_equity_points,size+1);
      ArrayResize(m_equity_times,size+1);
      m_equity_points[size]=equity_value;
      m_equity_times[size]=time_value;
     }

public:
   void Reset(const double starting_balance=0.0,const string prefix="StrategyTester")
     {
      m_initial_balance=(starting_balance>0.0 ? starting_balance : AccountInfoDouble(ACCOUNT_BALANCE));
      m_equity=m_initial_balance;
      m_peak_equity=m_initial_balance;
      m_max_drawdown_ratio=0.0;
      m_gross_profit=0.0;
      m_gross_loss=0.0;
      m_return_sum=0.0;
      m_return_squared_sum=0.0;
      m_trade_count=0;
      m_winning_trades=0;
      ArrayResize(m_equity_points,0);
      ArrayResize(m_equity_times,0);
      ArrayResize(m_symbol_filter,0);
      m_filter_enabled=false;
      m_report_prefix=prefix;
      AppendEquityPoint(TimeCurrent(),m_equity);
     }

   void SetReportPrefix(const string prefix)
     {
      m_report_prefix=prefix;
     }

   void UseSymbols(const string &symbols_list)
     {
      string cleaned=Trim(symbols_list);
      if(cleaned=="")
        {
         m_filter_enabled=false;
         ArrayResize(m_symbol_filter,0);
         return;
        }

      string tokens[];
      int total=StringSplit(cleaned,',',tokens);
      ArrayResize(m_symbol_filter,total);
      for(int i=0;i<total;++i)
         m_symbol_filter[i]=Trim(tokens[i]);
      m_filter_enabled=(total>0);
     }

   void UseSymbols(const string &symbols_array[])
     {
      int total=ArraySize(symbols_array);
      ArrayResize(m_symbol_filter,total);
      for(int i=0;i<total;++i)
         m_symbol_filter[i]=symbols_array[i];
      m_filter_enabled=(total>0);
     }

   ulong TradeCount() const
     {
      return m_trade_count;
     }

   double NetProfit() const
     {
      return m_gross_profit + m_gross_loss;
     }

   double MaxDrawdownPct() const
     {
      return m_max_drawdown_ratio*100.0;
     }

   double ProfitFactor() const
     {
      double losses=MathAbs(m_gross_loss);
      return (losses==0.0 ? 0.0 : m_gross_profit / losses);
     }

   double WinRate() const
     {
      if(m_trade_count==0)
         return 0.0;
      return (double)m_winning_trades / (double)m_trade_count * 100.0;
     }

   double SharpeRatio() const
     {
      if(m_trade_count<2)
         return 0.0;

      double mean=m_return_sum / (double)m_trade_count;
      double variance=(m_return_squared_sum / (double)m_trade_count) - mean*mean;
      if(variance<=0.0)
         return 0.0;

      double std_dev=MathSqrt(variance);
      // Annualize assuming 252 trading days
      return std_dev==0.0 ? 0.0 : (mean/std_dev)*MathSqrt(252.0);
     }

   double RecoveryFactor() const
     {
      double dd_money=m_max_drawdown_ratio*m_initial_balance;
      if(dd_money<=0.0)
         return 0.0;
      return NetProfit()/dd_money;
     }

   void RegisterDeal(const ulong ticket)
     {
      if(!HistoryDealSelect(ticket))
        {
         PrintFormat("PerformanceAnalyzer: failed to select deal %I64u",ticket);
         return;
        }

      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_INOUT)
         return;

      string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
      if(!SymbolAllowed(symbol))
         return;

      double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      double swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
      double commission=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      double trade_result=profit + swap + commission;

      m_equity+=trade_result;
      if(m_equity>m_peak_equity)
         m_peak_equity=m_equity;

      double drawdown=(m_peak_equity - m_equity);
      if(m_peak_equity>0.0)
        {
         double dd_ratio=drawdown / m_peak_equity;
         if(dd_ratio>m_max_drawdown_ratio)
            m_max_drawdown_ratio=dd_ratio;
        }

      double pct_return=(m_initial_balance>0.0 ? trade_result/m_initial_balance : 0.0);
      m_return_sum+=pct_return;
      m_return_squared_sum+=pct_return*pct_return;

      m_trade_count++;
      if(trade_result>=0.0)
        {
         m_gross_profit+=trade_result;
         m_winning_trades++;
        }
      else
        {
         m_gross_loss+=trade_result;
        }

      datetime deal_time=(datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
      AppendEquityPoint(deal_time,m_equity);
     }

   void ProcessHistory(const datetime from_date=0,const datetime to_date=0)
     {
      datetime from=from_date;
      datetime to=to_date;
      if(from==0)
         from=(datetime)0;
      if(to==0)
         to=TimeCurrent();

      if(!HistorySelect(from,to))
        {
         PrintFormat("PerformanceAnalyzer: HistorySelect failed (%s - %s)",TimeToString(from),TimeToString(to));
         return;
        }

      int total=HistoryDealsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=HistoryDealGetTicket(i);
         RegisterDeal(ticket);
        }
     }

   void ExportTradeHistory(const string file_name="trade_history.csv") const
     {
      string path=m_report_prefix + "_" + file_name;
      int handle=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
      if(handle==INVALID_HANDLE)
        {
         PrintFormat("PerformanceAnalyzer: unable to open %s for trade export",path);
         return;
        }

      FileWrite(handle,"ticket","symbol","type","volume","price","profit","swap","commission","time");

      int total=HistoryDealsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(!HistoryDealSelect(ticket))
            continue;

         string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
         if(!SymbolAllowed(symbol))
            continue;

         ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_INOUT)
            continue;

         FileWrite(handle,
                   (long)ticket,
                   symbol,
                   EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE)),
                   HistoryDealGetDouble(ticket,DEAL_VOLUME),
                   HistoryDealGetDouble(ticket,DEAL_PRICE),
                   HistoryDealGetDouble(ticket,DEAL_PROFIT),
                   HistoryDealGetDouble(ticket,DEAL_SWAP),
                   HistoryDealGetDouble(ticket,DEAL_COMMISSION),
                   TimeToString((datetime)HistoryDealGetInteger(ticket,DEAL_TIME)));
        }

      FileClose(handle);
     }

   void ExportEquityCurve(const string file_name="equity_curve.csv") const
     {
      string path=m_report_prefix + "_" + file_name;
      int handle=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
      if(handle==INVALID_HANDLE)
        {
         PrintFormat("PerformanceAnalyzer: unable to open %s for equity export",path);
         return;
        }

      FileWrite(handle,"time","equity");
      int total=ArraySize(m_equity_points);
      for(int i=0;i<total;i++)
         FileWrite(handle,TimeToString(m_equity_times[i]),m_equity_points[i]);
      FileClose(handle);
     }

   void ExportSummary(const string file_name="summary.csv") const
     {
      string path=m_report_prefix + "_" + file_name;
      int handle=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
      if(handle==INVALID_HANDLE)
        {
         PrintFormat("PerformanceAnalyzer: unable to open %s for summary export",path);
         return;
        }

      FileWrite(handle,"metric","value");
      FileWrite(handle,"net_profit",NetProfit());
      FileWrite(handle,"max_drawdown_pct",MaxDrawdownPct());
      FileWrite(handle,"sharpe_ratio",SharpeRatio());
      FileWrite(handle,"win_rate_pct",WinRate());
      FileWrite(handle,"profit_factor",ProfitFactor());
      FileWrite(handle,"recovery_factor",RecoveryFactor());
      FileClose(handle);
     }

   void AppendStrategyComparison(const string strategy_name,const string file_name="strategy_comparison.csv") const
     {
      string path=m_report_prefix + "_" + file_name;
      int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
      if(handle==INVALID_HANDLE)
        {
         handle=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
         if(handle==INVALID_HANDLE)
           {
            PrintFormat("PerformanceAnalyzer: unable to open %s for comparison",path);
            return;
           }
         FileWrite(handle,"strategy","net_profit","max_drawdown_pct","sharpe","win_rate","profit_factor","recovery_factor");
        }
      else
        {
         FileSeek(handle,0,SEEK_END);
        }

      FileWrite(handle,
                strategy_name,
                NetProfit(),
                MaxDrawdownPct(),
                SharpeRatio(),
                WinRate(),
                ProfitFactor(),
                RecoveryFactor());
      FileClose(handle);
     }

   void LogToJournal() const
     {
      PrintFormat("[PerformanceAnalyzer] trades=%I64u net=%.2f maxDD=%.2f%% sharpe=%.3f win=%.2f%% pf=%.2f recovery=%.2f",
                  m_trade_count,
                  NetProfit(),
                  MaxDrawdownPct(),
                  SharpeRatio(),
                  WinRate(),
                  ProfitFactor(),
                  RecoveryFactor());
     }
  };

// Utility function: process Strategy Tester results directly
void CollectStrategyTesterStats(PerformanceAnalyzer &analyzer,
                                const string symbols="",
                                const string report_prefix="StrategyTester")
  {
   analyzer.Reset(0.0,report_prefix);
   analyzer.UseSymbols(symbols);
   analyzer.ProcessHistory();
   analyzer.ExportTradeHistory();
   analyzer.ExportEquityCurve();
   analyzer.ExportSummary();
   analyzer.AppendStrategyComparison(report_prefix);
   analyzer.LogToJournal();
  }
