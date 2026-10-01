//+------------------------------------------------------------------+
//|                                  QuantMasterPortfolioGuard.mqh   |
//|                                  Copyright 2026, Quant EA Lab.   |
//|                         Unified 5-Model Multi-Asset Architecture |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quant EA Lab."
#property link      "https://github.com/quant-ea-lab"
#property strict

#include <Trade\Trade.mqh>
#include "QuantDefines.mqh"

//+------------------------------------------------------------------+
//| Class CQuantMasterPortfolioGuard                                 |
//+------------------------------------------------------------------+
class CQuantMasterPortfolioGuard
{
private:
   double            m_daily_start_equity;
   datetime          m_last_day_checked;
   double            m_hwm_equity;
   int               m_db_handle;
   string            m_db_path;
   bool              m_circuit_tripped;
   CTrade            m_trade;

public:
   CQuantMasterPortfolioGuard() : 
      m_daily_start_equity(0.0), 
      m_last_day_checked(0), 
      m_hwm_equity(0.0), 
      m_db_handle(INVALID_HANDLE),
      m_circuit_tripped(false)
   {
      m_db_path = "quant_journal.sqlite";
   }

   ~CQuantMasterPortfolioGuard()
   {
      if(m_db_handle != INVALID_HANDLE)
      {
         DatabaseClose(m_db_handle);
         m_db_handle = INVALID_HANDLE;
      }
   }

   bool Init()
   {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      m_daily_start_equity = eq;
      m_hwm_equity = MathMax(m_hwm_equity, eq);
      m_last_day_checked = (datetime)(TimeCurrent() / 86400) * 86400;
      m_circuit_tripped = false;

      // Initialize Pure SQLite Journal (Zero CSV Policy)
      m_db_handle = DatabaseOpen(m_db_path, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
      if(m_db_handle != INVALID_HANDLE)
      {
         string sql = "CREATE TABLE IF NOT EXISTS portfolio_journal ("
                      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                      "timestamp INTEGER, "
                      "symbol TEXT, "
                      "action TEXT, "
                      "equity REAL, "
                      "balance REAL, "
                      "daily_dd_pct REAL, "
                      "hwm_equity REAL, "
                      "message TEXT);";
         DatabaseExecute(m_db_handle, sql);
      }
      return true;
   }

   void LogEvent(string symbol, string action, string msg)
   {
      if(m_db_handle == INVALID_HANDLE) return;
      
      datetime now = TimeCurrent();
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double dd = GetDailyDrawdownPct();

      string sql = StringFormat("INSERT INTO portfolio_journal (timestamp, symbol, action, equity, balance, daily_dd_pct, hwm_equity, message) "
                                "VALUES (%d, '%s', '%s', %.2f, %.2f, %.2f, %.2f, '%s');",
                                (int)now, symbol, action, eq, bal, dd, m_hwm_equity, msg);
      DatabaseExecute(m_db_handle, sql);
   }

   double GetDailyDrawdownPct()
   {
      if(m_daily_start_equity <= 0.0) return 0.0;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq >= m_daily_start_equity) return 0.0;
      return ((m_daily_start_equity - eq) / m_daily_start_equity) * 100.0;
   }

   //--- Call on every tick/bar: manages high-water mark, day rollover, and circuit breaker
   ENUM_CIRCUIT_STATUS UpdateAndCheck()
   {
      datetime current_day = (datetime)(TimeCurrent() / 86400) * 86400;
      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);

      // Day rollover check
      if(current_day != m_last_day_checked)
      {
         m_daily_start_equity = current_equity;
         m_last_day_checked = current_day;
         m_circuit_tripped = false;
         LogEvent("PORTFOLIO", "DAY_ROLLOVER", StringFormat("New day start equity: %.2f", current_equity));
      }

      if(current_equity > m_hwm_equity)
         m_hwm_equity = current_equity;

      double daily_dd = GetDailyDrawdownPct();

      // Hard Circuit Breaker (PORTFOLIO_DAILY_LOSS_LIMIT e.g. 2.0%)
      if(daily_dd >= PORTFOLIO_DAILY_LOSS_LIMIT || m_circuit_tripped)
      {
         if(!m_circuit_tripped)
         {
            m_circuit_tripped = true;
            LogEvent("PORTFOLIO", "CIRCUIT_BREAKER_TRIPPED", StringFormat("Hard stop hit: Daily DD %.2f%%. Liquidating all trades.", daily_dd));
            CloseAllPositions();
         }
         return CIRCUIT_HARD_LOCK;
      }

      // Warning Level at 1.0% Daily DD: Scale risk by 50%
      if(daily_dd >= 1.0)
         return CIRCUIT_WARNING;

      return CIRCUIT_NORMAL;
   }

   //--- Server Rollover Spread Window Check (Midnight Blackout)
   bool IsRolloverWindow()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if((dt.hour == ROLLOVER_BLACKOUT_START_HOUR && dt.min >= ROLLOVER_BLACKOUT_START_MIN) ||
         (dt.hour == ROLLOVER_BLACKOUT_END_HOUR && dt.min <= ROLLOVER_BLACKOUT_END_MIN))
      {
         return true; // Inside rollover blackout window!
      }
      return false;
   }

   //--- Veto new trades if circuit tripped, inside rollover window, max trades exceeded, or correlation clash
   bool CanOpenNewPosition(string symbol = "", ENUM_SIGNAL_DIR dir = SIGNAL_NONE)
   {
      if(m_circuit_tripped) return false;
      if(IsRolloverWindow()) return false;
      if(PositionsTotal() >= 4) return false;

      // Dynamic Cross-Asset Correlation Guard
      if(symbol != "" && dir != SIGNAL_NONE)
      {
         int total = PositionsTotal();
         for(int i = 0; i < total; i++)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            string pos_sym = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            ENUM_SIGNAL_DIR pos_dir = (pos_type == POSITION_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL;

            // 1. Tech & Crypto Correlation Guard (NAS100 & BTCUSD)
            if(((StringFind(symbol, "NAS") >= 0 || StringFind(symbol, "USTEC") >= 0) && StringFind(pos_sym, "BTC") >= 0) ||
               (StringFind(symbol, "BTC") >= 0 && (StringFind(pos_sym, "NAS") >= 0 || StringFind(pos_sym, "USTEC") >= 0)))
            {
               if(dir == pos_dir)
               {
                  PrintFormat("[CorrelationGuard] Veto %s %d: Correlated with active %s position!", symbol, dir, pos_sym);
                  return false;
               }
            }

            // 2. Precious Metals & Energy Correlation Guard (XAUUSD & USOIL)
            if(((StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0) && StringFind(pos_sym, "OIL") >= 0) ||
               (StringFind(symbol, "OIL") >= 0 && (StringFind(pos_sym, "XAU") >= 0 || StringFind(pos_sym, "GOLD") >= 0)))
            {
               if(dir == pos_dir)
               {
                  PrintFormat("[CorrelationGuard] Veto %s %d: Correlated with active %s position!", symbol, dir, pos_sym);
                  return false;
               }
            }
         }
      }
      return true;
   }

   void CloseAllPositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            m_trade.PositionClose(ticket);
         }
      }
   }
};
