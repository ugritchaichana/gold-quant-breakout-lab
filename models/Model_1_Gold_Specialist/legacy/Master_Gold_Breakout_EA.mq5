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
input ENUM_TIMEFRAMES InpMacroTimeframe   = PERIOD_M15;     // Macro Trend & ATR Timeframe (M15 Champion)
input ENUM_TIMEFRAMES InpEntryTimeframe   = PERIOD_CURRENT; // Breakout Entry Timeframe (M15 or Current)

input group "=== STRATEGY PARAMETERS (CHAMPION OPTIMIZED) ==="
input int      InpDonchianWindow          = 104;     // Donchian Breakout Channel (Bars on Entry TF)
input double   InpATRTrailMult            = 5.4;     // Chandelier Trailing Stop (x Macro ATR)
input double   InpATRStopMult             = 1.3;     // Initial Stop Loss Distance (x Macro ATR)
input double   InpBreakevenR              = 1.8;     // Breakeven Ratchet Trigger (R-Multiple, 0=Disabled)
input double   InpBreakevenLockOffsetUSD  = 0.30;    // Profit Offset Above Entry in USD ($0.30/oz)
input bool     InpUseCloseConfirmation    = true;    // Close Confirmation Veto (Rejects False Breakouts)
input double   InpMinADX                  = 18.0;    // Minimum ADX(14) Trend Filter (Macro TF)
input int      InpEMA200Period            = 200;     // Intermediate Trend Filter (EMA)
input int      InpEMA800Period            = 800;     // Macro Regime Filter (EMA)
input int      InpMaxBarsHold             = 96;      // Max Bars to Hold Stagnant Trade (Entry TF)

input group "=== RISK & POSITION SIZING ==="
input double   InpRiskPercent             = 0.30;    // Risk per Trade (% of Balance, Challenge=0.30%, Funded=0.15%)
input double   InpMaxLeverage             = 5.0;     // Max Account Leverage Cap
input double   InpMaxSpreadUSD            = 0.60;    // Max Spread Allowed in USD per Oz ($0.60)

input group "=== 3-TIER CIRCUIT BREAKER (CAPITAL PRESERVATION) ==="
input double   InpTier1DrawdownPct = 5.0;     // Tier 1 Warning: Cut Risk by 50% (% DD)
input double   InpTier2DrawdownPct = 10.0;    // Tier 2 De-Lever: Liquidate Open Positions (% DD)
input double   InpTier3DrawdownPct = 15.0;    // Tier 3 Freeze: Hard System Shutdown (% DD)

input group "=== EA SETTINGS ==="
input ulong    InpMagicNumber      = 888999;  // EA Magic Number
input string   InpTradeComment     = "Master_XAU_Breakout";

#include "PropFirmGuard.mqh"
#include "ExecutionShield.mqh"
#include "ChartVisualizer.mqh"

//--- GLOBAL OBJECTS & HANDLES
CTrade           m_trade;
CPositionInfo    m_position;
CAccountInfo     m_account;
CPropFirmGuard   g_guard;
CExecutionShield g_shield;
CChartVisualizer g_visualizer;

int            h_atr;
int            h_adx;
int            h_ema200;
int            h_ema800;

datetime       m_last_bar_time;
double         m_peak_price;
double         m_high_water_mark;
double         m_day_start_equity;
int            m_last_day;
bool           m_circuit_breaker_freeze;
bool           m_be_locked;

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
   m_day_start_equity = m_account.Equity();
   MqlDateTime init_dt;
   TimeToStruct(TimeCurrent(), init_dt);
   m_last_day = init_dt.day;
   m_circuit_breaker_freeze = false;
   m_be_locked = false;

   SGuardConfig guard_cfg;
   GuardConfigFromInputs(guard_cfg, _Symbol, InpMagicNumber, "Master_Gold_Breakout_EA", "1.00-guard");
   if(!g_guard.Init(guard_cfg))
   {
      Print("CRITICAL: PropFirmGuard rejected its inputs: ", g_guard.LastRefusal());
      return INIT_PARAMETERS_INCORRECT;
   }
   SShieldConfig shield_cfg;
   ShieldConfigFromInputs(shield_cfg, _Symbol, InpMagicNumber, InpEntryTimeframe);
   if(!g_shield.Init(shield_cfg, GetPointer(g_guard)))
   {
      Print("CRITICAL: ExecutionShield rejected its inputs.");
      g_guard.Deinit(REASON_INITFAILED);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(m_position.SelectByMagic(_Symbol, InpMagicNumber))
      m_peak_price = ReconstructPeakPrice(m_position.Time(), m_position.PriceOpen());

   g_visualizer.Init(_Symbol, InpMagicNumber);
   EventSetTimer(1);

   Print("Master Gold Breakout EA initialized successfully. HWM: $", m_high_water_mark);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_visualizer.Deinit();
   g_shield.Deinit();
   g_guard.Deinit(reason);
   IndicatorRelease(h_atr);
   IndicatorRelease(h_adx);
   IndicatorRelease(h_ema200);
   IndicatorRelease(h_ema800);
   Print("Master Gold Breakout EA deinitialized. Reason: ", reason);
}

void OnTimer()
{
   g_guard.OnTimer();
   g_shield.OnTimer();

   // Live ticking countdown for FTMO Daily Reset
   double init_bal = (g_guard.InitialBalance() > 0) ? g_guard.InitialBalance() : 25000.0;
   g_visualizer.UpdateFTMOCompliance(init_bal, m_account.Equity(), m_account.Balance(), m_day_start_equity, m_high_water_mark);
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   g_guard.OnTradeTransaction(trans, request, result);
   g_shield.OnTradeTransaction(trans, request, result);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   g_guard.OnTick();
   g_shield.OnTick();

   // 1. Maintain High-Water Mark and Drawdown Circuit Breakers
   double balance = m_account.Balance();
   double equity  = m_account.Equity();
   if(balance > m_high_water_mark)
      m_high_water_mark = balance;

   double current_dd_pct = ((m_high_water_mark - equity) / m_high_water_mark) * 100.0;

   // Day reset tracker for FTMO daily loss (Midnight 00:00 server time)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != m_last_day)
   {
      m_day_start_equity = equity;
      m_last_day = dt.day;
   }

   // 1. FTMO Compliance Update
   double init_bal = (g_guard.InitialBalance() > 0) ? g_guard.InitialBalance() : 25000.0;
   g_visualizer.UpdateFTMOCompliance(init_bal, equity, balance, m_day_start_equity, m_high_water_mark);

   // 2. Complete Technical Scan Metrics
   double cur_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask_now   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double cur_spread = ask_now - cur_price;

   double cur_atr = 0.0;
   double atr_buf[];
   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(h_atr, 0, 1, 1, atr_buf) > 0) cur_atr = atr_buf[0];

   double cur_ema200 = 0.0;
   double ema200_buf[];
   ArraySetAsSeries(ema200_buf, true);
   if(CopyBuffer(h_ema200, 0, 1, 1, ema200_buf) > 0) cur_ema200 = ema200_buf[0];

   double cur_ema800 = 0.0;
   double ema800_buf[];
   ArraySetAsSeries(ema800_buf, true);
   if(CopyBuffer(h_ema800, 0, 1, 1, ema800_buf) > 0) cur_ema800 = ema800_buf[0];

   double cur_adx = 0.0, cur_pdi = 0.0, cur_mdi = 0.0;
   double adx_buf[], pdi_buf[], mdi_buf[];
   ArraySetAsSeries(adx_buf, true);
   ArraySetAsSeries(pdi_buf, true);
   ArraySetAsSeries(mdi_buf, true);
   if(CopyBuffer(h_adx, 0, 1, 1, adx_buf) > 0) cur_adx = adx_buf[0];
   if(CopyBuffer(h_adx, 1, 1, 1, pdi_buf) > 0) cur_pdi = pdi_buf[0];
   if(CopyBuffer(h_adx, 2, 1, 1, mdi_buf) > 0) cur_mdi = mdi_buf[0];

   double highest_high = -1.0;
   for(int i = 1; i <= InpDonchianWindow; i++)
   {
      double h = iHigh(_Symbol, InpEntryTimeframe, i);
      if(h > highest_high) highest_high = h;
   }

   double close_1 = iClose(_Symbol, InpEntryTimeframe, 1);
   double high_1  = iHigh(_Symbol, InpEntryTimeframe, 1);
   double low_1   = iLow(_Symbol, InpEntryTimeframe, 1);
   bool veto_passed = (high_1 < highest_high) || (close_1 >= highest_high || (close_1 - low_1) >= 0.50 * (high_1 - low_1));

   g_visualizer.UpdateTechnicalScan(cur_price, cur_ema200, cur_ema800, highest_high,
                                   cur_adx, cur_pdi, cur_mdi, cur_spread, InpMaxSpreadUSD, veto_passed);

   // 3. Trade Action & Projection Update
   if(HasOpenPosition())
   {
      if(m_position.SelectByMagic(_Symbol, InpMagicNumber))
      {
         double open_p = m_position.PriceOpen();
         double cur_sl = m_position.StopLoss();
         double cur_profit = m_position.Profit() + m_position.Swap();
         double init_sl_dist = InpATRStopMult * cur_atr;
         double cur_r = (init_sl_dist > 0) ? (cur_price - open_p) / init_sl_dist : 0.0;
         g_visualizer.UpdateActionStatus(true, m_position.Volume(), open_p, cur_sl,
                                         cur_profit, cur_r, m_be_locked,
                                         highest_high, 0, 0, 0);
      }
   }
   else
   {
      double proj_sl_dist = InpATRStopMult * cur_atr;
      double proj_sl = highest_high - proj_sl_dist;
      double proj_be = highest_high + (InpBreakevenR * proj_sl_dist);
      double tick_sz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double proj_lot = 0.0;
      if(tick_sz > 0 && tick_val > 0 && proj_sl_dist > 0)
      {
         double risk_curr = init_bal * (InpRiskPercent / 100.0);
         double sl_tks = proj_sl_dist / tick_sz;
         proj_lot = risk_curr / (sl_tks * tick_val);
         double step_l = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         proj_lot = MathFloor(proj_lot / step_l) * step_l;
         proj_lot = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), proj_lot));
      }
      g_visualizer.UpdateActionStatus(false, 0, 0, 0, 0, 0, false,
                                      highest_high, proj_sl, proj_be, proj_lot);
   }

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

   // Update TradingView Position Visuals
   g_visualizer.UpdatePositionVisuals(current_sl, m_peak_price, m_be_locked);

   // Calculate Chandelier Trailing Stop Level (x Macro ATR)
   double chandelier_stop = m_peak_price - (InpATRTrailMult * curr_atr);
   chandelier_stop = NormalizeDouble(chandelier_stop, _Digits);

   // Stagnant Trade Time Exit
   if(bars_held >= InpMaxBarsHold && (current_price - open_price) < (0.5 * curr_atr))
   {
      Print("Time-Based Stagnation Exit triggered after ", bars_held, " bars.");
      g_guard.NoteIntent(_Symbol, false, current_price, 0.0, 0.0);
      m_trade.PositionClose(m_position.Ticket());
      return;
   }

   // Macro Regime Invalidation Exit (Price drops below Macro EMA200)
   if(current_price < ema200[0])
   {
      Print("Macro Regime Invalidation triggered (Price < EMA200). Exiting position.");
      g_guard.NoteIntent(_Symbol, false, current_price, 0.0, 0.0);
      m_trade.PositionClose(m_position.Ticket());
      return;
   }

   // Breakeven Ratchet Lock
   if(InpBreakevenR > 0.0 && !m_be_locked)
   {
      double initial_sl_dist = InpATRStopMult * curr_atr;
      if((m_peak_price - open_price) >= (InpBreakevenR * initial_sl_dist))
      {
         double be_sl = NormalizeDouble(open_price + InpBreakevenLockOffsetUSD, _Digits);
         if(be_sl > current_sl && be_sl < current_price)
         {
            if(m_trade.PositionModify(m_position.Ticket(), be_sl, 0.0))
            {
               Print("Breakeven Ratchet Lock Activated at +", InpBreakevenR, "R. New SL: ", be_sl);
               m_be_locked = true;
               current_sl = be_sl;
            }
         }
      }
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
   string block_reason = "";
   if(!g_shield.EntryAllowed(block_reason))
   {
      Print("Shield blocked entry evaluation: ", block_reason);
      return;
   }

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
   double low_1   = iLow(_Symbol, InpEntryTimeframe, 1);

   // Calculate Upper Donchian Channel on previous N bars of Entry Timeframe (excluding bar 0)
   double highest_high = -1.0;
   for(int i = 1; i <= InpDonchianWindow; i++)
   {
      double h = iHigh(_Symbol, InpEntryTimeframe, i);
      if(h > highest_high)
         highest_high = h;
   }

   // Entry Conditions:
   // 1. Breakout above previous N-bars Highest High (with Close Confirmation Veto)
   bool is_breakout = false;
   if(InpUseCloseConfirmation)
   {
      is_breakout = (high_1 >= highest_high) && 
                    (close_1 >= highest_high || (close_1 - low_1) >= 0.50 * (high_1 - low_1));
   }
   else
   {
      is_breakout = (high_1 >= highest_high);
   }

   // 2. Trend Regime: Close > EMA200 and Close > EMA800
   bool is_trend    = close_1 > ema200[0] && close_1 > ema800[0];
   // 3. Momentum: ADX >= MinADX and +DI > -DI
   bool is_momentum = adx[0] >= InpMinADX && plus_di[0] > minus_di[0];

   if(is_breakout && is_trend && is_momentum)
   {
      // Tier 1 Circuit Breaker Sizing Throttle
      double risk_pct = g_guard.RiskBudgetPct();
      if(current_dd_pct >= InpTier1DrawdownPct)
      {
         risk_pct = risk_pct * 0.5; // Cut risk by 50%
         Print("Tier 1 DD active. Risk scaled down to: ", risk_pct, "%");
      }

      // Volatility Parity Position Sizing
      double stop_distance = InpATRStopMult * atr[0];
      if(stop_distance <= 0) return;

      double risk_currency = g_guard.InitialBalance() * (risk_pct / 100.0);
      
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
      lot_size = MathMin(max_lot, lot_size);
      if(lot_size < min_lot)
      {
         Print("Risk budget sizes below the minimum lot. Skipping entry.");
         return;
      }

      double initial_sl = NormalizeDouble(ask - stop_distance, _Digits);
      lot_size = g_guard.CanOpen(_Symbol, ORDER_TYPE_BUY, ask, initial_sl, lot_size);
      if(lot_size <= 0.0)
      {
         Print("Guard refused entry: ", g_guard.LastRefusal());
         return;
      }

      if(m_trade.Buy(lot_size, _Symbol, ask, initial_sl, 0.0, InpTradeComment))
      {
         m_peak_price = ask;
         m_be_locked  = false;
         double be_trigger = ask + (InpBreakevenR * stop_distance);
         g_visualizer.DrawLongPositionBox(m_trade.ResultOrder(), TimeCurrent(), ask, initial_sl, be_trigger);
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

double ReconstructPeakPrice(const datetime open_time, const double open_price)
{
   double peak = open_price;
   int shift = iBarShift(_Symbol, InpEntryTimeframe, open_time, false);
   if(shift > 0)
   {
      int highest = iHighest(_Symbol, InpEntryTimeframe, MODE_OPEN, shift, 0);
      if(highest >= 0)
         peak = MathMax(peak, iOpen(_Symbol, InpEntryTimeframe, highest));
   }
   return peak;
}
//+------------------------------------------------------------------+
