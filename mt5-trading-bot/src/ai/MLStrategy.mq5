#property copyright "MT5 Trading Bot"
#property link      "https://example.com"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Math\Stat\Math.mqh>
#include <Math\Algebra.mqh>
#include <Math\Neural\NeuralNet.mqh>

#include "PatternRecognition.mqh"
#include "SignalScoring.mqh"

//--- External inputs
input string  InpModelFile             = "models/HybridSignalNet.nn";
input string  InpTrainingDataset       = "data/ml_training_buffer.csv";
input bool    InpEnableNeural          = true;
input bool    InpCollectTraining       = false;
input int     InpFeatureWindow         = 96;
input double  InpRiskPerTrade          = 0.01;
input double  InpMaxSpreadPoints       = 30;
input double  InpTakeProfitATR         = 2.2;
input double  InpStopLossATR           = 1.3;
input double  InpTradeThreshold        = 0.58;
input ENUM_TIMEFRAMES InpFeatureTimeframe = PERIOD_CURRENT;

//--- Constants
#define FEATURE_COUNT 8
#define PERFORMANCE_BUFFER 128

//--- Trading helpers
CTrade         g_trade;
CPositionInfo  g_position;

CPatternRecognizer   g_patterns;
CSignalScoringEngine g_scorer;

double g_perfBuffer[PERFORMANCE_BUFFER];
int    g_perfIndex = 0;
int    g_perfSamples = 0;

struct FeatureVector
  {
   double features[FEATURE_COUNT];
   int    length;
  };

class CAdaptivePredictor
  {
private:
   CNeuralNetwork m_network;
   bool           m_loaded;
   double         m_linearWeights[FEATURE_COUNT];
   double         m_bias;

public:
                     CAdaptivePredictor():m_loaded(false),m_bias(0.1)
                     {
                      ArrayInitialize(m_linearWeights,0.0);
                      m_linearWeights[0] = 0.35;
                      m_linearWeights[1] = 0.25;
                      m_linearWeights[2] = 0.15;
                      m_linearWeights[3] = 0.05;
                      m_linearWeights[4] = 0.1;
                      m_linearWeights[5] = 0.2;
                      m_linearWeights[6] = 0.18;
                      m_linearWeights[7] = 0.12;
                     }

   bool              LoadModel(const string file)
     {
      if(!InpEnableNeural)
        {
         m_loaded = false;
         return false;
        }

      ResetLastError();
      if(m_network.Load(file))
        {
         m_loaded = true;
         return true;
        }

      PrintFormat("MLStrategy: Unable to load neural model %s, error %d",file,GetLastError());
      m_loaded = false;
      return false;
     }

   double            Predict(const FeatureVector &fv,double fallback,double &confidence)
     {
      confidence = 0.0;

      if(m_loaded)
        {
         double outputs[1]={0.0};
         if(m_network.SetInput((double&)fv.features,fv.length))
           {
            if(m_network.Calculate())
              {
               if(m_network.GetOutput(outputs,1))
                 {
                  confidence = MathMax(0.0,MathMin(1.0,outputs[0]));
                  return confidence;
                 }
              }
           }
        }

      //--- Statistical fallback (logistic regression)
      double linear = m_bias;
      for(int i = 0; i < fv.length && i < ArraySize(m_linearWeights); ++i)
         linear += fv.features[i] * m_linearWeights[i];
      double sigmoid = 1.0 / (1.0 + MathExp(-linear));
      confidence = sigmoid;
      return 0.5 * sigmoid + 0.5 * fallback;
     }
  };

CAdaptivePredictor g_predictor;

//--- Forward declarations
bool   BuildFeatureVector(const double &open[],const double &high[],const double &low[],const double &close[],const long &volume[],const PatternSignal &pattern,FeatureVector &fv);
void   EvaluateAndTrade();
void   ManagePositions(bool bullish,double score,double atr);
bool   LoadMarketArrays(int window,double &open[],double &high[],double &low[],double &close[],long &volume[]);
double ComputeATR(const double &high[],const double &low[],const double &close[],int period);
SignalContext BuildSignalContext(const double &high[],const double &low[],const double &close[],const PatternSignal &pattern,double atr);
void   LogTrainingRow(const PatternSignal &pattern,const SignalContext &ctx,double nnScore,double finalScore);
double ComputeRSI(const double &close[],int length);
void   RecordPerformance(double pnl);

int OnInit()
  {
   g_patterns.Configure(52,10,36,32,1.35);
   g_scorer.Configure(InpTradeThreshold,2.5,1.8);

   if(InpEnableNeural)
      g_predictor.LoadModel(InpModelFile);

   ArrayInitialize(g_perfBuffer,0.0);

   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   EvaluateAndTrade();
  }

void OnDeinit(const int reason)
  {
   PrintFormat("MLStrategy deinitialized. Reason=%d",reason);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_DEAL_UPDATE)
     {
      if((ENUM_DEAL_ENTRY)trans.entry == DEAL_ENTRY_OUT)
        {
         double pnl = trans.profit + trans.swap + trans.commission;
         RecordPerformance(pnl);
        }
     }
  }

void EvaluateAndTrade()
  {
   double open[],high[],low[],close[];
   long   volume[];
   if(!LoadMarketArrays(InpFeatureWindow,open,high,low,close,volume))
      return;

   PatternSignal primary, secondary;
   ZeroMemory(primary);
   ZeroMemory(secondary);

   g_patterns.Scan(open,high,low,close,primary,secondary);
   PatternSignal active = (primary.pattern != PATTERN_NONE) ? primary : secondary;

   double atr = ComputeATR(high,low,close,14);
   SignalContext ctx = BuildSignalContext(high,low,close,active,atr);
   ctx.historicalWinRate = g_scorer.ScoreHistoricalPerformance(g_perfBuffer,MathMin(g_perfSamples,PERFORMANCE_BUFFER),0.92);

   FeatureVector fv;
   if(!BuildFeatureVector(open,high,low,close,volume,active,fv))
      return;

   double nnConfidence = 0.0;
   double nnScore = g_predictor.Predict(fv,active.confidence,nnConfidence);

   double patternScore = g_scorer.ScorePattern(active,ctx);
   double finalScore = 0.55 * patternScore + 0.35 * nnScore + 0.10 * ctx.historicalWinRate;
   finalScore = MathMax(0.0,MathMin(1.0,finalScore));

   if(InpCollectTraining)
      LogTrainingRow(active,ctx,nnScore,finalScore);

   ManagePositions(active.bullish,finalScore,atr);
  }

bool LoadMarketArrays(int window,double &open[],double &high[],double &low[],double &close[],long &volume[])
  {
   if(window <= 32)
      window = 32;

   ENUM_TIMEFRAMES tf = (InpFeatureTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpFeatureTimeframe;

   if(CopyOpen(_Symbol,tf,0,window,open) < window)  return false;
   if(CopyHigh(_Symbol,tf,0,window,high) < window)  return false;
   if(CopyLow(_Symbol,tf,0,window,low) < window)    return false;
   if(CopyClose(_Symbol,tf,0,window,close) < window) return false;
   if(CopyTickVolume(_Symbol,tf,0,window,volume) < window) return false;

   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(volume,true);
   return true;
  }

double ComputeATR(const double &high[],const double &low[],const double &close[],int period)
  {
   if(period < 5)
      period = 5;
   double trSum = 0.0;
   for(int i = 1; i <= period; ++i)
     {
      double prevClose = close[i];
      double tr = MathMax(high[i-1] - low[i-1],MathMax(MathAbs(high[i-1] - prevClose),MathAbs(low[i-1] - prevClose)));
      trSum += tr;
     }
   return trSum / period;
  }

SignalContext BuildSignalContext(const double &high[],const double &low[],const double &close[],const PatternSignal &pattern,double atr)
  {
   SignalContext ctx;
   ctx.regime = pattern.regime;
   ctx.atr = atr;
   ctx.spread = SymbolInfoDouble(_Symbol,SYMBOL_SPREAD) * _Point;
   ctx.volatility = _SeriesStdDev(close,32);
   ctx.liquidityScore = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE) > 0.0 ? 1.0 : 0.6;
   ctx.historicalWinRate = 0.5;
   ctx.payoffRatio = atr > 0.0 ? (InpTakeProfitATR / InpStopLossATR) : 1.0;
   if(g_perfSamples > 0)
     {
      int count = MathMin(g_perfSamples,PERFORMANCE_BUFFER);
      int idx = ArrayMinimum(g_perfBuffer,0,count);
      double worst = g_perfBuffer[idx];
      ctx.drawdownRatio = MathAbs(worst);
     }
   else
      ctx.drawdownRatio = 0.1;
   ctx.sampleSize = g_perfSamples;
   return ctx;
  }

double ComputeRSI(const double &close[],int length)
  {
   if(length < 5)
      length = 5;
   double gain = 0.0;
   double loss = 0.0;
   for(int i = 0; i < length - 1; ++i)
     {
      double delta = close[i] - close[i+1];
      if(delta >= 0)
         gain += delta;
      else
         loss -= delta;
     }

   if(loss == 0.0)
      return 70.0;
   double rs = (gain / (length - 1)) / (loss / (length - 1));
   double rsi = 100.0 - (100.0 / (1.0 + rs));
   return rsi;
  }

bool BuildFeatureVector(const double &open[],const double &high[],const double &low[],const double &close[],const long &volume[],const PatternSignal &pattern,FeatureVector &fv)
  {
   ArrayInitialize(fv.features,0.0);
   fv.length = FEATURE_COUNT;

   double returns = 0.0;
   for(int i = 0; i < 12; ++i)
      returns += (close[i] - close[i+1]);

   double volatility = _SeriesStdDev(close,32);
   double momentum = _SeriesSlope(close,32);
   double rsi = ComputeRSI(close,14) / 100.0;
   double baseVolume = (double)volume[5];
   if(baseVolume <= 0.0)
      baseVolume = 1.0;
   double volChange = (double)volume[0] / baseVolume - 1.0;

   fv.features[0] = momentum;
   fv.features[1] = volatility;
   fv.features[2] = returns;
   fv.features[3] = rsi;
   fv.features[4] = volChange;
   fv.features[5] = pattern.confidence;
   fv.features[6] = pattern.velocity;
   fv.features[7] = pattern.bullish ? 1.0 : 0.0;

   return true;
  }

void ManagePositions(bool bullish,double score,double atr)
  {
   if(score < InpTradeThreshold)
      return;

   if(SymbolInfoDouble(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints)
      return;

   if(g_position.Select(_Symbol))
     {
      bool longPosition = g_position.PositionType() == POSITION_TYPE_BUY;
      if(longPosition != bullish)
        {
         g_trade.PositionClose(_Symbol);
        }
      else
        {
         // tighten stops based on confidence
         double price = longPosition ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double sl = longPosition ? price - InpStopLossATR * atr : price + InpStopLossATR * atr;
         double tp = longPosition ? price + InpTakeProfitATR * atr : price - InpTakeProfitATR * atr;
         g_trade.PositionModify(_Symbol,sl,tp);
        }
      return;
     }

   double lots = 0.1;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(atr > 0.0)
     {
      double riskValue = balance * InpRiskPerTrade;
      double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double stopPoints = (InpStopLossATR * atr) / _Point;
      if(tickValue > 0.0 && stopPoints > 0.0)
         lots = MathMax(0.01,NormalizeDouble(riskValue / (tickValue * stopPoints),2));
     }

   double price = bullish ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl = bullish ? price - InpStopLossATR * atr : price + InpStopLossATR * atr;
   double tp = bullish ? price + InpTakeProfitATR * atr : price - InpTakeProfitATR * atr;

   ENUM_ORDER_TYPE orderType = bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   g_trade.PositionOpen(_Symbol,orderType,lots,price,sl,tp,"MLStrategy");
  }

void LogTrainingRow(const PatternSignal &pattern,const SignalContext &ctx,double nnScore,double finalScore)
  {
   int handle = FileOpen(InpTrainingDataset,FILE_CSV|FILE_WRITE|FILE_READ|FILE_COMMON,';');
   if(handle == INVALID_HANDLE)
      return;

   FileSeek(handle,0,SEEK_END);
   FileWrite(handle,
             TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
             _Symbol,
             EnumToString(pattern.pattern),
             EnumToString(pattern.regime),
             DoubleToString(pattern.confidence,4),
             DoubleToString(pattern.velocity,4),
             DoubleToString(ctx.atr,5),
             DoubleToString(ctx.spread,6),
             DoubleToString(ctx.historicalWinRate,4),
             DoubleToString(nnScore,4),
             DoubleToString(finalScore,4));
   FileClose(handle);
  }

void RecordPerformance(double pnl)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double normalized = 0.0;
   if(balance > 0.0)
      normalized = MathMax(-1.0,MathMin(1.0,pnl / balance));
   g_perfBuffer[g_perfIndex % PERFORMANCE_BUFFER] = normalized;
   g_perfIndex++;
   g_perfSamples = MathMin(g_perfSamples + 1,PERFORMANCE_BUFFER);
  }

