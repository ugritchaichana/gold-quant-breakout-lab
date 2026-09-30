//+------------------------------------------------------------------+
//|                                            QuantRegimeFilter.mqh |
//|                                  Copyright 2026, Quant EA Lab.   |
//|                         Unified 5-Model Multi-Asset Architecture |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quant EA Lab."
#property link      "https://github.com/quant-ea-lab"
#property strict

#include "QuantDefines.mqh"

//+------------------------------------------------------------------+
//| Class CQuantRegimeFilter                                         |
//+------------------------------------------------------------------+
class CQuantRegimeFilter
{
public:
   //--- Calculate Kaufman Efficiency Ratio (KER)
   //    KER = |Net Price Change| / Sum of Absolute Price Changes
   //    KER >= 0.35 indicates trending / expansion regime.
   //    KER <  0.35 indicates choppy / sideways noise.
   static double CalculateKER(string symbol, ENUM_TIMEFRAMES tf, int period)
   {
      if(period <= 1) return 1.0;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(symbol, tf, 1, period + 1, rates);
      if(copied < period + 1) return 0.0;
      
      double net_change = MathAbs(rates[0].close - rates[period].close);
      double total_path = 0.0;
      
      for(int i = 0; i < period; i++)
      {
         total_path += MathAbs(rates[i].close - rates[i+1].close);
      }
      
      if(total_path <= 0.0) return 0.0;
      return (net_change / total_path);
   }

   //--- Determine Macro Trend Regime via Dual EMAs (e.g. H4 or H1)
   static ENUM_REGIME_TYPE GetMacroTrend(int fast_handle, int slow_handle, string symbol, ENUM_TIMEFRAMES tf)
   {
      double fast_val[1], slow_val[1];
      if(CopyBuffer(fast_handle, 0, 1, 1, fast_val) <= 0) return REGIME_SIDEWAYS_CHOP;
      if(CopyBuffer(slow_handle, 0, 1, 1, slow_val) <= 0) return REGIME_SIDEWAYS_CHOP;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(symbol, tf, 1, 1, rates) <= 0) return REGIME_SIDEWAYS_CHOP;
      
      double close_price = rates[0].close;
      
      if(close_price > fast_val[0] && fast_val[0] > slow_val[0])
         return REGIME_EXPANSION_BULL;
      else if(close_price < fast_val[0] && fast_val[0] < slow_val[0])
         return REGIME_EXPANSION_BEAR;
         
      return REGIME_SIDEWAYS_CHOP;
   }
};
