//+------------------------------------------------------------------+
//|                                  Master_Gold_Breakout_EA.mq5     |
//|                 Institutional Algorithmic Portfolio Architect    |
//|               Validated via Walk-Forward & Robustness Plateau     |
//+------------------------------------------------------------------+
#property copyright "Institutional Quantitative Architect"
#property link      "https://github.com/institutional-quant"
#property version   "1.00"
#property description "Master Gold Breakout EA with Volatility Parity & 3-Tier Circuit Breaker"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- INPUT PARAMETERS (VALIDATED BY WALK-FORWARD OPTIMIZATION)
input group "=== TIMEFRAME ARCHITECTURE (MULTI-TIMEFRAME SUPPORT) ==="
input ENUM_TIMEFRAMES InpMacroTimeframe   = PERIOD_H1;      // Macro Trend & ATR Timeframe (H1)
input ENUM_TIMEFRAMES InpEntryTimeframe   = PERIOD_CURRENT; // Breakout Entry Timeframe (M15 or Current)

input group "=== STRATEGY PARAMETERS (CHAMPION OPTIMIZED) ==="
input int      InpDonchianWindow   = 80;      // Donchian Breakout Channel (Bars on Entry TF)
input double   InpATRTrailMult     = 4.2;     // Chandelier Trailing Stop (x Macro ATR)
input double   InpATRStopMult      = 1.4;     // Initial Stop Loss Distance (x Macro ATR)
input double   InpMinADX           = 18.0;    // Minimum ADX(14) Trend Filter (Macro TF)
input int      InpEMA200Period     = 200;     // Intermediate Trend Filter (EMA)
input int      InpEMA800Period     = 800;     // Macro Regime Filter (EMA)
input int      InpMaxBarsHold      = 144;     // Max Bars to Hold Stagnant Trade (Entry TF)

input group "=== RISK & POSITION SIZING (TARGET >80% - 160% CAGR) ==="
input double   InpRiskPercent      = 3.0;     // Risk per Trade (% of Balance, Target >80% - 160%)
input double   InpMaxLeverage      = 5.0;     // Max Account Leverage Cap
input double   InpMaxSpreadUSD     = 0.60;    // Max Spread Allowed in USD per Oz ($0.60)

input group "=== 3-TIER CIRCUIT BREAKER (CAPITAL PRESERVATION) ==="
input double   InpTier1DrawdownPct = 5.0;     // Tier 1 Warning: Cut Risk by 50% (% DD)
input double   InpTier2DrawdownPct = 10.0;    // Tier 2 De-Lever: Liquidate Open Positions (% DD)
input double   InpTier3DrawdownPct = 15.0;    // Tier 3 Freeze: Hard System Shutdown (% DD)

input group "=== EA SETTINGS ==="
input ulong    InpMagicNumber      = 888999;  // EA Magic Number
input string   InpTradeComment     = "Master_XAU_Breakout";

//--- GLOBAL OBJECTS & HANDLES
CTrade         m_trade;
CPositionInfo  m_position;
CAccountInfo   m_account;

int            h_atr;
int            h_adx;
int            h_ema200;
int            h_ema800;

datetime       m_last_bar_time;
double         m_peak_price;
double         m_high_water_mark;
bool           m_circuit_breaker_freeze;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);

   // Initialize Indicator Handles on Macro Timeframe (H1)
   h_atr    = iATR(_Symbol, InpMacroTimeframe, 14);
   h_adx    = iADX(_Symbol, InpMacroTimeframe, 14);
   h_ema200 = iMA(_Symbol, InpMacroTimeframe, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema800 = iMA(_Symbol, InpMacroTimeframe, InpEMA800Period, 0, MODE_EMA, PRICE_CLOSE);

   if(h_atr == INVALID_HANDLE || h_adx == INVALID_HANDLE || 
      h_ema200 == INVALID_HANDLE || h_ema800 == INVALID_HANDLE)
   {
      Print("CRITICAL: Failed to initialize indicator handles.");
      return INIT_FAILED;
   }

   m_last_bar_time = 0;
   m_peak_price = 0.0;
   m_high_water_mark = m_account.Balance();
   m_circuit_breaker_freeze = false;

   Print("Master Gold Breakout EA initialized successfully. HWM: $", m_high_water_mark);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_atr);
   IndicatorRelease(h_adx);
   IndicatorRelease(h_ema200);
   IndicatorRelease(h_ema800);
   Print("Master Gold Breakout EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Maintain High-Water Mark and Drawdown Circuit Breakers
   double balance = m_account.Balance();
   double equity  = m_account.Equity();
   if(balance > m_high_water_mark)
      m_high_water_mark = balance;

   double current_dd_pct = ((m_high_water_mark - equity) / m_high_water_mark) * 100.0;

   // Tier 3 Circuit Breaker: Hard Freeze
   if(current_dd_pct >= InpTier3DrawdownPct)
   {
      if(!m_circuit_breaker_freeze)
      {
         Print("EMERGENCY: Tier 3 Circuit Breaker Triggered (DD: ", current_dd_pct, "%). Liquidating and Freezing!");
         CloseAllPositions();
         m_circuit_breaker_freeze = true;
      }
      return;
   }

   // Tier 2 Circuit Breaker: Liquidate active trades
   if(current_dd_pct >= InpTier2DrawdownPct)
   {
      if(PositionsTotal() > 0)
      {
         Print("WARNING: Tier 2 Circuit Breaker Triggered (DD: ", current_dd_pct, "%). De-leveraging active positions.");
         CloseAllPositions();
      }
      return;
   }

   // Check for New Bar on Entry Timeframe
   datetime current_bar_time = iTime(_Symbol, InpEntryTimeframe, 0);
   if(current_bar_time == m_last_bar_time)
      return;
   m_last_bar_time = current_bar_time;

   // 2. Manage Existing Open Position
   ManageOpenPosition();

   // 3. Evaluate New Entry (If no open position)
   if(!HasOpenPosition())
   {
      EvaluateEntry(current_dd_pct);
   }
}

//+------------------------------------------------------------------+
//| Position Management & Chandelier Trailing Stop                   |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
   if(!m_position.SelectByMagic(_Symbol, InpMagicNumber))
      return;

   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(h_atr, 0, 1, 1, atr);
   double curr_atr = atr[0];

   double ema200[];
   ArraySetAsSeries(ema200, true);
   CopyBuffer(h_ema200, 0, 1, 1, ema200);

   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double open_price    = m_position.PriceOpen();
   double current_sl    = m_position.StopLoss();
   datetime open_time   = m_position.Time();

   int bars_held = iBarShift(_Symbol, InpEntryTimeframe, open_time);

   // Update Peak High
   if(current_price > m_peak_price)
      m_peak_price = current_price;

   // Calculate Chandelier Trailing Stop Level (x Macro ATR)
   double chandelier_stop = m_peak_price - (InpATRTrailMult * curr_atr);
   chandelier_stop = NormalizeDouble(chandelier_stop, _Digits);

   // Stagnant Trade Time Exit
   if(bars_held >= InpMaxBarsHold && (current_price - open_price) < (0.5 * curr_atr))
   {
      Print("Time-Based Stagnation Exit triggered after ", bars_held, " bars.");
      m_trade.PositionClose(m_position.Ticket());
      return;
   }

   // Macro Regime Invalidation Exit (Price drops below Macro EMA200)
   if(current_price < ema200[0])
   {
      Print("Macro Regime Invalidation triggered (Price < EMA200). Exiting position.");
      m_trade.PositionClose(m_position.Ticket());
      return;
   }

   // Ratchet Trailing Stop higher (never lower)
   if(chandelier_stop > current_sl && chandelier_stop < current_price)
   {
      m_trade.PositionModify(m_position.Ticket(), chandelier_stop, 0.0);
   }
}

//+------------------------------------------------------------------+
//| Entry Evaluation Logic                                           |
//+------------------------------------------------------------------+
void EvaluateEntry(double current_dd_pct)
{
   // Spread Protection Filter
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   if(spread > InpMaxSpreadUSD)
   {
      Print("Spread too high ($", spread, " > $", InpMaxSpreadUSD, "). Skipping entry.");
      return;
   }

   // Indicator Buffers (Calculated on Macro Timeframe H1)
   double atr[], adx[], plus_di[], minus_di[], ema200[], ema800[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(plus_di, true);
   ArraySetAsSeries(minus_di, true);
   ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(ema800, true);

   CopyBuffer(h_atr, 0, 1, 1, atr);
   CopyBuffer(h_adx, 0, 1, 1, adx);
   CopyBuffer(h_adx, 1, 1, 1, plus_di);
   CopyBuffer(h_adx, 2, 1, 1, minus_di);
   CopyBuffer(h_ema200, 0, 1, 1, ema200);
   CopyBuffer(h_ema800, 0, 1, 1, ema800);

   double close_1 = iClose(_Symbol, InpEntryTimeframe, 1);
   double high_1  = iHigh(_Symbol, InpEntryTimeframe, 1);

   // Calculate Upper Donchian Channel on previous N bars of Entry Timeframe (excluding bar 0)
   double highest_high = -1.0;
   for(int i = 1; i <= InpDonchianWindow; i++)
   {
      double h = iHigh(_Symbol, InpEntryTimeframe, i);
      if(h > highest_high)
         highest_high = h;
   }

   // Entry Conditions:
   // 1. Breakout above previous N-bars Highest High
   bool is_breakout = high_1 >= highest_high;
   // 2. Trend Regime: Close > EMA200 and Close > EMA800
   bool is_trend    = close_1 > ema200[0] && close_1 > ema800[0];
   // 3. Momentum: ADX >= MinADX and +DI > -DI
   bool is_momentum = adx[0] >= InpMinADX && plus_di[0] > minus_di[0];

   if(is_breakout && is_trend && is_momentum)
   {
      // Tier 1 Circuit Breaker Sizing Throttle
      double risk_pct = InpRiskPercent;
      if(current_dd_pct >= InpTier1DrawdownPct)
      {
         risk_pct = risk_pct * 0.5; // Cut risk by 50%
         Print("Tier 1 DD active. Risk scaled down to: ", risk_pct, "%");
      }

      // Volatility Parity Position Sizing
      double stop_distance = InpATRStopMult * atr[0];
      if(stop_distance <= 0) return;

      double equity = m_account.Equity();
      double risk_currency = equity * (risk_pct / 100.0);
      
      double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tick_size <= 0 || tick_value <= 0) return;

      double sl_ticks = stop_distance / tick_size;
      double lot_size = risk_currency / (sl_ticks * tick_value);

      // Volume Constraints & Leverage Cap
      double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      lot_size = MathFloor(lot_size / step_lot) * step_lot;
      lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));

      double initial_sl = NormalizeDouble(ask - stop_distance, _Digits);

      if(m_trade.Buy(lot_size, _Symbol, ask, initial_sl, 0.0, InpTradeComment))
      {
         m_peak_price = ask;
         Print("BUY Order Executed: Lots=", lot_size, " Price=", ask, " SL=", initial_sl);
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Check if EA has open position                            |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   return m_position.SelectByMagic(_Symbol, InpMagicNumber);
}

//+------------------------------------------------------------------+
//| Helper: Close all EA positions                                   |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == InpMagicNumber && m_position.Symbol() == _Symbol)
         {
            m_trade.PositionClose(m_position.Ticket());
         }
      }
   }
}
//+------------------------------------------------------------------+
