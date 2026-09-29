//+------------------------------------------------------------------+
//|                                Master_Gold_Scalper_Grid.mq5       |
//|                 Institutional Algorithmic Portfolio Architect    |
//|               High-Frequency Scalper & Dynamic ATR Recovery Grid  |
//+------------------------------------------------------------------+
#property copyright "Institutional Quantitative Architect"
#property link      "https://github.com/institutional-quant"
#property version   "2.00"
#property description "Master Gold High-Frequency Scalper & Dynamic ATR Grid EA"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- INPUT PARAMETERS (CONFIGURABLE FOR DEEP OPTIMIZATION)
input group "=== CORE STRATEGY & TIMEFRAME SETTINGS ==="
input int      InpTrendEMA         = 200;     // Higher Trend Filter (EMA Bars)
input int      InpMacroEMA         = 800;     // Macro Regime Filter (EMA Bars)
input int      InpATRPeriod        = 14;      // ATR Period for Dynamic Volatility
input int      InpRSI期的          = 14;      // RSI Period for Scalp Entries
input double   InpRSIOversold      = 35.0;    // RSI Oversold Level (Long Entry)
input double   InpRSIOverbought    = 65.0;    // RSI Overbought Level (Short Entry)

input group "=== DYNAMIC GRID & PYRAMIDING SETTINGS ==="
input double   InpGridStepATR      = 1.2;     // Dynamic Grid Spacing (Multiplier x ATR14)
input double   InpTakeProfitATR    = 2.0;     // Individual Take Profit (Multiplier x ATR14)
input int      InpMaxGridOrders    = 4;       // Max Allowed Open Grid Orders per Basket
input double   InpLotMultiplier    = 1.25;    // Volume Progression Multiplier (Conservative Martingale/Progression)
input double   InpBasketTPUSD      = 75.0;    // Basket Target Profit in USD (All positions closed)

input group "=== CAPITAL & COMPOUNDING RISK ENGINE ==="
input double   InpBaseRiskPercent  = 2.0;     // Base Risk / Lot Sizing (% of Equity, Target >80% - 160%)
input double   InpMaxSpreadUSD     = 0.50;    // Max Spread Allowed in USD per Oz ($0.50)
input bool     InpAutoCompound     = true;    // Auto-Compound Position Size as Equity Grows

input group "=== HARD BASKET CIRCUIT BREAKER ==="
input double   InpMaxBasketLossPct = 15.0;    // Hard Basket Stop-Loss (% Drawdown on Basket to Liquidate)
input double   InpMaxDailyLossPct  = 18.0;    // Hard Daily Circuit Breaker (% Loss of Starting Daily Equity)

input group "=== EA ENVIRONMENT SETTINGS ==="
input ulong    InpMagicNumber      = 999111;  // Magic Number for Order Management
input string   InpTradeComment     = "Master_Scalp_Grid";

//--- GLOBAL HANDLES & OBJECTS
CTrade         m_trade;
CPositionInfo  m_position;
CAccountInfo   m_account;

int            h_atr;
int            h_rsi;
int            h_ema_trend;
int            h_ema_macro;

double         m_starting_daily_equity;
int            m_current_day;
bool           m_daily_lockout;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);

   // Initialize Indicator Handles on Current Chart Timeframe
   h_atr       = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   h_rsi       = iRSI(_Symbol, PERIOD_CURRENT, InpRSI期的, PRICE_CLOSE);
   h_ema_trend = iMA(_Symbol, PERIOD_CURRENT, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_macro = iMA(_Symbol, PERIOD_CURRENT, InpMacroEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(h_atr == INVALID_HANDLE || h_rsi == INVALID_HANDLE || 
      h_ema_trend == INVALID_HANDLE || h_ema_macro == INVALID_HANDLE)
   {
      Print("CRITICAL: Failed to initialize indicator handles.");
      return INIT_FAILED;
   }

   m_starting_daily_equity = m_account.Equity();
   MqlDateTime dt;
   TimeCurrent(dt);
   m_current_day = dt.day;
   m_daily_lockout = false;

   Print("Master Gold Scalper Grid EA initialized successfully on ", _Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_atr);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_ema_trend);
   IndicatorRelease(h_ema_macro);
   Print("Master Gold Scalper Grid EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Maintain Daily Reset and Daily Loss Circuit Breaker
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.day != m_current_day)
   {
      m_current_day = dt.day;
      m_starting_daily_equity = m_account.Equity();
      m_daily_lockout = false;
   }

   double equity = m_account.Equity();
   double daily_loss_pct = ((m_starting_daily_equity - equity) / m_starting_daily_equity) * 100.0;
   if(daily_loss_pct >= InpMaxDailyLossPct)
   {
      if(!m_daily_lockout)
      {
         Print("CRITICAL: Max Daily Loss Hit (", daily_loss_pct, "%). Liquidating all trades for today.");
         CloseAllGridPositions();
         m_daily_lockout = true;
      }
      return;
   }

   if(m_daily_lockout) return;

   // 2. Monitor Open Basket Profit / Loss Circuit Breaker
   MonitorBasket();

   // 3. Evaluate Grid Layers and New Scalp Entries
   ManageGridEntries();
}

//+------------------------------------------------------------------+
//| Monitor Basket: Checks Total Profit / Hard Loss Circuit Breaker  |
//+------------------------------------------------------------------+
void MonitorBasket()
{
   double total_basket_pnl = 0.0;
   int basket_count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == InpMagicNumber && m_position.Symbol() == _Symbol)
         {
            total_basket_pnl += m_position.Profit() + m_position.Swap();
            basket_count++;
         }
      }
   }

   if(basket_count == 0) return;

   // Check Basket Take Profit target in USD
   if(total_basket_pnl >= InpBasketTPUSD)
   {
      Print("BASKET TP HIT: Total Profit $", total_basket_pnl, " >= $", InpBasketTPUSD, ". Closing entire basket!");
      CloseAllGridPositions();
      return;
   }

   // Check Hard Basket Drawdown Stop Loss
   double balance = m_account.Balance();
   double basket_loss_pct = (MathAbs(MathMin(0.0, total_basket_pnl)) / balance) * 100.0;
   if(basket_loss_pct >= InpMaxBasketLossPct)
   {
      Print("HARD STOP: Basket Drawdown Hit -", basket_loss_pct, "% >= -", InpMaxBasketLossPct, "%. Liquidating basket!");
      CloseAllGridPositions();
      return;
   }
}

//+------------------------------------------------------------------+
//| Manage Grid Entries: First Entry & Dynamic ATR Spacing Addition  |
//+------------------------------------------------------------------+
void ManageGridEntries()
{
   // Check Spread Protection
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   if(spread > InpMaxSpreadUSD)
      return;

   // Fetch Indicators
   double atr[], rsi[], ema_trend[], ema_macro[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(ema_trend, true);
   ArraySetAsSeries(ema_macro, true);

   CopyBuffer(h_atr, 0, 1, 1, atr);
   CopyBuffer(h_rsi, 0, 1, 1, rsi);
   CopyBuffer(h_ema_trend, 0, 1, 1, ema_trend);
   CopyBuffer(h_ema_macro, 0, 1, 1, ema_macro);

   double curr_atr = atr[0];
   double curr_rsi = rsi[0];
   double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   // Determine Higher Trend Bias (Only Long if Bullish, Only Short if Bearish)
   bool is_bullish = close_1 > ema_trend[0] && close_1 > ema_macro[0];
   bool is_bearish = close_1 < ema_trend[0] && close_1 < ema_macro[0];

   // Count open positions and find lowest/highest entry prices
   int buy_count = 0;
   int sell_count = 0;
   double lowest_buy_price = 9999999.0;
   double highest_sell_price = -1.0;
   double last_lot = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == InpMagicNumber && m_position.Symbol() == _Symbol)
         {
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               buy_count++;
               if(m_position.PriceOpen() < lowest_buy_price)
                  lowest_buy_price = m_position.PriceOpen();
               last_lot = m_position.Volume();
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
            {
               sell_count++;
               if(m_position.PriceOpen() > highest_sell_price)
                  highest_sell_price = m_position.PriceOpen();
               last_lot = m_position.Volume();
            }
         }
      }
   }

   double dynamic_grid_step = InpGridStepATR * curr_atr;

   // 1. BUY SIDE GRID LOGIC (Trending Bullish)
   if(is_bullish)
   {
      // First Entry on RSI Pullback
      if(buy_count == 0 && sell_count == 0)
      {
         if(curr_rsi <= InpRSIOversold)
         {
            double base_lot = CalculateBaseLot(curr_atr);
            double tp = ask + (InpTakeProfitATR * curr_atr);
            m_trade.Buy(base_lot, _Symbol, ask, 0.0, tp, InpTradeComment);
            Print("SCALPER FIRST BUY: Lots=", base_lot, " Price=", ask, " TP=", tp);
         }
      }
      // Grid Recovery / Pyramiding Addition
      else if(buy_count > 0 && buy_count < InpMaxGridOrders)
      {
         if(ask <= (lowest_buy_price - dynamic_grid_step))
         {
            double next_lot = NormalizeDouble(last_lot * InpLotMultiplier, 2);
            next_lot = ValidateLotSize(next_lot);
            double tp = ask + (InpTakeProfitATR * curr_atr);
            m_trade.Buy(next_lot, _Symbol, ask, 0.0, tp, InpTradeComment);
            Print("GRID LAYER BUY #", buy_count + 1, ": Lots=", next_lot, " Price=", ask);
         }
      }
   }

   // 2. SELL SIDE GRID LOGIC (Trending Bearish)
   else if(is_bearish)
   {
      // First Entry on RSI Overbought
      if(sell_count == 0 && buy_count == 0)
      {
         if(curr_rsi >= InpRSIOverbought)
         {
            double base_lot = CalculateBaseLot(curr_atr);
            double tp = bid - (InpTakeProfitATR * curr_atr);
            m_trade.Sell(base_lot, _Symbol, bid, 0.0, tp, InpTradeComment);
            Print("SCALPER FIRST SELL: Lots=", base_lot, " Price=", bid, " TP=", tp);
         }
      }
      // Grid Recovery / Pyramiding Addition
      else if(sell_count > 0 && sell_count < InpMaxGridOrders)
      {
         if(bid >= (highest_sell_price + dynamic_grid_step))
         {
            double next_lot = NormalizeDouble(last_lot * InpLotMultiplier, 2);
            next_lot = ValidateLotSize(next_lot);
            double tp = bid - (InpTakeProfitATR * curr_atr);
            m_trade.Sell(next_lot, _Symbol, bid, 0.0, tp, InpTradeComment);
            Print("GRID LAYER SELL #", sell_count + 1, ": Lots=", next_lot, " Price=", bid);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Base Lot from Equity & Risk %                          |
//+------------------------------------------------------------------+
double CalculateBaseLot(double curr_atr)
{
   double equity = InpAutoCompound ? m_account.Equity() : m_account.Balance();
   double risk_currency = equity * (InpBaseRiskPercent / 100.0);

   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_size <= 0 || tick_value <= 0 || curr_atr <= 0)
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   // Estimate stop reference as 2.0x ATR for initial lot sizing
   double est_stop_ticks = (2.0 * curr_atr) / tick_size;
   double calculated_lot = risk_currency / (est_stop_ticks * tick_value);

   return ValidateLotSize(calculated_lot);
}

//+------------------------------------------------------------------+
//| Validate and Normalize Lot Size                                  |
//+------------------------------------------------------------------+
double ValidateLotSize(double lot)
{
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lot = MathFloor(lot / step_lot) * step_lot;
   lot = MathMax(min_lot, MathMin(max_lot, lot));
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Close all Grid positions                                         |
//+------------------------------------------------------------------+
void CloseAllGridPositions()
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
