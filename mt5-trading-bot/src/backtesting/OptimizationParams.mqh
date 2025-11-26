#ifndef __OPTIMIZATION_PARAMS_MQH__
#define __OPTIMIZATION_PARAMS_MQH__
#property strict

// Helper definitions that keep Strategy Tester optimization and walk-forward
// experiments consistent with the Expert Advisor settings.

enum ENUM_OPTIMIZATION_CRITERIA
  {
   OPT_CRITERIA_RECOVERY = 0,
   OPT_CRITERIA_SHARPE,
   OPT_CRITERIA_PROFIT_FACTOR,
   OPT_CRITERIA_WIN_RATE
  };

enum ENUM_WALKFORWARD_MODE
  {
   WALKFORWARD_DISABLED = 0,
   WALKFORWARD_ROLLING,
   WALKFORWARD_EXPANDING
  };

struct OptimizationParameter
  {
   string name;
   double default_value;
   double min_value;
   double max_value;
   double step;
   bool   integer_only;
  };

struct SymbolTarget
  {
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   double weight;
  };

struct WalkForwardWindow
  {
   datetime train_from;
   datetime train_to;
   datetime test_from;
   datetime test_to;
  };

input string            InpOptimizationSymbols     = "EURUSD,GBPUSD,USDJPY,USDCHF";
input ENUM_TIMEFRAMES   InpOptimizationTimeframe   = PERIOD_H1;
input ENUM_WALKFORWARD_MODE InpWalkForwardMode     = WALKFORWARD_ROLLING;
input int               InpWalkForwardTrainMonths  = 6;
input int               InpWalkForwardTestMonths   = 1;
input datetime          InpWalkForwardStart        = D'2020.01.01';
input datetime          InpWalkForwardEnd          = D'2024.12.31';

sinput double           InpRiskPerTrade            = 0.75;  // range 0.25 .. 2.0 step 0.25
sinput double           InpStopATRMultiplier       = 2.0;   // range 1.0 .. 4.0 step 0.25
sinput double           InpTakeATRMultiplier       = 3.0;   // range 1.0 .. 6.0 step 0.25
sinput int              InpLookbackPeriod          = 50;    // range 20 .. 150 step 10
sinput double           InpTrailPercent            = 0.5;   // range 0.1 .. 1.0 step 0.1
sinput double           InpMaxSpread               = 2.0;   // range 0.5 .. 4.0 step 0.25

void AppendOptimizationParameter(OptimizationParameter &params[], const OptimizationParameter &param)
  {
   const int index = ArraySize(params);
   ArrayResize(params,index+1);
   params[index] = param;
  }

int BuildDefaultParameters(OptimizationParameter &params[])
  {
   ArrayResize(params,0);

   OptimizationParameter param;

   param.name = "risk_per_trade";
   param.default_value = InpRiskPerTrade;
   param.min_value = 0.25;
   param.max_value = 2.0;
   param.step = 0.25;
   param.integer_only = false;
   AppendOptimizationParameter(params,param);

   param.name = "stop_atr_multiplier";
   param.default_value = InpStopATRMultiplier;
   param.min_value = 1.0;
   param.max_value = 4.0;
   param.step = 0.25;
   param.integer_only = false;
   AppendOptimizationParameter(params,param);

   param.name = "take_atr_multiplier";
   param.default_value = InpTakeATRMultiplier;
   param.min_value = 1.0;
   param.max_value = 6.0;
   param.step = 0.25;
   param.integer_only = false;
   AppendOptimizationParameter(params,param);

   param.name = "lookback_period";
   param.default_value = InpLookbackPeriod;
   param.min_value = 20;
   param.max_value = 150;
   param.step = 10;
   param.integer_only = true;
   AppendOptimizationParameter(params,param);

   param.name = "trail_percent";
   param.default_value = InpTrailPercent;
   param.min_value = 0.1;
   param.max_value = 1.0;
   param.step = 0.1;
   param.integer_only = false;
   AppendOptimizationParameter(params,param);

   param.name = "max_spread";
   param.default_value = InpMaxSpread;
   param.min_value = 0.5;
   param.max_value = 4.0;
   param.step = 0.25;
   param.integer_only = false;
   AppendOptimizationParameter(params,param);

   return ArraySize(params);
  }

string TrimCopy(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

int ParseOptimizationSymbols(SymbolTarget &symbols[])
  {
   ArrayResize(symbols,0);
   string parts[];
   const int total = StringSplit(InpOptimizationSymbols,',',parts);
   if(total<=0)
      return 0;

   for(int i=0; i<total; ++i)
     {
      string token = TrimCopy(parts[i]);
      if(token=="")
         continue;

      SymbolTarget item;
      item.symbol = token;
      item.timeframe = InpOptimizationTimeframe;
      item.weight = 1.0;
      const int index = ArraySize(symbols);
      ArrayResize(symbols,index+1);
      symbols[index] = item;
     }

   return ArraySize(symbols);
  }

void SelectOptimizationSymbols()
  {
   SymbolTarget symbols[];
   const int total = ParseOptimizationSymbols(symbols);
   for(int i=0; i<total; ++i)
      SymbolSelect(symbols[i].symbol,true);
  }

void ShiftMonth(MqlDateTime &dt, const int months)
  {
   int total_months = (int)dt.mon + months;
   while(total_months>12)
     {
      total_months -= 12;
      dt.year++;
     }
   while(total_months<=0)
     {
      total_months += 12;
      dt.year--;
     }
   dt.mon = (uchar)total_months;
   const int days_in_month = TimeDaysPerMonth(dt.year,dt.mon);
   if(dt.day>days_in_month)
      dt.day = (uchar)days_in_month;
  }

datetime AddMonths(const datetime value,const int months)
  {
   MqlDateTime dt;
   TimeToStruct(value,dt);
   ShiftMonth(dt,months);
   return StructToTime(dt);
  }

int BuildWalkForwardWindows(WalkForwardWindow &windows[])
  {
   ArrayResize(windows,0);
   if(InpWalkForwardMode==WALKFORWARD_DISABLED)
      return 0;

   datetime anchor = InpWalkForwardStart;
   int index = 0;

   while(anchor<InpWalkForwardEnd)
     {
      const datetime train_end = AddMonths(anchor,InpWalkForwardTrainMonths);
      datetime test_end = AddMonths(train_end,InpWalkForwardTestMonths);
      if(train_end>=InpWalkForwardEnd)
         break;
      if(test_end>InpWalkForwardEnd)
         test_end = InpWalkForwardEnd;

      ArrayResize(windows,index+1);
      windows[index].train_from = anchor;
      windows[index].train_to   = train_end;
      windows[index].test_from  = train_end;
      windows[index].test_to    = test_end;
      ++index;

      if(InpWalkForwardMode==WALKFORWARD_ROLLING)
         anchor = AddMonths(anchor,InpWalkForwardTestMonths);
      else
         anchor = train_end;
     }

   return ArraySize(windows);
  }

double EvaluateOptimizationCriterion(const ENUM_OPTIMIZATION_CRITERIA criterion,
                                      const double net_profit,
                                      const double max_drawdown,
                                      const double sharpe,
                                      const double profit_factor,
                                      const double win_rate)
  {
   switch(criterion)
     {
      case OPT_CRITERIA_SHARPE:
         return sharpe;
      case OPT_CRITERIA_PROFIT_FACTOR:
         return profit_factor;
      case OPT_CRITERIA_WIN_RATE:
         return win_rate;
      case OPT_CRITERIA_RECOVERY:
      default:
         if(max_drawdown==0.0)
            return 0.0;
         return net_profit/max_drawdown;
     }
  }

bool ExportOptimizationManifest(const string file_name)
  {
   OptimizationParameter params[];
   const int total = BuildDefaultParameters(params);
   if(total==0)
      return false;

   int flags = FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_COMMON;
   const int handle = FileOpen(file_name,flags);
   if(handle==INVALID_HANDLE)
      return false;

   FileWrite(handle,"name","default","min","max","step","integer");
   for(int i=0; i<total; ++i)
     {
      const OptimizationParameter &param = params[i];
      FileWrite(handle,
                param.name,
                DoubleToString(param.default_value,4),
                DoubleToString(param.min_value,4),
                DoubleToString(param.max_value,4),
                DoubleToString(param.step,4),
                param.integer_only ? "1" : "0");
     }

   FileClose(handle);
   return true;
  }

bool ExportWalkForwardPlan(const string file_name)
  {
   WalkForwardWindow windows[];
   const int total = BuildWalkForwardWindows(windows);
   if(total==0)
      return false;

   int flags = FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_COMMON;
   const int handle = FileOpen(file_name,flags);
   if(handle==INVALID_HANDLE)
      return false;

   FileWrite(handle,"train_from","train_to","test_from","test_to");
   for(int i=0; i<total; ++i)
     {
      const WalkForwardWindow &window = windows[i];
      FileWrite(handle,
                TimeToString(window.train_from,TIME_DATE),
                TimeToString(window.train_to,TIME_DATE),
                TimeToString(window.test_from,TIME_DATE),
                TimeToString(window.test_to,TIME_DATE));
     }

   FileClose(handle);
   return true;
  }

#endif // __OPTIMIZATION_PARAMS_MQH__
