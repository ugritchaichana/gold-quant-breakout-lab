//+------------------------------------------------------------------+
//|                                     Model_Gold_Specialist.mq5     |
//|                                  Copyright 2026, Quant EA Lab.   |
//|                         Model 1 of 5: Gold Specialist (XAUUSD)   |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Quant EA Lab."
#property link        "https://github.com/quant-ea-lab"
#property version     "2.00"
#property description "Model 1: Gold Specialist (XAUUSD) - H4 Macro Compass + H1 Precision Breakout"
#property strict

//--- Include Shared Framework
#include <QuantShared/QuantDefines.mqh>
#include <QuantShared/QuantRegimeFilter.mqh>
#include <QuantShared/QuantPositionManager.mqh>
#include <QuantShared/QuantMasterPortfolioGuard.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== MODEL IDENTIFICATION ==="
input ulong             InpMagicNumber       = 100101;         // Magic Number (Model 1 Gold)
input string            InpTradeComment      = "M1_GOLD";      // Order Comment

input group "=== CAPITAL & RISK MANAGEMENT ==="
input double            InpRiskPct           = 1.00;           // Risk % per trade (1.00% = $250.00 on $25k)
input double            InpAccountBasePool   = 25000.0;        // Base Account Liquidity Pool ($)

input group "=== TIMEFRAMES & REGIME FILTERS ==="
input ENUM_TIMEFRAMES   InpMacroTF           = PERIOD_H4;      // Macro Compass Timeframe (H4)
input ENUM_TIMEFRAMES   InpEntryTF           = PERIOD_H1;      // Precision Entry Timeframe (H1)
input int               InpFastEMA           = 100;            // Macro Fast EMA
input int               InpSlowEMA           = 200;            // Macro Slow EMA
input int               InpKERPeriod         = 20;             // Kaufman ER Period
input double            InpMinKER            = 0.35;           // Kaufman ER Min Threshold (Anti-Sideway)

input group "=== BREAKOUT & EXECUTION ==="
input int               InpDonchianWindow    = 48;             // Donchian Breakout Period (48 hours = 2 days)
input double            InpATRStopMult       = 1.5;            // ATR Multiplier for Stop Loss
input double            InpTP_R              = 1.35;           // Take Profit R-Multiple (1:1.35)
input double            InpBE_R              = 0.85;           // Fast Breakeven Trigger R-Multiple (+0.85R)
input double            InpATRTrailMult      = 3.5;            // ATR Trailing Stop Multiplier (0 to disable)

input group "=== TIMING & CIRCUIT BREAKER ==="
input int               InpMaxHoldBars       = 72;             // Max Bar Hold (Stagnation Exit)
input int               InpMaxSpreadPoints   = 40;             // Max Spread in Points (Veto if higher)

//--- Global Objects & Handles
CQuantPositionManager        g_pos_mgr;
CQuantMasterPortfolioGuard   g_portfolio_guard;
int                          g_hFastEMA = INVALID_HANDLE;
int                          g_hSlowEMA = INVALID_HANDLE;
int                          g_hATR     = INVALID_HANDLE;
datetime                     g_last_bar_time = 0;
double                       g_last_r_dist   = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_pos_mgr.Init(InpMagicNumber, 20);
   g_portfolio_guard.Init();

   // Initialize Indicators
   g_hFastEMA = iMA(_Symbol, InpMacroTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA = iMA(_Symbol, InpMacroTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hATR     = iATR(_Symbol, InpEntryTF, 14);

   if(g_hFastEMA == INVALID_HANDLE || g_hSlowEMA == INVALID_HANDLE || g_hATR == INVALID_HANDLE)
   {
      Print("[Model_Gold_Specialist] Failed to initialize indicator handles!");
      return INIT_FAILED;
   }

   PrintFormat("[Model_Gold_Specialist] Initialized successfully. Symbol=%s, Risk=%.2f%%, MacroTF=%s, EntryTF=%s",
               _Symbol, InpRiskPct, EnumToString(InpMacroTF), EnumToString(InpEntryTF));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_hFastEMA != INVALID_HANDLE) IndicatorRelease(g_hFastEMA);
   if(g_hSlowEMA != INVALID_HANDLE) IndicatorRelease(g_hSlowEMA);
   if(g_hATR != INVALID_HANDLE)     IndicatorRelease(g_hATR);
}

//+------------------------------------------------------------------+
//| Helper: Get Donchian High / Low                                  |
//+------------------------------------------------------------------+
bool GetDonchianChannel(int period, double &highest_high, double &lowest_low)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, InpEntryTF, 1, period, rates);
   if(copied < period) return false;

   highest_high = rates[0].high;
   lowest_low   = rates[0].low;

   for(int i = 1; i < period; i++)
   {
      if(rates[i].high > highest_high) highest_high = rates[i].high;
      if(rates[i].low < lowest_low)    lowest_low   = rates[i].low;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if Model already has an active position                    |
//+------------------------------------------------------------------+
bool HasActivePosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Account-Level Master Guard Check
   ENUM_CIRCUIT_STATUS circuit = g_portfolio_guard.UpdateAndCheck();
   if(circuit == CIRCUIT_HARD_LOCK) return;

   // 2. Fetch current ATR for trailing & position management
   double atr_val[1];
   if(CopyBuffer(g_hATR, 0, 1, 1, atr_val) <= 0) return;
   double current_atr = atr_val[0];

   // 3. Manage Open Positions (Fast BE & ATR Trailing Stop)
   double trail_dist = (InpATRTrailMult > 0.0) ? (InpATRTrailMult * current_atr) : 0.0;
   g_pos_mgr.ManageTrailingAndBE(InpMagicNumber, _Symbol, InpBE_R, g_last_r_dist, trail_dist);

   // 4. Bar-Level Execution: Only evaluate on new bar of InpEntryTF
   datetime bar_time = iTime(_Symbol, InpEntryTF, 0);
   if(bar_time == g_last_bar_time) return;
   g_last_bar_time = bar_time;

   // 5. If already holding a position, do not stack/open another
   if(HasActivePosition()) return;

   // 6. Concurrency Check: Ensure account has capacity
   if(!g_portfolio_guard.CanOpenNewPosition()) return;

   // 7. Spread Filter
   long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread > InpMaxSpreadPoints) return;

   // 8. Kaufman Efficiency Ratio (Anti-Sideway Veto)
   double ker = CQuantRegimeFilter::CalculateKER(_Symbol, InpEntryTF, InpKERPeriod);
   if(ker < InpMinKER) return; // Choppy regime -> 100% Cash!

   // 9. Macro Trend Filter (H4 Dual EMA)
   ENUM_REGIME_TYPE macro_trend = CQuantRegimeFilter::GetMacroTrend(g_hFastEMA, g_hSlowEMA, _Symbol, InpMacroTF);

   // 10. Donchian Breakout Channel on H1
   double donchian_high = 0.0, donchian_low = 0.0;
   if(!GetDonchianChannel(InpDonchianWindow, donchian_high, donchian_low)) return;

   MqlRates last_bar[];
   ArraySetAsSeries(last_bar, true);
   if(CopyRates(_Symbol, InpEntryTF, 1, 1, last_bar) <= 0) return;

   // Effective Equity calculation
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double effective_risk_pct = (circuit == CIRCUIT_WARNING) ? (InpRiskPct * 0.5) : InpRiskPct;
   double risk_usd = equity * (effective_risk_pct / 100.0);

   // --- BUY SIGNAL EVALUATION ---
   if(macro_trend == REGIME_EXPANSION_BULL && last_bar[0].close >= donchian_high)
   {
      if(!g_portfolio_guard.CanOpenNewPosition(_Symbol, SIGNAL_BUY)) return;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl_dist = InpATRStopMult * current_atr;
      if(sl_dist <= 0.0) return;

      double sl_price = ask - sl_dist;
      double tp_price = ask + (InpTP_R * sl_dist);
      double lots = g_pos_mgr.CalculateNormalizedLots(_Symbol, risk_usd, sl_dist);

      if(lots > 0.0 && g_pos_mgr.OpenBuy(_Symbol, lots, sl_price, tp_price, InpTradeComment))
      {
         g_last_r_dist = sl_dist;
         g_portfolio_guard.LogEvent(_Symbol, "ENTRY_BUY", StringFormat("Lots=%.2f, Ask=%.2f, SL=%.2f, TP=%.2f", lots, ask, sl_price, tp_price));
      }
   }
   // --- SELL SIGNAL EVALUATION ---
   else if(macro_trend == REGIME_EXPANSION_BEAR && last_bar[0].close <= donchian_low)
   {
      if(!g_portfolio_guard.CanOpenNewPosition(_Symbol, SIGNAL_SELL)) return;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl_dist = InpATRStopMult * current_atr;
      if(sl_dist <= 0.0) return;

      double sl_price = bid + sl_dist;
      double tp_price = bid - (InpTP_R * sl_dist);
      double lots = g_pos_mgr.CalculateNormalizedLots(_Symbol, risk_usd, sl_dist);

      if(lots > 0.0 && g_pos_mgr.OpenSell(_Symbol, lots, sl_price, tp_price, InpTradeComment))
      {
         g_last_r_dist = sl_dist;
         g_portfolio_guard.LogEvent(_Symbol, "ENTRY_SELL", StringFormat("Lots=%.2f, Bid=%.2f, SL=%.2f, TP=%.2f", lots, bid, sl_price, tp_price));
      }
   }
}
//+------------------------------------------------------------------+
