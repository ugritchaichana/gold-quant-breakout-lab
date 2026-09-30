#ifndef PROP_FIRM_GUARD_MQH
#define PROP_FIRM_GUARD_MQH

#include <Trade\Trade.mqh>

#define GUARD_JOURNAL_HEADER "time,ticket,symbol,type,volume,intended_price,fill_price,slippage_points,sl,spread_at_entry,planned_risk,magic,r_at_close"

enum ENUM_GUARD_MODE
  {
   GUARD_MODE_CHALLENGE = 0, // Challenge: target lock active
   GUARD_MODE_FUNDED    = 1  // Funded: no target lock
  };

enum ENUM_GUARD_SCOPE
  {
   GUARD_SCOPE_ACCOUNT = 0, // Account: all symbols and magics
   GUARD_SCOPE_MAGIC   = 1  // This EA: magic and symbol only
  };

enum ENUM_GUARD_DAY_MODE
  {
   GUARD_DAY_SERVER          = 0, // Server time
   GUARD_DAY_CET_EU_DST      = 1, // CET with EU daylight saving
   GUARD_DAY_NEW_YORK_US_DST = 2, // New York with US daylight saving
   GUARD_DAY_FIXED_GMT       = 3  // Fixed offset from GMT
  };

enum ENUM_GUARD_SERVER_TZ
  {
   GUARD_SERVER_TZ_AUTO  = 0, // Measured live, model in tester
   GUARD_SERVER_TZ_MODEL = 1  // Model always
  };

enum ENUM_GUARD_DST_RULE
  {
   GUARD_DST_NONE = 0, // No daylight saving
   GUARD_DST_EU   = 1, // EU daylight saving
   GUARD_DST_US   = 2  // US daylight saving
  };

enum ENUM_GUARD_DAY_BASIS
  {
   GUARD_BASIS_BALANCE = 0, // Balance at reset
   GUARD_BASIS_EQUITY  = 1, // Equity at reset
   GUARD_BASIS_MAX     = 2  // Higher of balance and equity at reset
  };

enum ENUM_GUARD_LIMIT_BASE
  {
   GUARD_BASE_INITIAL = 0, // Percent of initial balance
   GUARD_BASE_DAY_REF = 1  // Percent of day reference
  };

enum ENUM_GUARD_FLOOR_MODE
  {
   GUARD_FLOOR_STATIC        = 0, // Static from initial balance
   GUARD_FLOOR_TRAIL_EQUITY  = 1, // Trailing equity high-water mark
   GUARD_FLOOR_TRAIL_BALANCE = 2  // Trailing balance high-water mark
  };

enum ENUM_GUARD_RISK_POLICY
  {
   GUARD_RISK_FIXED = 0, // Fixed percent of initial balance
   GUARD_RISK_CPPI  = 1  // Scaled by cushion to the overall lock
  };

input group "=== PROP FIRM GUARD ==="
input ENUM_GUARD_MODE        InpGuardMode                = GUARD_MODE_CHALLENGE; // Guard mode
input ENUM_GUARD_SCOPE       InpGuardScope               = GUARD_SCOPE_ACCOUNT;  // Liquidation scope
input double                 InpGuardInitialBalance      = 0.0;                  // Initial balance (0 = persisted or first deposit)
input ENUM_GUARD_DAY_MODE    InpGuardDayMode             = GUARD_DAY_CET_EU_DST; // Firm-day reset clock
input int                    InpGuardDayResetHour        = 0;                    // Firm-day reset hour on that clock
input int                    InpGuardDayResetMinute      = 0;                    // Firm-day reset minute on that clock
input int                    InpGuardFixedGmtOffsetMin   = 0;                    // Fixed-GMT clock offset, minutes
input ENUM_GUARD_SERVER_TZ   InpGuardServerTz            = GUARD_SERVER_TZ_AUTO; // Server offset source
input int                    InpGuardServerGmtOffsetMin  = 120;                  // Server model base offset from GMT, minutes
input ENUM_GUARD_DST_RULE    InpGuardServerDstRule       = GUARD_DST_US;         // Server model daylight-saving rule
input ENUM_GUARD_DAY_BASIS   InpGuardDayBasis            = GUARD_BASIS_MAX;      // Day reference basis
input ENUM_GUARD_LIMIT_BASE  InpGuardDailyLimitBase      = GUARD_BASE_INITIAL;   // Daily percent base
input double                 InpGuardFirmDailyLimitPct   = 5.0;                  // Firm daily loss limit, percent
input double                 InpGuardDailyLockPct        = 3.0;                  // Our daily lock, percent
input ENUM_GUARD_FLOOR_MODE  InpGuardFloorMode           = GUARD_FLOOR_STATIC;   // Overall floor type
input bool                   InpGuardFloorStopAtInitial  = true;                 // Trailing floor stops at initial balance
input double                 InpGuardFirmOverallLimitPct = 10.0;                 // Firm overall loss limit, percent of initial
input double                 InpGuardOverallLockPct      = 7.0;                  // Our overall lock, percent of initial
input double                 InpGuardTargetPct           = 10.0;                 // Challenge profit target, percent (0 = off)
input int                    InpGuardUnlockCode          = 0;                    // Change to clear overall, target or state-fault lock
input ENUM_GUARD_RISK_POLICY InpGuardRiskPolicy          = GUARD_RISK_FIXED;     // Risk budget policy
input double                 InpGuardRiskPct             = 0.30;                 // Base risk per trade, percent of initial
input double                 InpGuardSlipBufferPct       = 20.0;                 // Worst-case slippage buffer, percent of stop distance
input double                 InpGuardCommissionPerLot    = 6.0;                  // Round-turn commission per lot, account currency
input int                    InpGuardCloseDeviationPts   = 300;                  // Close deviation, points (instant execution only)
input int                    InpGuardCloseRetries        = 3;                    // Close attempts per call
input int                    InpGuardCloseRetrySleepMs   = 250;                  // Sleep between close attempts, ms
input int                    InpGuardTimerMs             = 500;                  // Timer period live, ms
input int                    InpGuardTimerMsTester       = 60000;                // Timer period in tester, ms
input int                    InpGuardHeartbeatSec        = 10;                   // Heartbeat period, seconds
input bool                   InpGuardHeartbeatInTester   = false;                // Write heartbeat in tester
input bool                   InpGuardJournal             = true;                 // Write trade journal
input int                    InpGuardSnapshotGraceSec    = 120;                  // Seconds after reset a live equity snapshot counts

struct SGuardConfig
  {
   ENUM_GUARD_MODE        mode;
   ENUM_GUARD_SCOPE       scope;
   string                 symbol;
   ulong                  magic;
   double                 initial_balance;
   ENUM_GUARD_DAY_MODE    day_mode;
   int                    day_reset_hour;
   int                    day_reset_minute;
   int                    fixed_gmt_offset_min;
   ENUM_GUARD_SERVER_TZ   server_tz;
   int                    server_gmt_offset_min;
   ENUM_GUARD_DST_RULE    server_dst_rule;
   ENUM_GUARD_DAY_BASIS   day_basis;
   ENUM_GUARD_LIMIT_BASE  daily_limit_base;
   double                 firm_daily_limit_pct;
   double                 daily_lock_pct;
   ENUM_GUARD_FLOOR_MODE  floor_mode;
   bool                   floor_stop_at_initial;
   double                 firm_overall_limit_pct;
   double                 overall_lock_pct;
   double                 target_pct;
   int                    unlock_code;
   ENUM_GUARD_RISK_POLICY risk_policy;
   double                 risk_pct;
   double                 slip_buffer_pct;
   double                 commission_per_lot_rt;
   int                    close_deviation_points;
   int                    close_retries;
   int                    close_retry_sleep_ms;
   int                    timer_ms;
   int                    timer_ms_tester;
   int                    heartbeat_sec;
   bool                   heartbeat_in_tester;
   bool                   journal;
   int                    snapshot_grace_sec;
   string                 folder;
   string                 state_tag;
   string                 ea_name;
   string                 ea_version;
  };

struct SGuardState
  {
   long              login;
   double            initial;
   double            hwm_equity;
   double            hwm_balance;
   long              day_key;
   long              day_start;
   double            day_ref;
   double            day_ref_balance;
   double            day_ref_equity;
   int               day_reconstructed;
   long              daily_lock_key;
   int               overall_locked;
   int               target_locked;
   int               unlock_code;
   int               entries_today;
   int               fault_state;
  };

void GuardConfigFromInputs(SGuardConfig &cfg, const string symbol, const ulong magic, const string ea_name, const string ea_version)
  {
   cfg.mode                   = InpGuardMode;
   cfg.scope                  = InpGuardScope;
   cfg.symbol                 = symbol;
   cfg.magic                  = magic;
   cfg.initial_balance        = InpGuardInitialBalance;
   cfg.day_mode               = InpGuardDayMode;
   cfg.day_reset_hour         = InpGuardDayResetHour;
   cfg.day_reset_minute       = InpGuardDayResetMinute;
   cfg.fixed_gmt_offset_min   = InpGuardFixedGmtOffsetMin;
   cfg.server_tz              = InpGuardServerTz;
   cfg.server_gmt_offset_min  = InpGuardServerGmtOffsetMin;
   cfg.server_dst_rule        = InpGuardServerDstRule;
   cfg.day_basis              = InpGuardDayBasis;
   cfg.daily_limit_base       = InpGuardDailyLimitBase;
   cfg.firm_daily_limit_pct   = InpGuardFirmDailyLimitPct;
   cfg.daily_lock_pct         = InpGuardDailyLockPct;
   cfg.floor_mode             = InpGuardFloorMode;
   cfg.floor_stop_at_initial  = InpGuardFloorStopAtInitial;
   cfg.firm_overall_limit_pct = InpGuardFirmOverallLimitPct;
   cfg.overall_lock_pct       = InpGuardOverallLockPct;
   cfg.target_pct             = InpGuardTargetPct;
   cfg.unlock_code            = InpGuardUnlockCode;
   cfg.risk_policy            = InpGuardRiskPolicy;
   cfg.risk_pct               = InpGuardRiskPct;
   cfg.slip_buffer_pct        = InpGuardSlipBufferPct;
   cfg.commission_per_lot_rt  = InpGuardCommissionPerLot;
   cfg.close_deviation_points = InpGuardCloseDeviationPts;
   cfg.close_retries          = InpGuardCloseRetries;
   cfg.close_retry_sleep_ms   = InpGuardCloseRetrySleepMs;
   cfg.timer_ms               = InpGuardTimerMs;
   cfg.timer_ms_tester        = InpGuardTimerMsTester;
   cfg.heartbeat_sec          = InpGuardHeartbeatSec;
   cfg.heartbeat_in_tester    = InpGuardHeartbeatInTester;
   cfg.journal                = InpGuardJournal;
   cfg.snapshot_grace_sec     = InpGuardSnapshotGraceSec;
   cfg.folder                 = "PropGuard";
   cfg.state_tag              = "";
   cfg.ea_name                = ea_name;
   cfg.ea_version             = ea_version;
  }

class CPropFirmGuard
  {
private:
   SGuardConfig      m_cfg;
   CTrade            m_exec;
   bool              m_ready;
   bool              m_tester;
   bool              m_hedging;
   long              m_login;
   string            m_state_file;
   string            m_heartbeat_file;
   string            m_journal_file;
   string            m_gv_prefix;
   double            m_initial;
   double            m_hwm_equity;
   double            m_hwm_balance;
   long              m_day_key;
   datetime          m_day_start;
   double            m_day_ref;
   double            m_day_ref_balance;
   double            m_day_ref_equity;
   bool              m_day_reconstructed;
   long              m_daily_lock_key;
   bool              m_overall_locked;
   bool              m_target_locked;
   int               m_entries_today;
   bool              m_fault_state;
   bool              m_fault_initial;
   bool              m_fault_io;
   bool              m_fault_history;
   int               m_heartbeat_failures;
   bool              m_liquidation_pending;
   bool              m_unbounded_position;
   string            m_note;
   datetime          m_note_time;
   string            m_refusal;
   bool              m_dirty;
   ulong             m_last_persist_ms;
   ulong             m_last_sweep_ms;
   datetime          m_last_heartbeat;
   double            m_balance;
   double            m_equity;
   double            m_closing_commission;
   double            m_equity_adj;
   int               m_positions_in_scope;
   double            m_shield_spread;
   bool              m_shield_news;
   bool              m_shield_attached;
   string            m_intent_symbol;
   bool              m_intent_buy;
   double            m_intent_price;
   double            m_intent_sl;
   double            m_intent_risk;
   double            m_intent_spread_pts;
   datetime          m_intent_time;
   int               m_rollovers_timer;
   int               m_rollovers_tick;

   void              ResetMembers(void);
   bool              ValidateConfig(string &why) const;
   void              SetNote(const string text);
   ulong             ThrottleMs(void) const;
   bool              HeartbeatEnabled(void) const;
   bool              PositionInScope(void) const;
   bool              OrderInScope(void) const;
   bool              DealInScope(const ulong deal) const;
   void              RefreshAccount(void);
   double            LimitBase(void) const;
   double            BasisRef(const double balance_ref, const double equity_ref) const;
   double            DailyLossSigned(void) const;
   double            DailyLockAmount(void) const;
   bool              AnyLock(void) const;
   void              Latch(const string kind, const string why);
   void              Evaluate(void);
   void              Housekeeping(const bool from_timer);
   void              CheckRollover(const bool from_timer);
   bool              ReconstructDayRef(const datetime start, double &balance_ref, double &equity_ref, bool &approx);
   void              FloatingAtStart(const string symbol, const bool is_buy, const double volume, const double open_price, const datetime start, double &float_close, double &float_open) const;
   int               CountEntriesSince(const datetime start);
   bool              HistoryHasTradeDeals(void);
   double            FirstDepositFromHistory(void);
   double            MaxBalanceFromHistory(void);
   bool              ReplayDailyLock(const datetime start, const double day_ref, const double lock_amount);
   bool              PositionOpeningDeal(const ulong position_id, double &price, double &sl, double &volume, double &commission, bool &is_buy, datetime &first_in);
   double            RiskFromStop(const string symbol, const bool is_buy, const double entry, const double sl, const double volume) const;
   void              OpenWorstCase(double &extra, bool &unbounded);
   bool              DeletePendingInScope(void);
   bool              LoadFile(SGuardState &st);
   bool              LoadMirror(SGuardState &st);
   bool              WriteMirror(void);
   bool              AtomicWrite(const string path, const string content) const;
   void              JournalDeal(const ulong deal);
   void              AppendJournal(const string row);
   bool              IntentMatches(const string symbol, const bool is_buy, const datetime when) const;
   double            OverallDdPct(void) const;
   bool              TradeAllowed(void) const;
   string            BasisName(void) const;
   double            Refuse(const string why);
   int               ClockOffsetAtGmt(const datetime gmt) const;
   datetime          ClockFromServer(const datetime server_time) const;
   datetime          ServerFromClock(const datetime clock_time) const;
   int               MeasuredServerOffset(void) const;
   static double     DealAmount(const ulong deal);
   static uint       Fnv1a(const string text);
   static string     JsonStr(const string key, const string value);
   static string     JsonNum(const string key, const double value, const int digits);
   static string     JsonInt(const string key, const long value);
   static string     JsonBool(const string key, const bool value);

public:
                     CPropFirmGuard(void);
                    ~CPropFirmGuard(void);
   bool              Init(const SGuardConfig &cfg);
   void              ConfigureClock(const SGuardConfig &cfg);
   void              Deinit(const int reason);
   void              OnTick(void);
   void              OnTimer(void);
   void              OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
   double            CanOpen(const string symbol, const ENUM_ORDER_TYPE type, const double entry_price, const double sl_price, const double requested_lots);
   double            RiskBudgetPct(void);
   bool              EntriesBlocked(string &reason);
   bool              CloseAllInScope(const string why);
   bool              CloseTicket(const ulong ticket, const string why);
   bool              ClosePartial(const ulong ticket, const double volume, const string why);
   double            WorstCaseLossPerLot(const string symbol, const bool is_buy, const double entry, const double sl) const;
   void              NoteIntent(const string symbol, const bool is_buy, const double price, const double sl, const double planned_risk);
   bool              IntentFor(const string symbol, const bool is_buy, const datetime when, double &price, double &sl, double &planned_risk) const;
   void              SetShieldStatus(const double spread, const bool news_blackout);
   bool              Persist(void);
   bool              WriteHeartbeat(void);
   string            LockState(void) const;
   string            LastError(void) const;
   double            FirmFloor(void) const;
   double            OurFloor(void) const;
   double            DailyLossPct(void) const;
   long              FirmDayKeyAt(const datetime server_time) const;
   datetime          FirmDayStartAt(const datetime server_time) const;
   int               ServerOffsetAtGmt(const datetime gmt) const;
   datetime          GmtFromServer(const datetime server_time) const;
   datetime          ServerFromGmt(const datetime gmt) const;
   datetime          NewYorkFromServer(const datetime server_time) const;
   datetime          GmtNow(void) const;
   string            LastRefusal(void) const { return m_refusal; }
   bool              IsReady(void) const { return m_ready; }
   bool              IsFault(void) const { return m_fault_state || m_fault_initial || m_fault_io || m_fault_history || m_heartbeat_failures >= 3; }
   bool              StateFault(void) const { return m_fault_state; }
   bool              DailyLocked(void) const { return m_daily_lock_key != 0 && m_daily_lock_key == m_day_key; }
   bool              IsReconstructed(void) const { return m_day_reconstructed; }
   double            InitialBalance(void) const { return m_initial; }
   double            HighWaterMark(void) const { return m_hwm_equity; }
   double            DayRef(void) const { return m_day_ref; }
   long              DayKey(void) const { return m_day_key; }
   datetime          DayStart(void) const { return m_day_start; }
   int               EntriesToday(void) const { return m_entries_today; }
   int               PositionsInScope(void) const { return m_positions_in_scope; }
   double            EquityAdjusted(void) const { return m_equity_adj; }
   double            ClosingCommissionEstimate(void) const { return m_closing_commission; }
   int               RolloversFromTimer(void) const { return m_rollovers_timer; }
   int               RolloversFromTick(void) const { return m_rollovers_tick; }
   string            StateFilePath(void) const { return m_state_file; }
   string            HeartbeatFilePath(void) const { return m_heartbeat_file; }
   string            JournalFilePath(void) const { return m_journal_file; }
   string            MirrorPrefix(void) const { return m_gv_prefix; }
   static double     CppiRiskPct(const double base_risk_pct, const double lock_pct, const double equity, const double floor, const double initial);
   static bool       IsEuDst(const datetime gmt);
   static bool       IsUsDst(const datetime gmt);
   static datetime   NthSunday(const int year, const int month, const int n);
   static datetime   LastSunday(const int year, const int month);
   static string     IsoTime(const datetime value, const bool zulu);
   static string     JsonEscape(const string text);
   static int        VolumeDigits(const double step);
  };

CPropFirmGuard::CPropFirmGuard(void)
  {
   ResetMembers();
  }

CPropFirmGuard::~CPropFirmGuard(void)
  {
  }

void CPropFirmGuard::ResetMembers(void)
  {
   m_ready = false;
   m_tester = false;
   m_hedging = false;
   m_login = 0;
   m_state_file = "";
   m_heartbeat_file = "";
   m_journal_file = "";
   m_gv_prefix = "";
   m_initial = 0.0;
   m_hwm_equity = 0.0;
   m_hwm_balance = 0.0;
   m_day_key = 0;
   m_day_start = 0;
   m_day_ref = 0.0;
   m_day_ref_balance = 0.0;
   m_day_ref_equity = 0.0;
   m_day_reconstructed = false;
   m_daily_lock_key = 0;
   m_overall_locked = false;
   m_target_locked = false;
   m_entries_today = 0;
   m_fault_state = false;
   m_fault_initial = false;
   m_fault_io = false;
   m_fault_history = false;
   m_heartbeat_failures = 0;
   m_liquidation_pending = false;
   m_unbounded_position = false;
   m_note = "";
   m_note_time = 0;
   m_refusal = "";
   m_dirty = false;
   m_last_persist_ms = 0;
   m_last_sweep_ms = 0;
   m_last_heartbeat = 0;
   m_balance = 0.0;
   m_equity = 0.0;
   m_closing_commission = 0.0;
   m_equity_adj = 0.0;
   m_positions_in_scope = 0;
   m_shield_spread = 0.0;
   m_shield_news = false;
   m_shield_attached = false;
   m_intent_symbol = "";
   m_intent_buy = true;
   m_intent_price = 0.0;
   m_intent_sl = 0.0;
   m_intent_risk = 0.0;
   m_intent_spread_pts = 0.0;
   m_intent_time = 0;
   m_rollovers_timer = 0;
   m_rollovers_tick = 0;
  }

bool CPropFirmGuard::ValidateConfig(string &why) const
  {
   why = "";
   if(m_cfg.symbol == "")
      why = "symbol is empty";
   else if(m_cfg.firm_daily_limit_pct <= 0.0 || m_cfg.daily_lock_pct <= 0.0 || m_cfg.daily_lock_pct > m_cfg.firm_daily_limit_pct)
      why = "daily lock must be positive and not above the firm daily limit";
   else if(m_cfg.firm_overall_limit_pct <= 0.0 || m_cfg.overall_lock_pct <= 0.0 || m_cfg.overall_lock_pct > m_cfg.firm_overall_limit_pct)
      why = "overall lock must be positive and not above the firm overall limit";
   else if(m_cfg.day_reset_hour < 0 || m_cfg.day_reset_hour > 23 || m_cfg.day_reset_minute < 0 || m_cfg.day_reset_minute > 59)
      why = "reset hour or minute out of range";
   else if(m_cfg.risk_pct < 0.0 || m_cfg.slip_buffer_pct < 0.0 || m_cfg.commission_per_lot_rt < 0.0 || m_cfg.target_pct < 0.0)
      why = "risk, buffer, commission and target must not be negative";
   else if(m_cfg.heartbeat_sec < 1 || m_cfg.timer_ms < 10 || m_cfg.timer_ms_tester < 10)
      why = "heartbeat or timer period too small";
   else if(m_cfg.folder == "")
      why = "folder is empty";
   return why == "";
  }

void CPropFirmGuard::SetNote(const string text)
  {
   m_note = text;
   m_note_time = TimeTradeServer();
   PrintFormat("PropFirmGuard: %s", text);
  }

ulong CPropFirmGuard::ThrottleMs(void) const
  {
   if(m_tester)
      return (ulong)TimeCurrent() * 1000;
   return GetTickCount64();
  }

bool CPropFirmGuard::HeartbeatEnabled(void) const
  {
   return !m_tester || m_cfg.heartbeat_in_tester;
  }

bool CPropFirmGuard::PositionInScope(void) const
  {
   if(m_cfg.scope == GUARD_SCOPE_ACCOUNT)
      return true;
   return (ulong)PositionGetInteger(POSITION_MAGIC) == m_cfg.magic && PositionGetString(POSITION_SYMBOL) == m_cfg.symbol;
  }

bool CPropFirmGuard::OrderInScope(void) const
  {
   if(m_cfg.scope == GUARD_SCOPE_ACCOUNT)
      return true;
   return (ulong)OrderGetInteger(ORDER_MAGIC) == m_cfg.magic && OrderGetString(ORDER_SYMBOL) == m_cfg.symbol;
  }

bool CPropFirmGuard::DealInScope(const ulong deal) const
  {
   if(m_cfg.scope == GUARD_SCOPE_ACCOUNT)
      return true;
   return (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) == m_cfg.magic && HistoryDealGetString(deal, DEAL_SYMBOL) == m_cfg.symbol;
  }

void CPropFirmGuard::RefreshAccount(void)
  {
   m_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double commission = 0.0;
   int in_scope = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      commission += PositionGetDouble(POSITION_VOLUME) * m_cfg.commission_per_lot_rt * 0.5;
      if(PositionInScope())
         in_scope++;
     }
   m_closing_commission = commission;
   m_equity_adj = m_equity - commission;
   m_positions_in_scope = in_scope;
  }

double CPropFirmGuard::LimitBase(void) const
  {
   if(m_cfg.daily_limit_base == GUARD_BASE_INITIAL)
      return m_initial;
   return m_day_ref;
  }

double CPropFirmGuard::BasisRef(const double balance_ref, const double equity_ref) const
  {
   if(m_cfg.day_basis == GUARD_BASIS_BALANCE)
      return balance_ref;
   if(m_cfg.day_basis == GUARD_BASIS_EQUITY)
      return equity_ref;
   return MathMax(balance_ref, equity_ref);
  }

double CPropFirmGuard::DailyLossSigned(void) const
  {
   return m_day_ref - m_equity_adj;
  }

double CPropFirmGuard::DailyLockAmount(void) const
  {
   return m_cfg.daily_lock_pct / 100.0 * LimitBase();
  }

double CPropFirmGuard::DailyLossPct(void) const
  {
   double base = LimitBase();
   if(base <= 0.0)
      return 0.0;
   return MathMax(0.0, DailyLossSigned()) / base * 100.0;
  }

bool CPropFirmGuard::AnyLock(void) const
  {
   return m_overall_locked || m_target_locked || DailyLocked();
  }

double CPropFirmGuard::FirmFloor(void) const
  {
   double limit = m_cfg.firm_overall_limit_pct / 100.0 * m_initial;
   double floor = m_initial - limit;
   if(m_cfg.floor_mode == GUARD_FLOOR_TRAIL_EQUITY)
      floor = m_hwm_equity - limit;
   else if(m_cfg.floor_mode == GUARD_FLOOR_TRAIL_BALANCE)
      floor = m_hwm_balance - limit;
   if(m_cfg.floor_mode != GUARD_FLOOR_STATIC && m_cfg.floor_stop_at_initial)
      floor = MathMin(floor, m_initial);
   return floor;
  }

double CPropFirmGuard::OurFloor(void) const
  {
   return FirmFloor() + (m_cfg.firm_overall_limit_pct - m_cfg.overall_lock_pct) / 100.0 * m_initial;
  }

double CPropFirmGuard::OverallDdPct(void) const
  {
   if(m_initial <= 0.0)
      return 0.0;
   double headroom_pct = (m_equity_adj - FirmFloor()) / m_initial * 100.0;
   return MathMax(0.0, m_cfg.firm_overall_limit_pct - headroom_pct);
  }

bool CPropFirmGuard::TradeAllowed(void) const
  {
   return TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0
          && MQLInfoInteger(MQL_TRADE_ALLOWED) != 0
          && AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0
          && AccountInfoInteger(ACCOUNT_TRADE_EXPERT) != 0;
  }

string CPropFirmGuard::BasisName(void) const
  {
   if(m_cfg.day_basis == GUARD_BASIS_BALANCE)
      return "BALANCE";
   if(m_cfg.day_basis == GUARD_BASIS_EQUITY)
      return "EQUITY";
   return "MAX";
  }

string CPropFirmGuard::LockState(void) const
  {
   if(m_overall_locked)
      return "OVERALL";
   if(m_target_locked)
      return "TARGET";
   if(DailyLocked())
      return "DAILY";
   return "NONE";
  }

string CPropFirmGuard::LastError(void) const
  {
   string text = "";
   if(m_fault_state)
      text += "state missing or corrupt with trade history, change InpGuardUnlockCode to acknowledge; ";
   if(m_fault_initial)
      text += "initial balance unknown, set InpGuardInitialBalance; ";
   if(m_fault_io)
      text += "state file write failed; ";
   if(m_fault_history)
      text += "deal history unavailable for day reference; ";
   if(m_heartbeat_failures >= 3)
      text += "heartbeat write failing; ";
   if(m_liquidation_pending)
      text += "liquidation pending; ";
   if(m_unbounded_position)
      text += "open position without stop loss; ";
   if(m_note != "" && (long)TimeTradeServer() - (long)m_note_time < 3600)
      text += m_note + "; ";
   if(StringLen(text) >= 2)
      text = StringSubstr(text, 0, StringLen(text) - 2);
   return text;
  }

double CPropFirmGuard::Refuse(const string why)
  {
   m_refusal = why;
   return 0.0;
  }

bool CPropFirmGuard::Init(const SGuardConfig &cfg)
  {
   ResetMembers();
   m_cfg = cfg;
   m_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   string why = "";
   if(!ValidateConfig(why))
     {
      m_refusal = why;
      PrintFormat("PropFirmGuard: invalid configuration: %s", why);
      return false;
     }
   m_login = AccountInfoInteger(ACCOUNT_LOGIN);
   m_hedging = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   string suffix = IntegerToString(m_login);
   if(m_cfg.state_tag != "")
      suffix += "_" + m_cfg.state_tag;
   if(m_cfg.scope == GUARD_SCOPE_MAGIC)
      suffix += "_" + IntegerToString((long)m_cfg.magic);
   m_state_file = m_cfg.folder + "\\state_" + suffix + ".txt";
   m_heartbeat_file = m_cfg.folder + "\\heartbeat_" + IntegerToString(m_login) + ".json";
   m_journal_file = m_cfg.folder + "\\journal_" + IntegerToString(m_login) + ".csv";
   m_gv_prefix = "PG." + suffix + ".";
   FolderCreate(m_cfg.folder);

   m_exec.SetExpertMagicNumber(m_cfg.magic);
   m_exec.SetDeviationInPoints((ulong)(m_cfg.close_deviation_points < 0 ? 0 : m_cfg.close_deviation_points));
   m_exec.SetMarginMode();
   m_exec.SetTypeFillingBySymbol(m_cfg.symbol);
   m_exec.LogLevel(LOG_LEVEL_ERRORS);
   RefreshAccount();

   SGuardState fs;
   SGuardState gs;
   SGuardState st;
   ZeroMemory(fs);
   ZeroMemory(gs);
   ZeroMemory(st);
   bool file_ok = LoadFile(fs);
   bool mirror_ok = LoadMirror(gs);
   bool history = HistoryHasTradeDeals();
   bool have = false;
   if(file_ok)
     {
      st = fs;
      have = true;
      if(mirror_ok && gs.unlock_code == fs.unlock_code)
        {
         st.hwm_equity = MathMax(st.hwm_equity, gs.hwm_equity);
         st.hwm_balance = MathMax(st.hwm_balance, gs.hwm_balance);
         if(gs.overall_locked != 0)
            st.overall_locked = 1;
         if(gs.target_locked != 0)
            st.target_locked = 1;
         if(gs.fault_state != 0)
            st.fault_state = 1;
         if(gs.daily_lock_key > st.daily_lock_key)
            st.daily_lock_key = gs.daily_lock_key;
         if(gs.day_key == st.day_key)
           {
            st.day_ref = MathMax(st.day_ref, gs.day_ref);
            st.day_ref_balance = MathMax(st.day_ref_balance, gs.day_ref_balance);
            st.day_ref_equity = MathMax(st.day_ref_equity, gs.day_ref_equity);
            if(gs.entries_today > st.entries_today)
               st.entries_today = gs.entries_today;
           }
        }
     }
   else if(mirror_ok)
     {
      st = gs;
      have = true;
      SetNote("state file missing or corrupt, restored from global-variable mirror");
     }

   if(have)
     {
      m_fault_state = (st.fault_state != 0);
      m_overall_locked = (st.overall_locked != 0);
      m_target_locked = (st.target_locked != 0);
      m_daily_lock_key = st.daily_lock_key;
      if(m_cfg.unlock_code != st.unlock_code)
        {
         PrintFormat("PropFirmGuard: unlock code changed %d -> %d, clearing overall, target and state-fault locks", st.unlock_code, m_cfg.unlock_code);
         m_overall_locked = false;
         m_target_locked = false;
         m_fault_state = false;
        }
     }
   else if(history)
      m_fault_state = true;

   if(m_cfg.initial_balance > 0.0)
     {
      m_initial = m_cfg.initial_balance;
      if(have && st.initial > 0.0 && MathAbs(st.initial - m_initial) > 0.005)
         SetNote(StringFormat("initial balance input %.2f replaces persisted %.2f", m_initial, st.initial));
     }
   else if(have && st.initial > 0.0)
      m_initial = st.initial;
   else
     {
      m_initial = FirstDepositFromHistory();
      if(m_initial <= 0.0)
        {
         if(history)
            m_fault_initial = true;
         m_initial = m_balance;
        }
     }

   double history_peak = MaxBalanceFromHistory();
   double persisted_hwm_equity = have ? st.hwm_equity : 0.0;
   double persisted_hwm_balance = have ? st.hwm_balance : 0.0;
   m_hwm_equity = MathMax(MathMax(persisted_hwm_equity, m_initial), MathMax(m_equity, history_peak));
   m_hwm_balance = MathMax(MathMax(persisted_hwm_balance, m_initial), MathMax(m_balance, history_peak));

   datetime now = TimeTradeServer();
   long key = FirmDayKeyAt(now);
   datetime start = FirmDayStartAt(now);
   double balance_ref = 0.0;
   double equity_ref = 0.0;
   bool approx = false;
   bool reconstructed_ok = ReconstructDayRef(start, balance_ref, equity_ref, approx);
   m_day_key = key;
   m_day_start = start;
   if(have && st.day_key == key)
     {
      m_day_ref_balance = reconstructed_ok ? MathMax(st.day_ref_balance, balance_ref) : st.day_ref_balance;
      m_day_ref_equity = st.day_ref_equity;
      m_day_ref = MathMax(st.day_ref, BasisRef(m_day_ref_balance, m_day_ref_equity));
      m_day_reconstructed = (st.day_reconstructed != 0);
      m_entries_today = st.entries_today;
     }
   else if(reconstructed_ok)
     {
      bool prompt = ((long)now - (long)start) <= (long)m_cfg.snapshot_grace_sec;
      m_day_ref_balance = balance_ref;
      m_day_ref_equity = prompt ? m_equity : equity_ref;
      m_day_ref = BasisRef(m_day_ref_balance, m_day_ref_equity);
      m_day_reconstructed = !prompt;
      m_entries_today = 0;
     }
   else
     {
      m_fault_history = true;
      m_day_ref_balance = m_balance;
      m_day_ref_equity = m_equity;
      m_day_ref = BasisRef(m_balance, m_equity);
      m_day_reconstructed = true;
     }
   if(reconstructed_ok)
     {
      int counted = CountEntriesSince(start);
      if(counted > m_entries_today)
         m_entries_today = counted;
      if(!have && ReplayDailyLock(start, m_day_ref_balance, DailyLockAmount()))
         m_daily_lock_key = key;
     }

   int period = m_tester ? m_cfg.timer_ms_tester : m_cfg.timer_ms;
   if(!EventSetMillisecondTimer(period))
      SetNote("timer unavailable, rollover runs on ticks only");
   m_ready = true;
   Evaluate();
   Persist();
   if(HeartbeatEnabled())
      WriteHeartbeat();
   PrintFormat("PropFirmGuard: ready login=%I64d initial=%.2f hwm=%.2f day_key=%I64d day_ref=%.2f reconstructed=%s lock=%s fault=%s",
               m_login, m_initial, m_hwm_equity, m_day_key, m_day_ref, m_day_reconstructed ? "yes" : "no", LockState(), IsFault() ? LastError() : "none");
   return true;
  }

void CPropFirmGuard::ConfigureClock(const SGuardConfig &cfg)
  {
   m_cfg = cfg;
   m_tester = (MQLInfoInteger(MQL_TESTER) != 0);
  }

void CPropFirmGuard::Deinit(const int reason)
  {
   if(!m_ready)
      return;
   Evaluate();
   Persist();
   if(HeartbeatEnabled())
      WriteHeartbeat();
   EventKillTimer();
   m_ready = false;
   PrintFormat("PropFirmGuard: stopped, reason %d, lock %s", reason, LockState());
  }

void CPropFirmGuard::OnTick(void)
  {
   Housekeeping(false);
  }

void CPropFirmGuard::OnTimer(void)
  {
   Housekeeping(true);
  }

void CPropFirmGuard::Housekeeping(const bool from_timer)
  {
   if(!m_ready)
      return;
   CheckRollover(from_timer);
   Evaluate();
   if(HeartbeatEnabled() && (long)TimeTradeServer() - (long)m_last_heartbeat >= (long)m_cfg.heartbeat_sec)
      WriteHeartbeat();
  }

void CPropFirmGuard::CheckRollover(const bool from_timer)
  {
   datetime now = TimeTradeServer();
   long key = FirmDayKeyAt(now);
   if(key == m_day_key && !m_fault_history)
      return;
   datetime start = FirmDayStartAt(now);
   double balance_ref = 0.0;
   double equity_ref = 0.0;
   bool approx = false;
   if(!ReconstructDayRef(start, balance_ref, equity_ref, approx))
     {
      m_fault_history = true;
      return;
     }
   bool recovered = m_fault_history;
   m_fault_history = false;
   if(key == m_day_key)
     {
      if(recovered)
        {
         m_day_ref_balance = MathMax(m_day_ref_balance, balance_ref);
         m_day_ref_equity = MathMax(m_day_ref_equity, equity_ref);
         m_day_ref = MathMax(m_day_ref, BasisRef(m_day_ref_balance, m_day_ref_equity));
         Persist();
        }
      return;
     }
   RefreshAccount();
   bool prompt = ((long)now - (long)start) <= (long)m_cfg.snapshot_grace_sec;
   m_day_key = key;
   m_day_start = start;
   m_day_ref_balance = balance_ref;
   m_day_ref_equity = prompt ? m_equity : equity_ref;
   m_day_ref = BasisRef(m_day_ref_balance, m_day_ref_equity);
   m_day_reconstructed = !prompt;
   m_entries_today = CountEntriesSince(start);
   if(from_timer)
      m_rollovers_timer++;
   else
      m_rollovers_tick++;
   PrintFormat("PropFirmGuard: firm day %I64d started %s server, day_ref %.2f (%s, %s)",
               m_day_key, TimeToString(m_day_start, TIME_DATE | TIME_SECONDS), m_day_ref, BasisName(), prompt ? "snapshot" : "reconstructed");
   Persist();
  }

bool CPropFirmGuard::ReconstructDayRef(const datetime start, double &balance_ref, double &equity_ref, bool &approx)
  {
   approx = false;
   RefreshAccount();
   datetime until = (datetime)((long)TimeTradeServer() + 86400);
   if(!HistorySelect(start, until))
      return false;
   double net = 0.0;
   ulong out_position[];
   double out_volume[];
   string out_symbol[];
   int outs = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((datetime)HistoryDealGetInteger(deal, DEAL_TIME) < start)
         continue;
      long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type == DEAL_TYPE_CREDIT)
         continue;
      double amount = DealAmount(deal);
      if((type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_BONUS) && amount > 0.0)
         continue;
      net += amount;
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if((type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) && (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT))
        {
         ArrayResize(out_position, outs + 1);
         ArrayResize(out_volume, outs + 1);
         ArrayResize(out_symbol, outs + 1);
         out_position[outs] = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
         out_volume[outs] = HistoryDealGetDouble(deal, DEAL_VOLUME);
         out_symbol[outs] = HistoryDealGetString(deal, DEAL_SYMBOL);
         outs++;
        }
     }
   balance_ref = m_balance - net;

   double float_close = 0.0;
   double float_open = 0.0;
   for(int p = PositionsTotal() - 1; p >= 0; p--)
     {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0)
         continue;
      if((datetime)PositionGetInteger(POSITION_TIME) >= start)
         continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double fc = 0.0;
      double fo = 0.0;
      FloatingAtStart(symbol, is_buy, volume, open_price, start, fc, fo);
      float_close += fc;
      float_open += fo;
      approx = true;
     }
   for(int k = 0; k < outs; k++)
     {
      double in_price = 0.0;
      double in_sl = 0.0;
      double in_volume = 0.0;
      double in_commission = 0.0;
      bool in_buy = true;
      datetime first_in = 0;
      if(!PositionOpeningDeal(out_position[k], in_price, in_sl, in_volume, in_commission, in_buy, first_in))
         continue;
      if(first_in == 0 || first_in >= start)
         continue;
      double fc = 0.0;
      double fo = 0.0;
      FloatingAtStart(out_symbol[k], in_buy, out_volume[k], in_price, start, fc, fo);
      float_close += fc;
      float_open += fo;
      approx = true;
     }
   equity_ref = balance_ref + MathMax(float_close, float_open);
   return true;
  }

void CPropFirmGuard::FloatingAtStart(const string symbol, const bool is_buy, const double volume, const double open_price, const datetime start, double &float_close, double &float_open) const
  {
   float_close = 0.0;
   float_open = 0.0;
   double fallback = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price_close = fallback;
   double price_open = fallback;
   int shift_before = iBarShift(symbol, PERIOD_M1, (datetime)((long)start - 1), false);
   if(shift_before >= 0)
     {
      double c = iClose(symbol, PERIOD_M1, shift_before);
      if(c > 0.0)
         price_close = c;
     }
   int shift_at = iBarShift(symbol, PERIOD_M1, start, false);
   if(shift_at >= 0)
     {
      double o = iOpen(symbol, PERIOD_M1, shift_at);
      if(o > 0.0)
         price_open = o;
     }
   ENUM_ORDER_TYPE type = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double profit = 0.0;
   if(OrderCalcProfit(type, symbol, volume, open_price, price_close, profit))
      float_close = profit;
   profit = 0.0;
   if(OrderCalcProfit(type, symbol, volume, open_price, price_open, profit))
      float_open = profit;
  }

int CPropFirmGuard::CountEntriesSince(const datetime start)
  {
   datetime until = (datetime)((long)TimeTradeServer() + 86400);
   if(!HistorySelect(start, until))
      return 0;
   int count = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((datetime)HistoryDealGetInteger(deal, DEAL_TIME) < start)
         continue;
      long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      if(DealInScope(deal))
         count++;
     }
   return count;
  }

bool CPropFirmGuard::HistoryHasTradeDeals(void)
  {
   datetime until = (datetime)((long)TimeTradeServer() + 86400);
   if(!HistorySelect(0, until))
      return true;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL)
         return true;
     }
   return false;
  }

double CPropFirmGuard::FirstDepositFromHistory(void)
  {
   datetime until = (datetime)((long)TimeTradeServer() + 86400);
   if(!HistorySelect(0, until))
      return 0.0;
   datetime first_time = 0;
   double first_amount = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_TYPE) != DEAL_TYPE_BALANCE)
         continue;
      double amount = HistoryDealGetDouble(deal, DEAL_PROFIT);
      if(amount <= 0.0)
         continue;
      datetime t = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(first_time == 0 || t < first_time)
        {
         first_time = t;
         first_amount = amount;
        }
     }
   return first_amount;
  }

double CPropFirmGuard::MaxBalanceFromHistory(void)
  {
   datetime until = (datetime)((long)TimeTradeServer() + 86400);
   if(!HistorySelect(0, until))
      return 0.0;
   double running = 0.0;
   double peak = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_CREDIT)
         continue;
      running += DealAmount(deal);
      if(running > peak)
         peak = running;
     }
   return peak;
  }

bool CPropFirmGuard::ReplayDailyLock(const datetime start, const double day_ref, const double lock_amount)
  {
   if(lock_amount <= 0.0)
      return false;
   datetime until = (datetime)((long)TimeTradeServer() + 86400);
   if(!HistorySelect(start, until))
      return false;
   double running = m_day_ref_balance;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((datetime)HistoryDealGetInteger(deal, DEAL_TIME) < start)
         continue;
      long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type == DEAL_TYPE_CREDIT)
         continue;
      double amount = DealAmount(deal);
      if((type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_BONUS) && amount > 0.0)
         continue;
      running += amount;
      if(day_ref - running >= lock_amount)
         return true;
     }
   return false;
  }

bool CPropFirmGuard::PositionOpeningDeal(const ulong position_id, double &price, double &sl, double &volume, double &commission, bool &is_buy, datetime &first_in)
  {
   price = 0.0;
   sl = 0.0;
   volume = 0.0;
   commission = 0.0;
   is_buy = true;
   first_in = 0;
   if(position_id == 0 || !HistorySelectByPosition((long)position_id))
      return false;
   double weighted = 0.0;
   bool found = false;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      double v = HistoryDealGetDouble(deal, DEAL_VOLUME);
      datetime t = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(first_in == 0 || t < first_in)
         first_in = t;
      volume += v;
      weighted += v * HistoryDealGetDouble(deal, DEAL_PRICE);
      commission += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      if(!found)
        {
         sl = HistoryDealGetDouble(deal, DEAL_SL);
         is_buy = (HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_BUY);
         found = true;
        }
     }
   if(!found || volume <= 0.0)
      return false;
   price = weighted / volume;
   return true;
  }

double CPropFirmGuard::RiskFromStop(const string symbol, const bool is_buy, const double entry, const double sl, const double volume) const
  {
   if(sl <= 0.0 || entry <= 0.0 || volume <= 0.0)
      return 0.0;
   double profit = 0.0;
   if(!OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, symbol, volume, entry, sl, profit))
      return 0.0;
   return profit < 0.0 ? -profit : 0.0;
  }

double CPropFirmGuard::WorstCaseLossPerLot(const string symbol, const bool is_buy, const double entry, const double sl) const
  {
   if(entry <= 0.0 || sl <= 0.0)
      return 0.0;
   double loss = 0.0;
   double profit = 0.0;
   if(OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, symbol, 1.0, entry, sl, profit) && profit < 0.0)
      loss = -profit;
   else
     {
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tick_value <= 0.0)
         tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tick_size <= 0.0 || tick_value <= 0.0)
         return 0.0;
      loss = MathAbs(entry - sl) / tick_size * tick_value;
     }
   return loss * (1.0 + m_cfg.slip_buffer_pct / 100.0) + m_cfg.commission_per_lot_rt;
  }

void CPropFirmGuard::OpenWorstCase(double &extra, bool &unbounded)
  {
   extra = 0.0;
   unbounded = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0.0)
        {
         unbounded = true;
         continue;
        }
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double profit_now = PositionGetDouble(POSITION_PROFIT);
      double profit_sl = 0.0;
      if(!OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, symbol, volume, open_price, sl, profit_sl))
        {
         unbounded = true;
         continue;
        }
      double giveback = profit_now - profit_sl;
      if(giveback > 0.0)
         extra += giveback * (1.0 + m_cfg.slip_buffer_pct / 100.0);
     }
   m_unbounded_position = unbounded;
  }

void CPropFirmGuard::Evaluate(void)
  {
   if(!m_ready)
      return;
   RefreshAccount();
   if(m_equity > m_hwm_equity)
     {
      m_hwm_equity = m_equity;
      m_dirty = true;
     }
   if(m_balance > m_hwm_balance)
     {
      m_hwm_balance = m_balance;
      m_dirty = true;
     }
   if(!m_overall_locked && m_equity_adj <= OurFloor())
      Latch("OVERALL", StringFormat("equity %.2f at or below overall lock floor %.2f", m_equity_adj, OurFloor()));
   if(!DailyLocked() && m_day_ref > 0.0 && DailyLossSigned() >= DailyLockAmount())
      Latch("DAILY", StringFormat("daily loss %.2f reached lock amount %.2f", DailyLossSigned(), DailyLockAmount()));
   double target_level = m_initial * (1.0 + m_cfg.target_pct / 100.0);
   if(m_cfg.mode == GUARD_MODE_CHALLENGE && m_cfg.target_pct > 0.0 && !m_target_locked && m_equity_adj >= target_level)
      Latch("TARGET", StringFormat("equity %.2f reached target %.2f", m_equity_adj, target_level));
   if((AnyLock() || m_liquidation_pending) && ThrottleMs() - m_last_sweep_ms >= 1000)
      CloseAllInScope("sweep");
   if((m_dirty || m_fault_io) && GetTickCount64() - m_last_persist_ms >= 1000)
      Persist();
  }

void CPropFirmGuard::Latch(const string kind, const string why)
  {
   if(kind == "OVERALL")
      m_overall_locked = true;
   else if(kind == "DAILY")
      m_daily_lock_key = m_day_key;
   else if(kind == "TARGET")
      m_target_locked = true;
   PrintFormat("PropFirmGuard: %s lock engaged: %s", kind, why);
   Persist();
   CloseAllInScope(kind + " lock");
   if(HeartbeatEnabled())
      WriteHeartbeat();
  }

bool CPropFirmGuard::EntriesBlocked(string &reason)
  {
   reason = "";
   if(!m_ready)
      reason = "guard not initialized";
   else if(m_overall_locked)
      reason = "overall lock";
   else if(m_target_locked)
      reason = "target lock";
   else if(DailyLocked())
      reason = "daily lock";
   else if(m_fault_state)
      reason = "state fault";
   else if(m_fault_initial)
      reason = "initial balance unknown";
   else if(m_fault_io)
      reason = "state write failed";
   else if(m_fault_history)
      reason = "deal history unavailable";
   else if(m_heartbeat_failures >= 3)
      reason = "heartbeat write failing";
   else if(m_liquidation_pending)
      reason = "liquidation pending";
   return reason != "";
  }

double CPropFirmGuard::CanOpen(const string symbol, const ENUM_ORDER_TYPE type, const double entry_price, const double sl_price, const double requested_lots)
  {
   m_refusal = "";
   if(!m_ready)
      return Refuse("guard not initialized");
   Evaluate();
   string why = "";
   if(EntriesBlocked(why))
      return Refuse(why);
   bool is_buy = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT);
   if(entry_price <= 0.0 || sl_price <= 0.0)
      return Refuse("stop loss required");
   if((is_buy && sl_price >= entry_price) || (!is_buy && sl_price <= entry_price))
      return Refuse("stop loss on the wrong side of entry");
   if(requested_lots <= 0.0)
      return Refuse("no volume requested");
   double per_lot = WorstCaseLossPerLot(symbol, is_buy, entry_price, sl_price);
   if(per_lot <= 0.0)
      return Refuse("cannot value the stop distance");
   double extra = 0.0;
   bool unbounded = false;
   OpenWorstCase(extra, unbounded);
   if(unbounded)
      return Refuse("open position without stop loss");
   double daily_room = DailyLockAmount() - DailyLossSigned() - extra;
   double overall_room = (m_equity_adj - OurFloor()) - extra;
   double room = MathMin(daily_room, overall_room);
   if(room <= 0.0)
      return Refuse("no risk budget left");
   double lots = MathMin(requested_lots, room / per_lot);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(max_lot > 0.0)
      lots = MathMin(lots, max_lot);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0.0)
      return Refuse("volume step unknown");
   lots = MathFloor(lots / step + 1e-7) * step;
   if(lots < min_lot - 1e-9)
      return Refuse(StringFormat("allowed volume %.4f below min lot %.4f", lots, min_lot));
   lots = NormalizeDouble(lots, VolumeDigits(step));
   NoteIntent(symbol, is_buy, entry_price, sl_price, per_lot * lots);
   return lots;
  }

double CPropFirmGuard::RiskBudgetPct(void)
  {
   if(!m_ready)
      return 0.0;
   Evaluate();
   string why = "";
   if(EntriesBlocked(why))
      return 0.0;
   if(m_cfg.risk_policy == GUARD_RISK_FIXED)
      return m_cfg.risk_pct;
   return CppiRiskPct(m_cfg.risk_pct, m_cfg.overall_lock_pct, m_equity_adj, OurFloor(), m_initial);
  }

double CPropFirmGuard::CppiRiskPct(const double base_risk_pct, const double lock_pct, const double equity, const double floor, const double initial)
  {
   if(base_risk_pct <= 0.0 || lock_pct <= 0.0 || initial <= 0.0)
      return 0.0;
   double cushion = equity - floor;
   if(cushion <= 0.0)
      return 0.0;
   return MathMin(base_risk_pct, base_risk_pct * cushion / (lock_pct / 100.0 * initial));
  }

bool CPropFirmGuard::CloseAllInScope(const string why)
  {
   bool all_closed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionInScope())
         continue;
      if(!CloseTicket(ticket, why))
         all_closed = false;
     }
   if(!DeletePendingInScope())
      all_closed = false;
   m_liquidation_pending = !all_closed;
   m_last_sweep_ms = ThrottleMs();
   return all_closed;
  }

bool CPropFirmGuard::CloseTicket(const ulong ticket, const string why)
  {
   int attempts = m_cfg.close_retries < 1 ? 1 : m_cfg.close_retries;
   for(int attempt = 0; attempt < attempts; attempt++)
     {
      if(!PositionSelectByTicket(ticket))
         return true;
      string symbol = PositionGetString(POSITION_SYMBOL);
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      MqlTick tick;
      if(!SymbolInfoTick(symbol, tick))
        {
         Sleep(m_cfg.close_retry_sleep_ms);
         continue;
        }
      NoteIntent(symbol, !is_buy, is_buy ? tick.bid : tick.ask, 0.0, 0.0);
      m_exec.SetTypeFillingBySymbol(symbol);
      bool sent = m_exec.PositionClose(ticket, (ulong)(m_cfg.close_deviation_points < 0 ? 0 : m_cfg.close_deviation_points));
      uint rc = m_exec.ResultRetcode();
      if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED))
         return true;
      if(sent && rc == TRADE_RETCODE_DONE_PARTIAL)
         continue;
      if(rc == TRADE_RETCODE_POSITION_CLOSED)
         return true;
      if(rc == TRADE_RETCODE_MARKET_CLOSED || rc == TRADE_RETCODE_TRADE_DISABLED || rc == TRADE_RETCODE_SERVER_DISABLES_AT
         || rc == TRADE_RETCODE_CLIENT_DISABLES_AT || rc == TRADE_RETCODE_CONNECTION)
        {
         SetNote(StringFormat("close of %I64u deferred to next tick (%s): retcode %u", ticket, why, rc));
         return false;
        }
      PrintFormat("PropFirmGuard: close of %I64u attempt %d failed (%s): retcode %u %s", ticket, attempt + 1, why, rc, m_exec.ResultRetcodeDescription());
      Sleep(m_cfg.close_retry_sleep_ms);
     }
   return !PositionSelectByTicket(ticket);
  }

bool CPropFirmGuard::ClosePartial(const ulong ticket, const double volume, const string why)
  {
   int attempts = m_cfg.close_retries < 1 ? 1 : m_cfg.close_retries;
   for(int attempt = 0; attempt < attempts; attempt++)
     {
      if(!PositionSelectByTicket(ticket))
         return false;
      string symbol = PositionGetString(POSITION_SYMBOL);
      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double held = PositionGetDouble(POSITION_VOLUME);
      double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double cut = step > 0.0 ? NormalizeDouble(volume, VolumeDigits(step)) : volume;
      if(cut >= held - 1e-9)
         return CloseTicket(ticket, why);
      MqlTick tick;
      if(!SymbolInfoTick(symbol, tick))
        {
         Sleep(m_cfg.close_retry_sleep_ms);
         continue;
        }
      NoteIntent(symbol, !is_buy, is_buy ? tick.bid : tick.ask, 0.0, 0.0);
      m_exec.SetTypeFillingBySymbol(symbol);
      bool sent = false;
      if(m_hedging)
         sent = m_exec.PositionClosePartial(ticket, cut, (ulong)(m_cfg.close_deviation_points < 0 ? 0 : m_cfg.close_deviation_points));
      else if(is_buy)
         sent = m_exec.Sell(cut, symbol, 0.0, 0.0, 0.0, "guard reduce");
      else
         sent = m_exec.Buy(cut, symbol, 0.0, 0.0, 0.0, "guard reduce");
      uint rc = m_exec.ResultRetcode();
      if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
         return true;
      if(rc == TRADE_RETCODE_MARKET_CLOSED || rc == TRADE_RETCODE_TRADE_DISABLED || rc == TRADE_RETCODE_CONNECTION)
        {
         SetNote(StringFormat("partial close of %I64u deferred (%s): retcode %u", ticket, why, rc));
         return false;
        }
      PrintFormat("PropFirmGuard: partial close of %I64u attempt %d failed (%s): retcode %u %s", ticket, attempt + 1, why, rc, m_exec.ResultRetcodeDescription());
      Sleep(m_cfg.close_retry_sleep_ms);
     }
   return false;
  }

bool CPropFirmGuard::DeletePendingInScope(void)
  {
   bool ok = true;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderInScope())
         continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL || type == ORDER_TYPE_CLOSE_BY)
         continue;
      if(!m_exec.OrderDelete(ticket))
        {
         ok = false;
         PrintFormat("PropFirmGuard: delete of order %I64u failed: retcode %u", ticket, m_exec.ResultRetcode());
        }
     }
   return ok;
  }

void CPropFirmGuard::NoteIntent(const string symbol, const bool is_buy, const double price, const double sl, const double planned_risk)
  {
   m_intent_symbol = symbol;
   m_intent_buy = is_buy;
   m_intent_price = price;
   m_intent_sl = sl;
   m_intent_risk = planned_risk;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spread = SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
   m_intent_spread_pts = (point > 0.0) ? spread / point : 0.0;
   m_intent_time = TimeTradeServer();
  }

bool CPropFirmGuard::IntentMatches(const string symbol, const bool is_buy, const datetime when) const
  {
   if(m_intent_time == 0 || m_intent_symbol != symbol || m_intent_buy != is_buy)
      return false;
   long gap = (long)when - (long)m_intent_time;
   return gap >= -60 && gap <= 60;
  }

bool CPropFirmGuard::IntentFor(const string symbol, const bool is_buy, const datetime when, double &price, double &sl, double &planned_risk) const
  {
   if(!IntentMatches(symbol, is_buy, when))
      return false;
   price = m_intent_price;
   sl = m_intent_sl;
   planned_risk = m_intent_risk;
   return true;
  }

void CPropFirmGuard::SetShieldStatus(const double spread, const bool news_blackout)
  {
   m_shield_spread = spread;
   m_shield_news = news_blackout;
   m_shield_attached = true;
  }

void CPropFirmGuard::OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(!m_ready)
      return;
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
     {
      if(AnyLock())
         DeletePendingInScope();
      return;
     }
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.deal != 0 && HistoryDealSelect(trans.deal))
     {
      long type = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
      long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      datetime when = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
      ulong position = trans.position != 0 ? trans.position : (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      bool trade_deal = (type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL);
      if(trade_deal && DealInScope(trans.deal))
        {
         if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
           {
            if(AnyLock())
              {
               PrintFormat("PropFirmGuard: position %I64u opened while %s lock active, closing", position, LockState());
               if(!CloseTicket(position, "opened while locked"))
                  m_liquidation_pending = true;
              }
            else if(entry == DEAL_ENTRY_IN && when >= m_day_start)
              {
               m_entries_today++;
               m_dirty = true;
               Persist();
              }
           }
         if(m_cfg.journal)
            JournalDeal(trans.deal);
        }
     }
   Evaluate();
  }

void CPropFirmGuard::JournalDeal(const ulong deal)
  {
   if(!HistoryDealSelect(deal))
      return;
   datetime when = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
   string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
   long type = HistoryDealGetInteger(deal, DEAL_TYPE);
   long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   long reason = HistoryDealGetInteger(deal, DEAL_REASON);
   double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
   double fill = HistoryDealGetDouble(deal, DEAL_PRICE);
   double sl = HistoryDealGetDouble(deal, DEAL_SL);
   double tp = HistoryDealGetDouble(deal, DEAL_TP);
   long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
   ulong position_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   double net = DealAmount(deal);
   bool buy_deal = (type == DEAL_TYPE_BUY);
   bool opening = (entry == DEAL_ENTRY_IN);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   bool matched = IntentMatches(symbol, buy_deal, when);

   double intended = 0.0;
   bool have_intended = false;
   if(!opening && reason == DEAL_REASON_SL && sl > 0.0)
     {
      intended = sl;
      have_intended = true;
     }
   else if(!opening && reason == DEAL_REASON_TP && tp > 0.0)
     {
      intended = tp;
      have_intended = true;
     }
   else if(matched && m_intent_price > 0.0)
     {
      intended = m_intent_price;
      have_intended = true;
     }
   string intended_text = have_intended ? DoubleToString(intended, digits) : "";
   string slippage_text = "";
   if(have_intended && point > 0.0)
     {
      double slippage = buy_deal ? (fill - intended) / point : (intended - fill) / point;
      slippage_text = DoubleToString(slippage, 1);
     }

   string spread_text = "";
   string planned_text = "";
   string r_text = "";
   if(opening)
     {
      double spread_points = matched ? m_intent_spread_pts : 0.0;
      if(!matched && point > 0.0)
         spread_points = (SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) / point;
      spread_text = DoubleToString(spread_points, 1);
      double planned = 0.0;
      if(matched && m_intent_sl > 0.0 && m_intent_price > 0.0)
         planned = RiskFromStop(symbol, buy_deal, m_intent_price, m_intent_sl, volume);
      if(planned <= 0.0)
         planned = RiskFromStop(symbol, buy_deal, fill, sl, volume);
      planned_text = planned > 0.0 ? DoubleToString(planned, 2) : "";
     }
   else
     {
      double in_price = 0.0;
      double in_sl = 0.0;
      double in_volume = 0.0;
      double in_commission = 0.0;
      bool in_buy = true;
      datetime first_in = 0;
      double r_value = 0.0;
      if(PositionOpeningDeal(position_id, in_price, in_sl, in_volume, in_commission, in_buy, first_in))
        {
         double slice_risk = RiskFromStop(symbol, in_buy, in_price, in_sl, volume);
         double slice_net = net + in_commission * (volume / in_volume);
         if(slice_risk > 0.0)
           {
            r_value = slice_net / slice_risk;
            planned_text = DoubleToString(slice_risk, 2);
           }
         else
            SetNote(StringFormat("no initial stop for position %I64u, r_at_close written as 0", position_id));
        }
      r_text = DoubleToString(r_value, 4);
     }

   string row = IsoTime(when, false);
   row += "," + IntegerToString((long)deal);
   row += "," + symbol;
   row += "," + (buy_deal ? "BUY" : "SELL");
   row += "," + DoubleToString(volume, 2);
   row += "," + intended_text;
   row += "," + DoubleToString(fill, digits);
   row += "," + slippage_text;
   row += "," + (sl > 0.0 ? DoubleToString(sl, digits) : "");
   row += "," + spread_text;
   row += "," + planned_text;
   row += "," + IntegerToString(magic);
   row += "," + r_text;
   AppendJournal(row);
  }

void CPropFirmGuard::AppendJournal(const string row)
  {
   ResetLastError();
   int handle = FileOpen(m_journal_file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ, '\t', CP_UTF8);
   if(handle == INVALID_HANDLE)
     {
      SetNote(StringFormat("journal write failed, error %d", GetLastError()));
      return;
     }
   FileSeek(handle, 0, SEEK_END);
   if(FileSize(handle) == 0)
      FileWriteString(handle, GUARD_JOURNAL_HEADER + "\r\n");
   FileWriteString(handle, row + "\r\n");
   FileClose(handle);
  }

bool CPropFirmGuard::AtomicWrite(const string path, const string content) const
  {
   string temp = path + ".tmp";
   ResetLastError();
   int handle = FileOpen(temp, FILE_WRITE | FILE_TXT | FILE_ANSI, '\t', CP_UTF8);
   if(handle == INVALID_HANDLE)
      return false;
   uint written = FileWriteString(handle, content);
   FileFlush(handle);
   FileClose(handle);
   if(written == 0 && StringLen(content) > 0)
      return false;
   return FileMove(temp, 0, path, FILE_REWRITE);
  }

bool CPropFirmGuard::Persist(void)
  {
   if(m_login == 0 || m_state_file == "")
      return false;
   string body = "schema=1";
   body += ";login=" + IntegerToString(m_login);
   body += ";initial=" + DoubleToString(m_initial, 2);
   body += ";hwm_equity=" + DoubleToString(m_hwm_equity, 2);
   body += ";hwm_balance=" + DoubleToString(m_hwm_balance, 2);
   body += ";day_key=" + IntegerToString(m_day_key);
   body += ";day_start=" + IntegerToString((long)m_day_start);
   body += ";day_ref=" + DoubleToString(m_day_ref, 2);
   body += ";day_ref_balance=" + DoubleToString(m_day_ref_balance, 2);
   body += ";day_ref_equity=" + DoubleToString(m_day_ref_equity, 2);
   body += ";day_reconstructed=" + (m_day_reconstructed ? "1" : "0");
   body += ";daily_lock_key=" + IntegerToString(m_daily_lock_key);
   body += ";overall_locked=" + (m_overall_locked ? "1" : "0");
   body += ";target_locked=" + (m_target_locked ? "1" : "0");
   body += ";unlock_code=" + IntegerToString(m_cfg.unlock_code);
   body += ";entries_today=" + IntegerToString(m_entries_today);
   body += ";fault_state=" + (m_fault_state ? "1" : "0");
   string content = body + ";crc=" + IntegerToString((long)Fnv1a(body));
   bool mirror_ok = WriteMirror();
   bool file_ok = AtomicWrite(m_state_file, content);
   m_last_persist_ms = GetTickCount64();
   if(!file_ok)
     {
      if(!m_fault_io)
         PrintFormat("PropFirmGuard: state write failed for %s, error %d", m_state_file, GetLastError());
      m_fault_io = true;
      return false;
     }
   m_fault_io = false;
   m_dirty = false;
   if(!mirror_ok)
      SetNote("global-variable mirror write failed");
   return true;
  }

bool CPropFirmGuard::WriteMirror(void)
  {
   bool ok = true;
   if(GlobalVariableSet(m_gv_prefix + "initial", m_initial) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "hwm_equity", m_hwm_equity) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "hwm_balance", m_hwm_balance) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "day_key", (double)m_day_key) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "day_start", (double)(long)m_day_start) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "day_ref", m_day_ref) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "day_ref_balance", m_day_ref_balance) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "day_ref_equity", m_day_ref_equity) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "day_reconstructed", m_day_reconstructed ? 1.0 : 0.0) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "daily_lock_key", (double)m_daily_lock_key) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "overall_locked", m_overall_locked ? 1.0 : 0.0) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "target_locked", m_target_locked ? 1.0 : 0.0) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "unlock_code", (double)m_cfg.unlock_code) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "entries_today", (double)m_entries_today) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "fault_state", m_fault_state ? 1.0 : 0.0) == 0)
      ok = false;
   if(GlobalVariableSet(m_gv_prefix + "saved", 1.0) == 0)
      ok = false;
   GlobalVariablesFlush();
   return ok;
  }

bool CPropFirmGuard::LoadMirror(SGuardState &st)
  {
   ZeroMemory(st);
   if(!GlobalVariableCheck(m_gv_prefix + "saved"))
      return false;
   st.login = m_login;
   st.initial = GlobalVariableGet(m_gv_prefix + "initial");
   st.hwm_equity = GlobalVariableGet(m_gv_prefix + "hwm_equity");
   st.hwm_balance = GlobalVariableGet(m_gv_prefix + "hwm_balance");
   st.day_key = (long)GlobalVariableGet(m_gv_prefix + "day_key");
   st.day_start = (long)GlobalVariableGet(m_gv_prefix + "day_start");
   st.day_ref = GlobalVariableGet(m_gv_prefix + "day_ref");
   st.day_ref_balance = GlobalVariableGet(m_gv_prefix + "day_ref_balance");
   st.day_ref_equity = GlobalVariableGet(m_gv_prefix + "day_ref_equity");
   st.day_reconstructed = (int)GlobalVariableGet(m_gv_prefix + "day_reconstructed");
   st.daily_lock_key = (long)GlobalVariableGet(m_gv_prefix + "daily_lock_key");
   st.overall_locked = (int)GlobalVariableGet(m_gv_prefix + "overall_locked");
   st.target_locked = (int)GlobalVariableGet(m_gv_prefix + "target_locked");
   st.unlock_code = (int)GlobalVariableGet(m_gv_prefix + "unlock_code");
   st.entries_today = (int)GlobalVariableGet(m_gv_prefix + "entries_today");
   st.fault_state = (int)GlobalVariableGet(m_gv_prefix + "fault_state");
   return st.initial > 0.0;
  }

bool CPropFirmGuard::LoadFile(SGuardState &st)
  {
   ZeroMemory(st);
   if(!FileIsExist(m_state_file))
      return false;
   ResetLastError();
   int handle = FileOpen(m_state_file, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ, '\t', CP_UTF8);
   if(handle == INVALID_HANDLE)
      return false;
   string line = FileReadString(handle);
   FileClose(handle);
   StringTrimLeft(line);
   StringTrimRight(line);
   int crc_pos = StringFind(line, ";crc=");
   if(crc_pos <= 0)
      return false;
   string body = StringSubstr(line, 0, crc_pos);
   string crc_text = StringSubstr(line, crc_pos + 5);
   if(StringToInteger(crc_text) != (long)Fnv1a(body))
      return false;
   string parts[];
   ushort separator = StringGetCharacter(";", 0);
   int count = StringSplit(body, separator, parts);
   int seen = 0;
   for(int i = 0; i < count; i++)
     {
      int eq = StringFind(parts[i], "=");
      if(eq <= 0)
         continue;
      string key = StringSubstr(parts[i], 0, eq);
      string value = StringSubstr(parts[i], eq + 1);
      if(key == "login")
        { st.login = StringToInteger(value); seen++; }
      else if(key == "initial")
        { st.initial = StringToDouble(value); seen++; }
      else if(key == "hwm_equity")
        { st.hwm_equity = StringToDouble(value); seen++; }
      else if(key == "hwm_balance")
        { st.hwm_balance = StringToDouble(value); seen++; }
      else if(key == "day_key")
        { st.day_key = StringToInteger(value); seen++; }
      else if(key == "day_start")
        { st.day_start = StringToInteger(value); seen++; }
      else if(key == "day_ref")
        { st.day_ref = StringToDouble(value); seen++; }
      else if(key == "day_ref_balance")
        { st.day_ref_balance = StringToDouble(value); seen++; }
      else if(key == "day_ref_equity")
        { st.day_ref_equity = StringToDouble(value); seen++; }
      else if(key == "day_reconstructed")
        { st.day_reconstructed = (int)StringToInteger(value); seen++; }
      else if(key == "daily_lock_key")
        { st.daily_lock_key = StringToInteger(value); seen++; }
      else if(key == "overall_locked")
        { st.overall_locked = (int)StringToInteger(value); seen++; }
      else if(key == "target_locked")
        { st.target_locked = (int)StringToInteger(value); seen++; }
      else if(key == "unlock_code")
        { st.unlock_code = (int)StringToInteger(value); seen++; }
      else if(key == "entries_today")
        { st.entries_today = (int)StringToInteger(value); seen++; }
      else if(key == "fault_state")
        { st.fault_state = (int)StringToInteger(value); seen++; }
     }
   if(seen < 16 || st.login != m_login || st.initial <= 0.0)
      return false;
   return true;
  }

bool CPropFirmGuard::WriteHeartbeat(void)
  {
   if(!m_ready)
      return false;
   RefreshAccount();
   double extra = 0.0;
   bool unbounded = false;
   OpenWorstCase(extra, unbounded);
   double open_risk_pct = unbounded ? -1.0 : (m_initial > 0.0 ? extra / m_initial * 100.0 : 0.0);
   string symbol = m_cfg.symbol;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double spread = m_shield_attached ? m_shield_spread : SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
   datetime server_now = TimeTradeServer();
   string json = "{";
   json += JsonInt("schema", 1) + ",";
   json += JsonStr("ts_server", IsoTime(server_now, false)) + ",";
   json += JsonStr("ts_gmt", IsoTime(GmtNow(), true)) + ",";
   json += JsonInt("login", m_login) + ",";
   json += JsonStr("server", AccountInfoString(ACCOUNT_SERVER)) + ",";
   json += JsonStr("ea", m_cfg.ea_name) + ",";
   json += JsonStr("ea_version", m_cfg.ea_version) + ",";
   json += JsonNum("balance", m_balance, 2) + ",";
   json += JsonNum("equity", m_equity, 2) + ",";
   json += JsonNum("day_ref", m_day_ref, 2) + ",";
   json += JsonStr("day_basis", BasisName()) + ",";
   json += JsonStr("day_start_server", IsoTime(m_day_start, false)) + ",";
   json += JsonNum("daily_loss_pct", DailyLossPct(), 4) + ",";
   json += JsonNum("daily_lock_pct", m_cfg.daily_lock_pct, 4) + ",";
   json += JsonNum("firm_daily_limit_pct", m_cfg.firm_daily_limit_pct, 4) + ",";
   json += JsonNum("overall_floor", FirmFloor(), 2) + ",";
   json += JsonNum("overall_dd_pct", OverallDdPct(), 4) + ",";
   json += JsonNum("overall_lock_pct", m_cfg.overall_lock_pct, 4) + ",";
   json += JsonNum("firm_overall_limit_pct", m_cfg.firm_overall_limit_pct, 4) + ",";
   json += JsonStr("lock_state", LockState()) + ",";
   json += JsonInt("positions", m_positions_in_scope) + ",";
   json += JsonNum("open_risk_pct", open_risk_pct, 4) + ",";
   json += JsonInt("entries_today", m_entries_today) + ",";
   json += JsonStr("last_error", LastError()) + ",";
   json += JsonBool("trade_allowed", TradeAllowed()) + ",";
   json += JsonBool("connected", TerminalInfoInteger(TERMINAL_CONNECTED) != 0) + ",";
   json += JsonNum("spread", spread, digits) + ",";
   json += JsonBool("news_blackout", m_shield_news) + ",";
   json += JsonNum("initial_balance", m_initial, 2) + ",";
   json += JsonStr("daily_base", m_cfg.daily_limit_base == GUARD_BASE_INITIAL ? "INITIAL" : "DAY_REF") + ",";
   json += JsonNum("closing_commission_est", m_closing_commission, 2);
   json += "}";
   m_last_heartbeat = server_now;
   if(!AtomicWrite(m_heartbeat_file, json))
     {
      m_heartbeat_failures++;
      if(m_heartbeat_failures == 3)
         PrintFormat("PropFirmGuard: heartbeat write failing for %s, entries blocked until it recovers", m_heartbeat_file);
      return false;
     }
   m_heartbeat_failures = 0;
   return true;
  }

int CPropFirmGuard::MeasuredServerOffset(void) const
  {
   long diff = (long)TimeTradeServer() - (long)TimeGMT();
   return (int)(MathRound((double)diff / 900.0) * 900.0);
  }

int CPropFirmGuard::ServerOffsetAtGmt(const datetime gmt) const
  {
   if(m_cfg.server_tz == GUARD_SERVER_TZ_AUTO && !m_tester)
      return MeasuredServerOffset();
   int offset = m_cfg.server_gmt_offset_min * 60;
   if(m_cfg.server_dst_rule == GUARD_DST_EU && IsEuDst(gmt))
      offset += 3600;
   else if(m_cfg.server_dst_rule == GUARD_DST_US && IsUsDst(gmt))
      offset += 3600;
   return offset;
  }

datetime CPropFirmGuard::GmtFromServer(const datetime server_time) const
  {
   datetime gmt = (datetime)((long)server_time - (long)m_cfg.server_gmt_offset_min * 60);
   int offset = ServerOffsetAtGmt(gmt);
   gmt = (datetime)((long)server_time - offset);
   offset = ServerOffsetAtGmt(gmt);
   return (datetime)((long)server_time - offset);
  }

datetime CPropFirmGuard::ServerFromGmt(const datetime gmt) const
  {
   return (datetime)((long)gmt + ServerOffsetAtGmt(gmt));
  }

datetime CPropFirmGuard::GmtNow(void) const
  {
   if(m_tester)
      return GmtFromServer(TimeTradeServer());
   return TimeGMT();
  }

datetime CPropFirmGuard::NewYorkFromServer(const datetime server_time) const
  {
   datetime gmt = GmtFromServer(server_time);
   return (datetime)((long)gmt - 18000 + (IsUsDst(gmt) ? 3600 : 0));
  }

int CPropFirmGuard::ClockOffsetAtGmt(const datetime gmt) const
  {
   if(m_cfg.day_mode == GUARD_DAY_CET_EU_DST)
      return 3600 + (IsEuDst(gmt) ? 3600 : 0);
   if(m_cfg.day_mode == GUARD_DAY_NEW_YORK_US_DST)
      return -18000 + (IsUsDst(gmt) ? 3600 : 0);
   if(m_cfg.day_mode == GUARD_DAY_FIXED_GMT)
      return m_cfg.fixed_gmt_offset_min * 60;
   return 0;
  }

datetime CPropFirmGuard::ClockFromServer(const datetime server_time) const
  {
   if(m_cfg.day_mode == GUARD_DAY_SERVER)
      return server_time;
   datetime gmt = GmtFromServer(server_time);
   return (datetime)((long)gmt + ClockOffsetAtGmt(gmt));
  }

datetime CPropFirmGuard::ServerFromClock(const datetime clock_time) const
  {
   if(m_cfg.day_mode == GUARD_DAY_SERVER)
      return clock_time;
   int offset = ClockOffsetAtGmt(clock_time);
   datetime gmt = (datetime)((long)clock_time - offset);
   offset = ClockOffsetAtGmt(gmt);
   gmt = (datetime)((long)clock_time - offset);
   return ServerFromGmt(gmt);
  }

long CPropFirmGuard::FirmDayKeyAt(const datetime server_time) const
  {
   long reset = (long)m_cfg.day_reset_hour * 3600 + (long)m_cfg.day_reset_minute * 60;
   datetime shifted = (datetime)((long)ClockFromServer(server_time) - reset);
   MqlDateTime parts;
   TimeToStruct(shifted, parts);
   return (long)parts.year * 10000 + (long)parts.mon * 100 + (long)parts.day;
  }

datetime CPropFirmGuard::FirmDayStartAt(const datetime server_time) const
  {
   long reset = (long)m_cfg.day_reset_hour * 3600 + (long)m_cfg.day_reset_minute * 60;
   long shifted = (long)ClockFromServer(server_time) - reset;
   long clock_start = (shifted / 86400) * 86400 + reset;
   return ServerFromClock((datetime)clock_start);
  }

datetime CPropFirmGuard::NthSunday(const int year, const int month, const int n)
  {
   MqlDateTime parts;
   parts.year = year;
   parts.mon = month;
   parts.day = 1;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   parts.day_of_week = 0;
   parts.day_of_year = 0;
   datetime first = StructToTime(parts);
   MqlDateTime check;
   TimeToStruct(first, check);
   int to_sunday = (7 - check.day_of_week) % 7;
   return (datetime)((long)first + (long)(to_sunday + 7 * (n - 1)) * 86400);
  }

datetime CPropFirmGuard::LastSunday(const int year, const int month)
  {
   int next_year = year;
   int next_month = month + 1;
   if(next_month > 12)
     {
      next_month = 1;
      next_year++;
     }
   MqlDateTime parts;
   parts.year = next_year;
   parts.mon = next_month;
   parts.day = 1;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   parts.day_of_week = 0;
   parts.day_of_year = 0;
   datetime last_day = (datetime)((long)StructToTime(parts) - 86400);
   MqlDateTime check;
   TimeToStruct(last_day, check);
   return (datetime)((long)last_day - (long)check.day_of_week * 86400);
  }

bool CPropFirmGuard::IsEuDst(const datetime gmt)
  {
   MqlDateTime parts;
   TimeToStruct(gmt, parts);
   datetime begin = (datetime)((long)LastSunday(parts.year, 3) + 3600);
   datetime end = (datetime)((long)LastSunday(parts.year, 10) + 3600);
   return gmt >= begin && gmt < end;
  }

bool CPropFirmGuard::IsUsDst(const datetime gmt)
  {
   MqlDateTime parts;
   TimeToStruct(gmt, parts);
   datetime begin = (datetime)((long)NthSunday(parts.year, 3, 2) + 7 * 3600);
   datetime end = (datetime)((long)NthSunday(parts.year, 11, 1) + 6 * 3600);
   return gmt >= begin && gmt < end;
  }

string CPropFirmGuard::IsoTime(const datetime value, const bool zulu)
  {
   string text = TimeToString(value, TIME_DATE | TIME_SECONDS);
   StringReplace(text, ".", "-");
   StringReplace(text, " ", "T");
   if(zulu)
      text += "Z";
   return text;
  }

double CPropFirmGuard::DealAmount(const ulong deal)
  {
   return HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_COMMISSION)
          + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_FEE);
  }

uint CPropFirmGuard::Fnv1a(const string text)
  {
   uint hash = (uint)2166136261;
   int length = StringLen(text);
   for(int i = 0; i < length; i++)
     {
      hash ^= (uint)StringGetCharacter(text, i);
      hash *= (uint)16777619;
     }
   return hash;
  }

string CPropFirmGuard::JsonEscape(const string text)
  {
   string out = "";
   int length = StringLen(text);
   for(int i = 0; i < length; i++)
     {
      ushort c = StringGetCharacter(text, i);
      if(c == 34)
         out += "\\\"";
      else if(c == 92)
         out += "\\\\";
      else if(c < 32)
         out += " ";
      else if(c > 126)
         out += "?";
      else
         out += ShortToString(c);
     }
   return out;
  }

string CPropFirmGuard::JsonStr(const string key, const string value)
  {
   return "\"" + key + "\":\"" + JsonEscape(value) + "\"";
  }

string CPropFirmGuard::JsonNum(const string key, const double value, const int digits)
  {
   string number = MathIsValidNumber(value) ? DoubleToString(value, digits) : "0";
   return "\"" + key + "\":" + number;
  }

string CPropFirmGuard::JsonInt(const string key, const long value)
  {
   return "\"" + key + "\":" + IntegerToString(value);
  }

string CPropFirmGuard::JsonBool(const string key, const bool value)
  {
   return "\"" + key + "\":" + (value ? "true" : "false");
  }

int CPropFirmGuard::VolumeDigits(const double step)
  {
   int digits = 0;
   double scaled = step;
   while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 1e-9)
     {
      scaled *= 10.0;
      digits++;
     }
   return digits;
  }

#endif
