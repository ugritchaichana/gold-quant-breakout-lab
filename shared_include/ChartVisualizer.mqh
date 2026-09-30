//+------------------------------------------------------------------+
//|                                              ChartVisualizer.mqh |
//|                 Institutional HUD Panel & TradingView Position   |
//|                 FTMO Swing Rules & Technical Scan Control Center |
//|                 Color on White Edition (TradingView Teal/Coral)  |
//|                 Optimized for 27" Full-Screen Display            |
//+------------------------------------------------------------------+
#ifndef CHART_VISUALIZER_MQH
#define CHART_VISUALIZER_MQH

#include <Trade\Trade.mqh>

class CChartVisualizer
{
private:
   string   m_prefix;
   string   m_symbol;
   ulong    m_magic;
   long     m_chart_id;
   int      m_corner;
   
   // Position Visual Tracking
   bool     m_pos_active;
   ulong    m_active_ticket;
   datetime m_entry_time;
   double   m_entry_price;
   double   m_initial_sl;
   double   m_be_trigger;

   // Theme Colors (Color on White - TradingView Palette)
   color    m_c_bg;
   color    m_c_border;
   color    m_c_title;
   color    m_c_subtitle;
   color    m_c_params;
   color    m_c_label;
   color    m_c_val;
   color    m_c_sep;
   color    m_c_teal;   // Bullish Teal (#26a69a)
   color    m_c_coral;  // Bearish Coral (#ef5350)
   color    m_c_amber;  // Warning / BE Amber
   color    m_c_blue;   // Projection Cyan

   // Position Box Colors
   color    m_box_risk_bg;
   color    m_box_risk_border;
   color    m_box_reward_bg;
   color    m_box_reward_border;
   color    m_line_entry;
   color    m_line_be;

public:
   CChartVisualizer() : m_prefix("QHUD_"), m_chart_id(0), m_corner(CORNER_LEFT_UPPER), m_pos_active(false) {}
   ~CChartVisualizer() { Deinit(); }

   void Init(string symbol, ulong magic)
   {
      m_symbol = symbol;
      m_magic  = magic;
      m_prefix = "QHUD_" + IntegerToString(magic) + "_";
      SetThemeColors();
      CreateDashboardPanel();
   }

   void Deinit()
   {
      ObjectsDeleteAll(m_chart_id, m_prefix);
      ChartRedraw(m_chart_id);
   }

   void SetThemeColors()
   {
      // Color on White: Premium Swiss Quant Minimalist
      m_c_bg              = C'255,255,255'; // Clean White Card
      m_c_border          = C'210,222,233'; // Soft Slate Border (1px)
      m_c_title           = C'16,120,105';  // Deep TradingView Teal
      m_c_subtitle        = C'95,108,125';  // Muted Slate
      m_c_params          = C'40,90,140';   // Indigo Parameter Highlight
      m_c_label           = C'100,112,128'; // Category Label Gray
      m_c_val             = C'20,28,38';    // High-Contrast Charcoal Black
      m_c_sep             = C'235,240,246'; // Soft Divider
      m_c_teal            = C'26,155,140';  // Bullish Teal Green (#26a69a)
      m_c_coral           = C'235,80,75';   // Bearish Coral Red (#ef5350)
      m_c_amber           = C'225,135,25';  // Golden Amber (#f59e0b)
      m_c_blue            = C'20,120,200';  // Projection Blue

      // TradingView Position Box
      m_box_risk_bg       = C'255,233,233'; // Pastel Coral Wash
      m_box_risk_border   = C'235,85,80';
      m_box_reward_bg     = C'224,248,244'; // Pastel Teal Wash
      m_box_reward_border = C'26,160,145';
      m_line_entry        = C'35,45,60';
      m_line_be           = C'225,135,25';
   }

   //+------------------------------------------------------------------+
   //| 1. DASHBOARD PANEL SETUP (400px x 430px FOR 27" DISPLAY)         |
   //+------------------------------------------------------------------+
   void CreateDashboardPanel()
   {
      string bg_name = m_prefix + "BG";
      if(ObjectFind(m_chart_id, bg_name) < 0)
      {
         ObjectCreate(m_chart_id, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_XDISTANCE, 18);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_YDISTANCE, 45);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_XSIZE, 385);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_YSIZE, 425);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_BGCOLOR, m_c_bg);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_BORDER_COLOR, m_c_border);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(m_chart_id, bg_name, OBJPROP_SELECTABLE, false);
      }

      // HEADER
      SetLabel("TITLE", "★ GOLD QUANT BREAKOUT CHAMPION", 30, 56, 10, m_c_title, true);
      SetLabel("BENCH", "FTMO Swing 25k | SQN: 3.03 | Calmar: 7.44", 30, 74, 8, m_c_subtitle, false);
      SetLabel("PARAMS", "Donchian: 104 | SL: 1.3x | Trail: 5.4x | BE: 1.8R | Risk: 0.30%", 30, 90, 8, m_c_params, true);

      CreateHLine("SEP1", 28, 108, 365);

      // SECTION 1: FTMO SWING RULES MONITOR
      SetLabel("S1_TITLE", "◈ FTMO SWING ACCOUNT COMPLIANCE", 30, 114, 8, m_c_label, true);
      
      SetLabel("L_TARGET_T", "Total Net PnL / Target:", 30, 130, 8, m_c_label);
      SetLabel("L_TARGET_V", "+$0.00 (+0.00%) / Target +10% (+$2,500)", 30, 145, 9, m_c_val, true);

      SetLabel("L_DAILY_T", "Daily Loss (Reset 00:00):", 30, 163, 8, m_c_label);
      SetLabel("L_DAILY_V", "$0.00 (0.00%) / Limit -5.00% (-$1,250)", 30, 178, 9, m_c_teal, true);

      SetLabel("L_MAXDD_T", "Max Overall Loss:", 30, 196, 8, m_c_label);
      SetLabel("L_MAXDD_V", "$0.00 (0.00%) / Limit -10.00% (-$2,500)", 30, 211, 9, m_c_teal, true);

      CreateHLine("SEP2", 28, 230, 365);

      // SECTION 2: TECHNICAL SCAN MATRIX
      SetLabel("S2_TITLE", "◈ SYSTEM TECHNICAL SCAN (M15 BARS)", 30, 236, 8, m_c_label, true);

      SetLabel("L_TREND_T", "Trend Filter (EMA 200 / 800):", 30, 252, 8, m_c_label);
      SetLabel("L_TREND_V", "Scanning...", 30, 267, 9, m_c_teal, true);

      SetLabel("L_DONCH_T", "Donchian 104 Breakout Level:", 30, 285, 8, m_c_label);
      SetLabel("L_DONCH_V", "High: 4170.50 (Diff: -5.30 pts)", 30, 300, 9, m_c_val, true);

      SetLabel("L_MOM_T", "Momentum (ADX14 +DI / -DI):", 30, 318, 8, m_c_label);
      SetLabel("L_MOM_V", "ADX: 24.5 | +DI > -DI (CONFIRMED)", 30, 333, 9, m_c_teal, true);

      SetLabel("L_SPREAD_T", "Spread & Veto Shield:", 30, 351, 8, m_c_label);
      SetLabel("L_SPREAD_V", "Spread: $0.18 (Max: $0.60) | Veto: READY", 30, 366, 9, m_c_teal, true);

      CreateHLine("SEP3", 28, 385, 365);

      // SECTION 3: TRADE ACTION & PROJECTION
      SetLabel("L_ACT_TITLE", "◈ ACTION & EXECUTION STATUS", 30, 391, 8, m_c_label, true);
      SetLabel("L_ACT_V", "SCANNING FOR ENTRY (Touch >= 4170.50)", 30, 407, 9, m_c_amber, true);
      SetLabel("L_ACT_SUB", "Proj SL: 4158.20 | Proj BE: 4192.60 | Lot: 0.25", 30, 423, 8, m_c_subtitle, false);
   }

   //+------------------------------------------------------------------+
   //| UPDATE LIVE METRICS & COMPLIANCE                                 |
   //+------------------------------------------------------------------+
   void UpdateFTMOCompliance(double initial_bal, double equity, double balance,
                             double day_start_equity, double hwm)
   {
      // 1. Total Net Profit vs +10% Target
      double net_profit = equity - initial_bal;
      double net_profit_pct = (initial_bal > 0) ? (net_profit / initial_bal) * 100.0 : 0.0;
      double target_usd = initial_bal * 0.10;
      color c_target = (net_profit >= 0) ? m_c_teal : m_c_coral;
      string target_str = StringFormat("%s$%.2f (%+.2f%%) / Target +10.0%% (+$%.0f)",
                                       (net_profit >= 0 ? "+" : ""), net_profit, net_profit_pct, target_usd);
      SetLabel("L_TARGET_V", target_str, 30, 145, 9, c_target, true);

      // 2. Daily Loss vs 5.0% Limit (Resets 00:00 server time)
      datetime cur_server_time = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(cur_server_time, dt);
      int sec_left = (23 - dt.hour) * 3600 + (59 - dt.min) * 60 + (59 - dt.sec);
      if(sec_left < 0) sec_left = 0;
      int h_left = sec_left / 3600;
      int m_left = (sec_left % 3600) / 60;
      int s_left = sec_left % 60;
      string cd_str = StringFormat("%02dh %02dm %02ds", h_left, m_left, s_left);
      SetLabel("L_DAILY_T", "Daily Loss [Reset in " + cd_str + "]:", 30, 163, 8, m_c_label);
      double daily_loss_usd = day_start_equity - equity;
      double daily_loss_pct = (initial_bal > 0) ? (daily_loss_usd / initial_bal) * 100.0 : 0.0;
      double daily_limit_usd = initial_bal * 0.05;
      
      color c_daily = m_c_teal;
      if(daily_loss_pct >= 3.0) c_daily = m_c_coral;
      else if(daily_loss_pct >= 2.0) c_daily = m_c_amber;

      string daily_str = StringFormat("%s$%.2f (%.2f%%) / Limit -5.00%% (-$%.0f)",
                                      (daily_loss_usd > 0 ? "-" : "+"), MathAbs(daily_loss_usd), daily_loss_pct, daily_limit_usd);
      SetLabel("L_DAILY_V", daily_str, 30, 178, 9, c_daily, true);

      // 3. Max Overall Loss vs 10.0% Limit (Static Floor $22,500 on $25k)
      double overall_loss_usd = initial_bal - equity;
      double overall_loss_pct = (initial_bal > 0) ? (overall_loss_usd / initial_bal) * 100.0 : 0.0;
      double overall_limit_usd = initial_bal * 0.10;

      color c_overall = m_c_teal;
      if(overall_loss_pct >= 6.0) c_overall = m_c_coral;
      else if(overall_loss_pct >= 4.0) c_overall = m_c_amber;

      string overall_str = StringFormat("%s$%.2f (%.2f%%) / Limit -10.00%% (-$%.0f)",
                                        (overall_loss_usd > 0 ? "-" : "+"), MathAbs(overall_loss_usd), overall_loss_pct, overall_limit_usd);
      SetLabel("L_MAXDD_V", overall_str, 30, 211, 9, c_overall, true);
   }

   void UpdateTechnicalScan(double cur_price, double ema200, double ema800,
                            double donchian_high, double adx_val, double plus_di, double minus_di,
                            double spread_usd, double max_spread, bool veto_passed)
   {
      // Trend: Price vs EMA200 & EMA800
      bool is_trend = (cur_price > ema200 && cur_price > ema800);
      string trend_str = StringFormat("%s (P: %.2f > EMA200: %.2f)", 
                                      (is_trend ? "BULLISH PASS" : "NEUTRAL / WAIT"), cur_price, ema200);
      SetLabel("L_TREND_V", trend_str, 30, 267, 9, is_trend ? m_c_teal : m_c_subtitle, true);

      // Donchian Breakout High
      double dist_to_high = donchian_high - cur_price;
      string donch_str = StringFormat("High: %.2f (Dist: %+.2f pts) %s", 
                                      donchian_high, dist_to_high, (dist_to_high <= 0 ? "★ BREAKOUT" : ""));
      SetLabel("L_DONCH_V", donch_str, 30, 300, 9, (dist_to_high <= 0 ? m_c_amber : m_c_val), true);

      // Momentum: ADX & DI
      bool is_mom = (adx_val >= 18.0 && plus_di > minus_di);
      string mom_str = StringFormat("ADX: %.1f %s | +DI: %.1f > -DI: %.1f",
                                    adx_val, (is_mom ? "(STRONG)" : "(WEAK)"), plus_di, minus_di);
      SetLabel("L_MOM_V", mom_str, 30, 333, 9, is_mom ? m_c_teal : m_c_subtitle, true);

      // Spread & Veto
      bool spread_ok = (spread_usd <= max_spread);
      string spread_str = StringFormat("Spread: $%.2f (%s) | Close Veto: %s",
                                       spread_usd, (spread_ok ? "OK" : "HIGH"), (veto_passed ? "PASS" : "WAIT"));
      SetLabel("L_SPREAD_V", spread_str, 30, 366, 9, (spread_ok && veto_passed) ? m_c_teal : m_c_amber, true);
   }

   void UpdateActionStatus(bool in_pos, double lots, double open_p, double cur_sl, 
                           double cur_profit, double cur_r, bool be_locked,
                           double proj_entry, double proj_sl, double proj_be, double proj_lot)
   {
      if(in_pos)
      {
         string act_str = StringFormat("ACTIVE: BUY %.2f @ %.2f | SL: %.2f | %s$%.2f (%+.1fR)",
                                       lots, open_p, cur_sl, (cur_profit >= 0 ? "+" : ""), cur_profit, cur_r);
         color c_act = (cur_profit >= 0) ? m_c_teal : m_c_coral;
         SetLabel("L_ACT_V", act_str, 30, 407, 9, c_act, true);

         string sub_str = StringFormat("BE Trigger: %.2f [%s] | Trailing SL: %.2f",
                                       open_p + (cur_sl > 0 ? (open_p - cur_sl)*1.8 : 0),
                                       (be_locked ? "LOCKED +$0.30" : "PENDING"), cur_sl);
         SetLabel("L_ACT_SUB", sub_str, 30, 423, 8, be_locked ? m_c_teal : m_c_subtitle, false);
      }
      else
      {
         string act_str = StringFormat("SCANNING: Next Breakout Trigger >= %.2f", proj_entry);
         SetLabel("L_ACT_V", act_str, 30, 407, 9, m_c_amber, true);

         string sub_str = StringFormat("Proj SL: %.2f | Proj BE (+1.8R): %.2f | Lot: %.2f",
                                       proj_sl, proj_be, proj_lot);
         SetLabel("L_ACT_SUB", sub_str, 30, 423, 8, m_c_blue, false);
         RemovePositionVisuals();
         m_pos_active = false;
      }
      ChartRedraw(m_chart_id);
   }

   //+------------------------------------------------------------------+
   //| 2. TRADINGVIEW-STYLE LONG POSITION BOX VISUALIZER                |
   //+------------------------------------------------------------------+
   void DrawLongPositionBox(ulong ticket, datetime open_time, double open_price, double initial_sl, double be_trigger)
   {
      m_pos_active    = true;
      m_active_ticket = ticket;
      m_entry_time    = open_time;
      m_entry_price   = open_price;
      m_initial_sl    = initial_sl;
      m_be_trigger    = be_trigger;

      datetime future_time = open_time + (PeriodSeconds(PERIOD_CURRENT) * 35);

      // Red Risk Box (Pastel Coral)
      string risk_box = m_prefix + "RISK_BOX";
      ObjectCreate(m_chart_id, risk_box, OBJ_RECTANGLE, 0, open_time, open_price, future_time, initial_sl);
      ObjectSetInteger(m_chart_id, risk_box, OBJPROP_COLOR, m_box_risk_border);
      ObjectSetInteger(m_chart_id, risk_box, OBJPROP_BGCOLOR, m_box_risk_bg);
      ObjectSetInteger(m_chart_id, risk_box, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chart_id, risk_box, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chart_id, risk_box, OBJPROP_BACK, true);
      ObjectSetInteger(m_chart_id, risk_box, OBJPROP_FILL, true);

      // Green Profit Box (Pastel Teal)
      string reward_box = m_prefix + "REWARD_BOX";
      ObjectCreate(m_chart_id, reward_box, OBJ_RECTANGLE, 0, open_time, be_trigger, future_time, open_price);
      ObjectSetInteger(m_chart_id, reward_box, OBJPROP_COLOR, m_box_reward_border);
      ObjectSetInteger(m_chart_id, reward_box, OBJPROP_BGCOLOR, m_box_reward_bg);
      ObjectSetInteger(m_chart_id, reward_box, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chart_id, reward_box, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chart_id, reward_box, OBJPROP_BACK, true);
      ObjectSetInteger(m_chart_id, reward_box, OBJPROP_FILL, true);

      // Entry Price Line
      string entry_line = m_prefix + "LINE_ENTRY";
      ObjectCreate(m_chart_id, entry_line, OBJ_TREND, 0, open_time, open_price, future_time, open_price);
      ObjectSetInteger(m_chart_id, entry_line, OBJPROP_COLOR, m_line_entry);
      ObjectSetInteger(m_chart_id, entry_line, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chart_id, entry_line, OBJPROP_WIDTH, 2);
      ObjectSetInteger(m_chart_id, entry_line, OBJPROP_RAY_RIGHT, true);

      // Breakeven Trigger Line (+1.8R)
      string be_line = m_prefix + "LINE_BE";
      ObjectCreate(m_chart_id, be_line, OBJ_TREND, 0, open_time, be_trigger, future_time, be_trigger);
      ObjectSetInteger(m_chart_id, be_line, OBJPROP_COLOR, m_line_be);
      ObjectSetInteger(m_chart_id, be_line, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(m_chart_id, be_line, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chart_id, be_line, OBJPROP_RAY_RIGHT, true);

      // Initial SL Line (-1.0R)
      string sl_line = m_prefix + "LINE_SL";
      ObjectCreate(m_chart_id, sl_line, OBJ_TREND, 0, open_time, initial_sl, future_time, initial_sl);
      ObjectSetInteger(m_chart_id, sl_line, OBJPROP_COLOR, m_c_coral);
      ObjectSetInteger(m_chart_id, sl_line, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chart_id, sl_line, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chart_id, sl_line, OBJPROP_RAY_RIGHT, true);

      ChartRedraw(m_chart_id);
   }

   void UpdatePositionVisuals(double current_sl, double peak_price, bool be_locked)
   {
      if(!m_pos_active) return;

      datetime cur_time = TimeCurrent();
      datetime right_edge = cur_time + (PeriodSeconds(PERIOD_CURRENT) * 25);

      string risk_box = m_prefix + "RISK_BOX";
      ObjectSetInteger(m_chart_id, risk_box, OBJPROP_TIME, 1, right_edge);

      string reward_box = m_prefix + "REWARD_BOX";
      ObjectSetInteger(m_chart_id, reward_box, OBJPROP_TIME, 1, right_edge);
      if(peak_price > m_be_trigger)
         ObjectSetDouble(m_chart_id, reward_box, OBJPROP_PRICE, 0, peak_price);

      string be_line = m_prefix + "LINE_BE";
      if(be_locked)
      {
         ObjectSetInteger(m_chart_id, be_line, OBJPROP_COLOR, m_c_teal);
         ObjectSetInteger(m_chart_id, be_line, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(m_chart_id, be_line, OBJPROP_WIDTH, 2);
      }

      string sl_line = m_prefix + "LINE_SL";
      if(current_sl > m_initial_sl)
      {
         ObjectSetDouble(m_chart_id, sl_line, OBJPROP_PRICE, 0, current_sl);
         ObjectSetDouble(m_chart_id, sl_line, OBJPROP_PRICE, 1, current_sl);
         ObjectSetInteger(m_chart_id, sl_line, OBJPROP_COLOR, be_locked ? m_c_teal : m_c_amber);
      }

      ChartRedraw(m_chart_id);
   }

   void RemovePositionVisuals()
   {
      ObjectDelete(m_chart_id, m_prefix + "RISK_BOX");
      ObjectDelete(m_chart_id, m_prefix + "REWARD_BOX");
      ObjectDelete(m_chart_id, m_prefix + "LINE_ENTRY");
      ObjectDelete(m_chart_id, m_prefix + "LINE_BE");
      ObjectDelete(m_chart_id, m_prefix + "LINE_SL");
      ChartRedraw(m_chart_id);
   }

private:
   void SetLabel(string name_suffix, string text, int x, int y, int font_size, color col, bool bold=false)
   {
      string name = m_prefix + name_suffix;
      if(ObjectFind(m_chart_id, name) < 0)
      {
         ObjectCreate(m_chart_id, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
      }
      ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(m_chart_id, name, OBJPROP_TEXT, text);
      ObjectSetString(m_chart_id, name, OBJPROP_FONT, bold ? "Segoe UI Bold" : "Segoe UI");
      ObjectSetInteger(m_chart_id, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetInteger(m_chart_id, name, OBJPROP_COLOR, col);
   }

   void CreateHLine(string name_suffix, int x, int y, int width)
   {
      string name = m_prefix + name_suffix;
      if(ObjectFind(m_chart_id, name) < 0)
      {
         ObjectCreate(m_chart_id, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chart_id, name, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(m_chart_id, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(m_chart_id, name, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(m_chart_id, name, OBJPROP_XSIZE, width);
         ObjectSetInteger(m_chart_id, name, OBJPROP_YSIZE, 1);
         ObjectSetInteger(m_chart_id, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(m_chart_id, name, OBJPROP_SELECTABLE, false);
      }
      ObjectSetInteger(m_chart_id, name, OBJPROP_BGCOLOR, m_c_sep);
   }
};

#endif
