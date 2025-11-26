#pragma once

#include <Trade\SymbolInfo.mqh>

enum ENUM_STRATEGY_SIGNAL
{
   STRATEGY_SIGNAL_HOLD = 0,
   STRATEGY_SIGNAL_BUY  = 1,
   STRATEGY_SIGNAL_SELL = -1
};

struct StrategyUniverse
{
   string symbols[];
   ENUM_TIMEFRAMES timeframes[];
};

struct TrendStrategyConfig
{
   string name;
   StrategyUniverse universe;
   int    fastEmaPeriod;
   int    slowEmaPeriod;
   int    signalSmoothing;
   int    macdSignalPeriod;
   double minSlope;
   double minConfidence;
   double stopAtrMultiplier;
   double takeProfitAtrMultiplier;
};

struct MeanReversionStrategyConfig
{
   string name;
   StrategyUniverse universe;
   int    rsiPeriod;
   int    bollingerPeriod;
   double bollingerDeviation;
   int    stochasticKPeriod;
   int    stochasticDPeriod;
   int    stochasticSlowing;
   double oversoldLevel;
   double overboughtLevel;
   double exitBandCompression;
   double minConfidence;
};

struct BreakoutStrategyConfig
{
   string name;
   StrategyUniverse universe;
   int    supportLookback;
   int    resistanceLookback;
   int    volumeLookback;
   double volumeSpikeMultiplier;
   double breakoutBufferPoints;
   double retestTolerancePoints;
   double minConfidence;
};

struct StrategyWeightConfig
{
   double trendWeight;
   double meanReversionWeight;
   double breakoutWeight;
   double conflictThreshold;
};

// --- Internal helper prototypes --------------------------------------------
int  StrategyConfig_ParseSymbols(const string csv, string &output[]);
int  StrategyConfig_ParseTimeframes(const string csv, ENUM_TIMEFRAMES &output[]);
void StrategyConfig_CopyStrings(string &target[], const string source[]);
void StrategyConfig_CopyTimeframes(ENUM_TIMEFRAMES &target[], const ENUM_TIMEFRAMES source[]);
string StrategyConfig_Trim(const string value);
ENUM_TIMEFRAMES StrategyConfig_ParseTimeframeToken(const string token);

// --- Public API -------------------------------------------------------------
void LoadTrendStrategyConfig(TrendStrategyConfig &config,
                             const string symbolCsv = "",
                             const string timeframeCsv = "");

void LoadMeanReversionConfig(MeanReversionStrategyConfig &config,
                             const string symbolCsv = "",
                             const string timeframeCsv = "");

void LoadBreakoutStrategyConfig(BreakoutStrategyConfig &config,
                                const string symbolCsv = "",
                                const string timeframeCsv = "");

void LoadStrategyWeights(StrategyWeightConfig &weights,
                         const double trendWeight = 0.4,
                         const double meanReversionWeight = 0.35,
                         const double breakoutWeight = 0.25,
                         const double conflictThreshold = 0.15);

// --- Defaults ---------------------------------------------------------------
string TREND_DEFAULT_SYMBOLS[]     = {"EURUSD","GBPUSD","USDJPY"};
ENUM_TIMEFRAMES TREND_DEFAULT_TFS[] = {PERIOD_M15, PERIOD_H1, PERIOD_H4};

string MEANREV_DEFAULT_SYMBOLS[]      = {"EURUSD","AUDUSD","USDCHF"};
ENUM_TIMEFRAMES MEANREV_DEFAULT_TFS[] = {PERIOD_M5, PERIOD_M15, PERIOD_H1};

string BREAKOUT_DEFAULT_SYMBOLS[]      = {"XAUUSD","GBPUSD","USDJPY"};
ENUM_TIMEFRAMES BREAKOUT_DEFAULT_TFS[] = {PERIOD_M30, PERIOD_H1, PERIOD_H4};

// --- Implementations --------------------------------------------------------
void LoadTrendStrategyConfig(TrendStrategyConfig &config,
                             const string symbolCsv,
                             const string timeframeCsv)
{
   config.name                   = "TrendFollowing";
   config.fastEmaPeriod          = 21;
   config.slowEmaPeriod          = 55;
   config.signalSmoothing        = 9;
   config.macdSignalPeriod       = 9;
   config.minSlope               = 0.0003;
   config.minConfidence          = 35.0;
   config.stopAtrMultiplier      = 2.5;
   config.takeProfitAtrMultiplier= 4.0;

   if(StringLen(symbolCsv) > 0 && StrategyConfig_ParseSymbols(symbolCsv, config.universe.symbols) == 0)
      StrategyConfig_CopyStrings(config.universe.symbols, TREND_DEFAULT_SYMBOLS);
   else if(StringLen(symbolCsv) == 0)
      StrategyConfig_CopyStrings(config.universe.symbols, TREND_DEFAULT_SYMBOLS);

   if(StringLen(timeframeCsv) > 0 && StrategyConfig_ParseTimeframes(timeframeCsv, config.universe.timeframes) == 0)
      StrategyConfig_CopyTimeframes(config.universe.timeframes, TREND_DEFAULT_TFS);
   else if(StringLen(timeframeCsv) == 0)
      StrategyConfig_CopyTimeframes(config.universe.timeframes, TREND_DEFAULT_TFS);
}

void LoadMeanReversionConfig(MeanReversionStrategyConfig &config,
                             const string symbolCsv,
                             const string timeframeCsv)
{
   config.name                 = "MeanReversion";
   config.rsiPeriod            = 14;
   config.bollingerPeriod      = 20;
   config.bollingerDeviation   = 2.0;
   config.stochasticKPeriod    = 14;
   config.stochasticDPeriod    = 3;
   config.stochasticSlowing    = 3;
   config.oversoldLevel        = 30.0;
   config.overboughtLevel      = 70.0;
   config.exitBandCompression  = 0.15;
   config.minConfidence        = 30.0;

   if(StringLen(symbolCsv) > 0 && StrategyConfig_ParseSymbols(symbolCsv, config.universe.symbols) == 0)
      StrategyConfig_CopyStrings(config.universe.symbols, MEANREV_DEFAULT_SYMBOLS);
   else if(StringLen(symbolCsv) == 0)
      StrategyConfig_CopyStrings(config.universe.symbols, MEANREV_DEFAULT_SYMBOLS);

   if(StringLen(timeframeCsv) > 0 && StrategyConfig_ParseTimeframes(timeframeCsv, config.universe.timeframes) == 0)
      StrategyConfig_CopyTimeframes(config.universe.timeframes, MEANREV_DEFAULT_TFS);
   else if(StringLen(timeframeCsv) == 0)
      StrategyConfig_CopyTimeframes(config.universe.timeframes, MEANREV_DEFAULT_TFS);
}

void LoadBreakoutStrategyConfig(BreakoutStrategyConfig &config,
                                const string symbolCsv,
                                const string timeframeCsv)
{
   config.name                   = "Breakout";
   config.supportLookback        = 30;
   config.resistanceLookback     = 30;
   config.volumeLookback         = 20;
   config.volumeSpikeMultiplier  = 1.5;
   config.breakoutBufferPoints   = 15;
   config.retestTolerancePoints  = 8;
   config.minConfidence          = 40.0;

   if(StringLen(symbolCsv) > 0 && StrategyConfig_ParseSymbols(symbolCsv, config.universe.symbols) == 0)
      StrategyConfig_CopyStrings(config.universe.symbols, BREAKOUT_DEFAULT_SYMBOLS);
   else if(StringLen(symbolCsv) == 0)
      StrategyConfig_CopyStrings(config.universe.symbols, BREAKOUT_DEFAULT_SYMBOLS);

   if(StringLen(timeframeCsv) > 0 && StrategyConfig_ParseTimeframes(timeframeCsv, config.universe.timeframes) == 0)
      StrategyConfig_CopyTimeframes(config.universe.timeframes, BREAKOUT_DEFAULT_TFS);
   else if(StringLen(timeframeCsv) == 0)
      StrategyConfig_CopyTimeframes(config.universe.timeframes, BREAKOUT_DEFAULT_TFS);
}

void LoadStrategyWeights(StrategyWeightConfig &weights,
                         const double trendWeight,
                         const double meanReversionWeight,
                         const double breakoutWeight,
                         const double conflictThreshold)
{
   double total = trendWeight + meanReversionWeight + breakoutWeight;
   if(total <= 0.0)
      total = 1.0;

   weights.trendWeight          = trendWeight / total;
   weights.meanReversionWeight  = meanReversionWeight / total;
   weights.breakoutWeight       = breakoutWeight / total;
   weights.conflictThreshold    = conflictThreshold;
}

// --- Helpers ----------------------------------------------------------------
int StrategyConfig_ParseSymbols(const string csv, string &output[])
{
   ArrayResize(output, 0);
   if(StringLen(csv) == 0)
      return 0;

   string tokens[];
   int count = StringSplit(csv, ',', tokens);
   if(count <= 0)
      return 0;

   int valid = 0;
   ArrayResize(output, count);
   for(int i=0; i<count; i++)
   {
      string token = StrategyConfig_Trim(tokens[i]);
      if(StringLen(token) == 0)
         continue;
      output[valid++] = token;
   }
   ArrayResize(output, valid);
   return valid;
}

int StrategyConfig_ParseTimeframes(const string csv, ENUM_TIMEFRAMES &output[])
{
   ArrayResize(output, 0);
   if(StringLen(csv) == 0)
      return 0;

   string tokens[];
   int count = StringSplit(csv, ',', tokens);
   if(count <= 0)
      return 0;

   int valid = 0;
   ArrayResize(output, count);
   for(int i=0; i<count; i++)
   {
      ENUM_TIMEFRAMES tf = StrategyConfig_ParseTimeframeToken(StrategyConfig_Trim(tokens[i]));
      if(tf == ENUM_TIMEFRAMES(-1))
         continue;
      output[valid++] = tf;
   }
   ArrayResize(output, valid);
   return valid;
}

void StrategyConfig_CopyStrings(string &target[], const string source[])
{
   int count = ArraySize(source);
   ArrayResize(target, count);
   for(int i=0; i<count; i++)
      target[i] = source[i];
}

void StrategyConfig_CopyTimeframes(ENUM_TIMEFRAMES &target[], const ENUM_TIMEFRAMES source[])
{
   int count = ArraySize(source);
   ArrayResize(target, count);
   for(int i=0; i<count; i++)
      target[i] = source[i];
}

string StrategyConfig_Trim(const string value)
{
   string trimmed = value;
   while(StringLen(trimmed) > 0 && (trimmed[0] == ' ' || trimmed[0] == '\t'))
      trimmed = StringSubstr(trimmed, 1);
   while(StringLen(trimmed) > 0 && (trimmed[StringLen(trimmed)-1] == ' ' || trimmed[StringLen(trimmed)-1] == '\t'))
      trimmed = StringSubstr(trimmed, 0, StringLen(trimmed)-1);
   return trimmed;
}

ENUM_TIMEFRAMES StrategyConfig_ParseTimeframeToken(const string token)
{
   string upper = StringUpper(token);
   if(upper == "M1")  return PERIOD_M1;
   if(upper == "M5")  return PERIOD_M5;
   if(upper == "M15") return PERIOD_M15;
   if(upper == "M30") return PERIOD_M30;
   if(upper == "H1")  return PERIOD_H1;
   if(upper == "H4")  return PERIOD_H4;
   if(upper == "D1")  return PERIOD_D1;
   if(upper == "W1")  return PERIOD_W1;
   if(upper == "MN1") return PERIOD_MN1;
   return ENUM_TIMEFRAMES(-1);
}
