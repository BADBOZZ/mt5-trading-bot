#property strict
#pragma once

//+------------------------------------------------------------------+
//| Optimization parameter helpers for MT5 Strategy Tester           |
//+------------------------------------------------------------------+
enum ENUM_OptimizationCriterion
  {
   OPTIMIZE_BY_SHARPE = 0,
   OPTIMIZE_BY_RECOVERY,
   OPTIMIZE_BY_PROFIT_FACTOR,
   OPTIMIZE_BY_EXPECTANCY
  };

struct OptimizationParamRange
  {
   string   name;
   double   start;
   double   step;
   double   stop;
   bool     is_integer;
  };

struct OptimizationSnapshot
  {
   double   sharpe;
   double   recovery;
   double   win_rate;
   double   profit_factor;
   double   net_profit;
   double   max_drawdown_pct;
   double   expectancy;
   ulong    trades;
  };

struct WalkForwardSlice
  {
   datetime train_from;
   datetime train_to;
   datetime test_from;
   datetime test_to;
  };

input group           "Multi-currency"
input string          InpSymbols          = "EURUSD,GBPUSD,USDJPY,XAUUSD";
input ENUM_TIMEFRAMES InpExecutionTF      = PERIOD_H1;
input ENUM_TIMEFRAMES InpSignalTF         = PERIOD_M15;
input bool            InpSyncTimeframes   = true;

input group           "Risk profile"
input double          InpRiskPerTradePct  = 0.75;
input int             InpMaxParallelTrades= 3;
input double          InpMaxPortfolioDD   = 12.5;

input group           "Strategy Tester"
input bool            InpEnableWalkForward= true;
input datetime        InpWFStart          = D'2023.01.01';
input datetime        InpWFEnd            = 0;
input int             InpWFTrainMonths    = 3;
input int             InpWFTestMonths     = 1;
input ENUM_OptimizationCriterion InpOptimizationGoal = OPTIMIZE_BY_SHARPE;

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void AddRange(OptimizationParamRange &ranges[],
              const string name,
              const double start,
              const double step,
              const double stop,
              const bool is_integer=false)
  {
   OptimizationParamRange range;
   range.name=name;
   range.start=start;
   range.step=step;
   range.stop=stop;
   range.is_integer=is_integer;

   int size=ArraySize(ranges);
   ArrayResize(ranges,size+1);
   ranges[size]=range;
  }

int BuildDefaultRanges(OptimizationParamRange &ranges[])
  {
   ArrayResize(ranges,0);
   AddRange(ranges,"RiskPerTradePct",0.25,0.25,2.0);
   AddRange(ranges,"MaxParallelTrades",1,1,6,true);
   AddRange(ranges,"StopATRMultiplier",1.0,0.25,4.0);
   AddRange(ranges,"TrailATRMultiplier",0.5,0.25,3.0);
   AddRange(ranges,"SignalThreshold",0.15,0.05,0.65);
   AddRange(ranges,"LookbackBars",30,10,250,true);
   AddRange(ranges,"VolumeFilter",50000,50000,500000,true);
   AddRange(ranges,"BreakEvenPips",5,1,25,true);
   AddRange(ranges,"PartialClosePct",20,5,60,true);
   return ArraySize(ranges);
  }

void SerializeRangesToCsv(const OptimizationParamRange &ranges[],
                          const string file_name="parameter_ranges.csv")
  {
   int handle=FileOpen(file_name,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_WRITE);
   if(handle==INVALID_HANDLE)
     {
      Print("OptimizationParams: unable to write ",file_name);
      return;
     }

   FileWrite(handle,"name","start","step","stop","is_integer");
   for(int i=0;i<ArraySize(ranges);++i)
      FileWrite(handle,
                ranges[i].name,
                ranges[i].start,
                ranges[i].step,
                ranges[i].stop,
                (int)ranges[i].is_integer);
   FileClose(handle);
  }

double EvaluateCriterion(const OptimizationSnapshot &snapshot,
                         const ENUM_OptimizationCriterion criterion)
  {
   switch(criterion)
     {
      case OPTIMIZE_BY_SHARPE:
         return snapshot.sharpe;
      case OPTIMIZE_BY_RECOVERY:
         return snapshot.recovery;
      case OPTIMIZE_BY_PROFIT_FACTOR:
         return snapshot.profit_factor;
      case OPTIMIZE_BY_EXPECTANCY:
         return snapshot.expectancy;
     }
   return snapshot.sharpe;
  }

void SaveOptimizationReport(const OptimizationSnapshot &snapshot,
                            const ENUM_OptimizationCriterion criterion,
                            const string strategy_name="StrategyTester",
                            const string file_name="optimization_report.csv")
  {
   int handle=FileOpen(file_name,FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      handle=FileOpen(file_name,FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
      if(handle==INVALID_HANDLE)
        {
         Print("OptimizationParams: unable to persist optimization report");
         return;
        }
      FileWrite(handle,"strategy","criterion","score","sharpe","recovery","profit_factor","win_rate","max_drawdown_pct","net_profit","trades","expectancy");
     }
   else
     {
      FileSeek(handle,0,SEEK_END);
     }

   double score=EvaluateCriterion(snapshot,criterion);
   FileWrite(handle,
             strategy_name,
             EnumToString(criterion),
             score,
             snapshot.sharpe,
             snapshot.recovery,
             snapshot.profit_factor,
             snapshot.win_rate,
             snapshot.max_drawdown_pct,
             snapshot.net_profit,
             (long)snapshot.trades,
             snapshot.expectancy);
   FileClose(handle);
  }

void ParseSymbols(const string list,string &symbols[])
  {
   string copy=list;
   StringTrimLeft(copy);
   StringTrimRight(copy);
   if(copy=="")
     {
      ArrayResize(symbols,0);
      return;
     }

   string tokens[];
   int count=StringSplit(copy,',',tokens);
   ArrayResize(symbols,count);
   for(int i=0;i<count;++i)
     {
      string token=tokens[i];
      StringTrimLeft(token);
      StringTrimRight(token);
      symbols[i]=token;
     }
  }

int DaysInMonth(const int month,const int year)
  {
   static const int days[12]={31,28,31,30,31,30,31,31,30,31,30,31};
   int result=days[MathMax(0,MathMin(month-1,11))];
   bool leap=((year%4==0 && year%100!=0) || (year%400==0));
   if(month==2 && leap)
      result=29;
   return result;
  }

datetime AddMonths(datetime value,const int months)
  {
   MqlDateTime dt;
   TimeToStruct(value,dt);
   int new_month=dt.mon + months;
   dt.year += (new_month-1)/12;
   dt.mon = (new_month-1)%12 + 1;
   dt.day = MathMin(dt.day,DaysInMonth(dt.mon,dt.year));
   return StructToTime(dt);
  }

int BuildWalkForwardSlices(const datetime start_date,
                           const datetime end_date,
                           const int train_months,
                           const int test_months,
                           WalkForwardSlice &slices[])
  {
   ArrayResize(slices,0);
   if(start_date==0 || end_date==0 || start_date>=end_date)
      return 0;

   datetime cursor=start_date;
   while(cursor<end_date)
     {
      datetime train_end=AddMonths(cursor,train_months);
      datetime test_end=AddMonths(train_end,test_months);
      if(train_end>end_date)
         break;

      WalkForwardSlice slice;
      slice.train_from=cursor;
      slice.train_to=train_end - 1;
      slice.test_from=train_end;
      slice.test_to=MathMin(test_end,end_date);

      int size=ArraySize(slices);
      ArrayResize(slices,size+1);
      slices[size]=slice;

      cursor=test_end;
     }
   return ArraySize(slices);
  }

void ExportWalkForwardPlan(const WalkForwardSlice &slices[],
                           const string file_name="walkforward_windows.csv")
  {
   int handle=FileOpen(file_name,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_WRITE);
   if(handle==INVALID_HANDLE)
     {
      Print("OptimizationParams: unable to export walk-forward plan");
      return;
     }

   FileWrite(handle,"train_from","train_to","test_from","test_to");
   for(int i=0;i<ArraySize(slices);++i)
      FileWrite(handle,
                TimeToString(slices[i].train_from),
                TimeToString(slices[i].train_to),
                TimeToString(slices[i].test_from),
                TimeToString(slices[i].test_to));
   FileClose(handle);
  }
