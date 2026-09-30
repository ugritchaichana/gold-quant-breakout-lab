#ifndef EXECUTION_SHIELD_MQH
#define EXECUTION_SHIELD_MQH

#include "PropFirmGuard.mqh"

enum ENUM_SHIELD_NEWS_SOURCE
  {
   SHIELD_NEWS_AUTO     = 0, // Calendar live, CSV in tester, session windows on failure
   SHIELD_NEWS_CALENDAR = 1, // Calendar only, session windows on failure
   SHIELD_NEWS_CSV      = 2, // CSV only, session windows on failure
   SHIELD_NEWS_SESSION  = 3, // Session windows only
   SHIELD_NEWS_OFF      = 4  // No news blackout
  };

input group "=== EXECUTION SHIELD ==="
input double                         InpShieldMaxSpreadPrice      = 0.0;                        // Absolute spread cap, price units (0 = off)
input double                         InpShieldSpreadMedianMult    = 2.0;                        // Block above this multiple of the rolling median (0 = off)
input int                            InpShieldSpreadWindow        = 300;                        // Rolling median window, samples
input int                            InpShieldSpreadMinSamples    = 30;                         // Samples required before entries
input string                         InpShieldRolloverWindow      = "23:45-01:00";              // No-entry window, server HH:MM-HH:MM (empty = off)
input int                            InpShieldFridayNoEntryHour   = 20;                         // Friday server hour with no new entries (-1 = off)
input int                            InpShieldFridayFlattenHour   = -1;                         // Friday server hour to flatten (-1 = off)
input int                            InpShieldFridayFlattenMinute = 0;                          // Friday flatten minute
input ENUM_SHIELD_NEWS_SOURCE        InpShieldNewsSource          = SHIELD_NEWS_AUTO;           // News source
input string                         InpShieldNewsCurrencies      = "USD";                      // News currencies, comma separated
input ENUM_CALENDAR_EVENT_IMPORTANCE InpShieldNewsMinImportance   = CALENDAR_IMPORTANCE_HIGH;   // Minimum news importance
input int                            InpShieldNewsBeforeMin       = 15;                         // Blackout minutes before an event
input int                            InpShieldNewsAfterMin        = 15;                         // Blackout minutes after an event
input string                         InpShieldNewsCsvFile         = "PropGuard\\calendar.csv";  // Tester news CSV in the common files folder
input int                            InpShieldNewsShiftMin        = 0;                          // Minutes added to live calendar times
input string                         InpShieldSessionWindowsNy    = "08:25-08:45,09:55-10:10,13:55-14:20"; // Fallback windows, New York time
input string                         InpShieldTier1Keywords       = "Nonfarm,CPI,Interest Rate Decision,FOMC"; // Tier-1 event name keywords
input bool                           InpShieldFlattenBeforeTier1  = false;                      // Flatten before tier-1 events
input int                            InpShieldFlattenBeforeMin    = 5;                          // Minutes before a tier-1 event to flatten
input int                            InpShieldMaxEntriesPerDay    = 2;                          // Max entries per firm day (0 = off)
input int                            InpShieldCooldownBars        = 4;                          // Entry-timeframe bars blocked after a losing exit (0 = off)
input double                         InpShieldReconcileTolPct     = 10.0;                       // Post-fill risk tolerance above plan, percent (0 = off)
input int                            InpShieldCalendarRefreshMin  = 15;                         // Live calendar refresh period, minutes

struct SShieldConfig
  {
   string                         symbol;
   ulong                          magic;
   ENUM_TIMEFRAMES                entry_tf;
   double                         max_spread_price;
   double                         spread_median_mult;
   int                            spread_window;
   int                            spread_min_samples;
   string                         rollover_window;
   int                            friday_no_entry_hour;
   int                            friday_flatten_hour;
   int                            friday_flatten_minute;
   ENUM_SHIELD_NEWS_SOURCE        news_source;
   string                         news_currencies;
   ENUM_CALENDAR_EVENT_IMPORTANCE news_min_importance;
   int                            news_before_min;
   int                            news_after_min;
   string                         news_csv_file;
   int                            news_shift_min;
   string                         session_windows_ny;
   string                         tier1_keywords;
   bool                           flatten_before_tier1;
   int                            flatten_before_min;
   int                            max_entries_per_day;
   int                            cooldown_bars;
   double                         reconcile_tol_pct;
   int                            calendar_refresh_min;
  };

void ShieldConfigFromInputs(SShieldConfig &cfg, const string symbol, const ulong magic, const ENUM_TIMEFRAMES entry_tf)
  {
   cfg.symbol                = symbol;
   cfg.magic                 = magic;
   cfg.entry_tf              = entry_tf;
   cfg.max_spread_price      = InpShieldMaxSpreadPrice;
   cfg.spread_median_mult    = InpShieldSpreadMedianMult;
   cfg.spread_window         = InpShieldSpreadWindow;
   cfg.spread_min_samples    = InpShieldSpreadMinSamples;
   cfg.rollover_window       = InpShieldRolloverWindow;
   cfg.friday_no_entry_hour  = InpShieldFridayNoEntryHour;
   cfg.friday_flatten_hour   = InpShieldFridayFlattenHour;
   cfg.friday_flatten_minute = InpShieldFridayFlattenMinute;
   cfg.news_source           = InpShieldNewsSource;
   cfg.news_currencies       = InpShieldNewsCurrencies;
   cfg.news_min_importance   = InpShieldNewsMinImportance;
   cfg.news_before_min       = InpShieldNewsBeforeMin;
   cfg.news_after_min        = InpShieldNewsAfterMin;
   cfg.news_csv_file         = InpShieldNewsCsvFile;
   cfg.news_shift_min        = InpShieldNewsShiftMin;
   cfg.session_windows_ny    = InpShieldSessionWindowsNy;
   cfg.tier1_keywords        = InpShieldTier1Keywords;
   cfg.flatten_before_tier1  = InpShieldFlattenBeforeTier1;
   cfg.flatten_before_min    = InpShieldFlattenBeforeMin;
   cfg.max_entries_per_day   = InpShieldMaxEntriesPerDay;
   cfg.cooldown_bars         = InpShieldCooldownBars;
   cfg.reconcile_tol_pct     = InpShieldReconcileTolPct;
   cfg.calendar_refresh_min  = InpShieldCalendarRefreshMin;
  }

class CExecutionShield
  {
private:
   SShieldConfig     m_cfg;
   CPropFirmGuard   *m_guard;
   bool              m_ready;
   bool              m_tester;
   double            m_spreads[];
   int               m_spread_count;
   int               m_spread_pos;
   datetime          m_last_sample;
   double            m_spread_now;
   datetime          m_news_time[];
   bool              m_news_tier1[];
   string            m_news_name[];
   int               m_news_count;
   bool              m_news_source_ok;
   string            m_news_source;
   datetime          m_last_calendar_refresh;
   bool              m_blackout_now;
   datetime          m_last_loss_exit;
   datetime          m_last_friday_flatten;
   datetime          m_last_tier1_flatten;
   int               m_roll_start;
   int               m_roll_end;
   int               m_session_start[];
   int               m_session_end[];
   int               m_session_count;
   string            m_keywords[];
   int               m_keyword_count;

   bool              GuardOk(void);
   void              Update(void);
   void              ClearNews(void);
   void              AddNews(const datetime server_time, const string name);
   bool              IsTier1Name(const string name);
   bool              CurrencyWanted(const string currency);
   void              ScanLastLosingExit(void);
   void              Reconcile(const ulong deal, const ulong position_ticket);
   void              ParseSessions(void);
   void              ParseKeywords(void);

public:
                     CExecutionShield(void);
                    ~CExecutionShield(void);
   bool              Init(const SShieldConfig &cfg, CPropFirmGuard *guard);
   void              Deinit(void);
   void              OnTick(void);
   void              OnTimer(void);
   void              OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
   bool              EntryAllowed(string &reason);
   bool              SpreadOk(const double spread, string &reason);
   double            SpreadMedian(void);
   void              AddSpreadSample(const double spread);
   bool              InRolloverWindow(const datetime server_time);
   bool              FridayNoEntry(const datetime server_time);
   bool              FridayFlattenDue(const datetime server_time);
   bool              NewsBlackoutAt(const datetime server_time);
   bool              SessionBlackoutAt(const datetime server_time);
   bool              Tier1Within(const datetime server_time, const int minutes_ahead);
   bool              EntriesCapReached(void);
   bool              CooldownActive(void);
   bool              LoadNewsCsv(void);
   bool              RefreshCalendar(void);
   int               NewsEventCount(void) const { return m_news_count; }
   string            NewsSource(void) const { return m_news_source; }
   int               SpreadSampleCount(void) const { return m_spread_count; }
   datetime          LastLosingExit(void) const { return m_last_loss_exit; }
   static string     ExecutionModeName(const long mode);
   static bool       ParseWindow(const string text, int &start_minute, int &end_minute);
   static bool       InWindow(const int minute_of_day, const int start_minute, const int end_minute);
  };

CExecutionShield::CExecutionShield(void)
  {
   m_guard = NULL;
   m_ready = false;
   m_tester = false;
   m_spread_count = 0;
   m_spread_pos = 0;
   m_last_sample = 0;
   m_spread_now = 0.0;
   m_news_count = 0;
   m_news_source_ok = false;
   m_news_source = "off";
   m_last_calendar_refresh = 0;
   m_blackout_now = false;
   m_last_loss_exit = 0;
   m_last_friday_flatten = 0;
   m_last_tier1_flatten = 0;
   m_roll_start = -1;
   m_roll_end = -1;
   m_session_count = 0;
   m_keyword_count = 0;
  }

CExecutionShield::~CExecutionShield(void)
  {
  }

bool CExecutionShield::GuardOk(void)
  {
   return CheckPointer(m_guard) != POINTER_INVALID;
  }

bool CExecutionShield::Init(const SShieldConfig &cfg, CPropFirmGuard *guard)
  {
   m_cfg = cfg;
   m_guard = guard;
   m_ready = false;
   m_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   if(!GuardOk())
     {
      Print("ExecutionShield: guard pointer is invalid");
      return false;
     }
   if(m_cfg.spread_window < 1)
      m_cfg.spread_window = 1;
   ArrayResize(m_spreads, m_cfg.spread_window);
   ArrayInitialize(m_spreads, 0.0);
   m_spread_count = 0;
   m_spread_pos = 0;
   m_last_sample = 0;
   m_spread_now = 0.0;
   m_roll_start = -1;
   m_roll_end = -1;
   if(m_cfg.rollover_window != "" && !ParseWindow(m_cfg.rollover_window, m_roll_start, m_roll_end))
     {
      PrintFormat("ExecutionShield: rollover window '%s' is not HH:MM-HH:MM", m_cfg.rollover_window);
      return false;
     }
   ParseSessions();
   ParseKeywords();
   ClearNews();
   m_news_source_ok = false;
   m_news_source = "session";
   if(m_cfg.news_source == SHIELD_NEWS_OFF)
      m_news_source = "off";
   else if(m_cfg.news_source == SHIELD_NEWS_CSV || (m_cfg.news_source == SHIELD_NEWS_AUTO && m_tester))
     {
      if(LoadNewsCsv())
        {
         m_news_source_ok = true;
         m_news_source = "csv";
        }
      else
         PrintFormat("ExecutionShield: news CSV '%s' unavailable in the common files folder, session windows active", m_cfg.news_csv_file);
     }
   else if(m_cfg.news_source == SHIELD_NEWS_CALENDAR || m_cfg.news_source == SHIELD_NEWS_AUTO)
     {
      if(m_tester)
         Print("ExecutionShield: calendar functions are not available in the tester, session windows active");
      else
         RefreshCalendar();
     }
   long mode = SymbolInfoInteger(m_cfg.symbol, SYMBOL_TRADE_EXEMODE);
   PrintFormat("ExecutionShield: %s execution=%s filling_flags=%I64d stops_level=%I64d freeze_level=%I64d margin_mode=%I64d news=%s events=%d",
               m_cfg.symbol, ExecutionModeName(mode), SymbolInfoInteger(m_cfg.symbol, SYMBOL_FILLING_MODE),
               SymbolInfoInteger(m_cfg.symbol, SYMBOL_TRADE_STOPS_LEVEL), SymbolInfoInteger(m_cfg.symbol, SYMBOL_TRADE_FREEZE_LEVEL),
               AccountInfoInteger(ACCOUNT_MARGIN_MODE), m_news_source, m_news_count);
   if(mode == SYMBOL_TRADE_EXECUTION_MARKET || mode == SYMBOL_TRADE_EXECUTION_EXCHANGE)
      Print("ExecutionShield: deviation is ignored under this execution mode; post-fill reconciliation is the slippage control");
   m_last_loss_exit = 0;
   ScanLastLosingExit();
   m_ready = true;
   Update();
   return true;
  }

void CExecutionShield::Deinit(void)
  {
   m_ready = false;
  }

void CExecutionShield::OnTick(void)
  {
   Update();
  }

void CExecutionShield::OnTimer(void)
  {
   Update();
  }

void CExecutionShield::Update(void)
  {
   if(!m_ready || !GuardOk())
      return;
   datetime now = TimeTradeServer();
   MqlTick tick;
   if(SymbolInfoTick(m_cfg.symbol, tick) && tick.ask > 0.0 && tick.bid > 0.0)
     {
      m_spread_now = tick.ask - tick.bid;
      if(now != m_last_sample)
        {
         AddSpreadSample(m_spread_now);
         m_last_sample = now;
        }
     }
   bool calendar_mode = (m_cfg.news_source == SHIELD_NEWS_CALENDAR || m_cfg.news_source == SHIELD_NEWS_AUTO);
   if(!m_tester && calendar_mode && (long)now - (long)m_last_calendar_refresh >= (long)m_cfg.calendar_refresh_min * 60)
      RefreshCalendar();
   m_blackout_now = NewsBlackoutAt(now);
   m_guard.SetShieldStatus(m_spread_now, m_blackout_now);
   if(FridayFlattenDue(now) && m_guard.PositionsInScope() > 0 && (long)now - (long)m_last_friday_flatten >= 60)
     {
      m_last_friday_flatten = now;
      Print("ExecutionShield: Friday flatten");
      m_guard.CloseAllInScope("friday flatten");
     }
   if(m_cfg.flatten_before_tier1 && Tier1Within(now, m_cfg.flatten_before_min) && m_guard.PositionsInScope() > 0
      && (long)now - (long)m_last_tier1_flatten >= 60)
     {
      m_last_tier1_flatten = now;
      Print("ExecutionShield: flatten before tier-1 event");
      m_guard.CloseAllInScope("tier-1 news flatten");
     }
  }

bool CExecutionShield::EntryAllowed(string &reason)
  {
   reason = "";
   if(!m_ready || !GuardOk())
     {
      reason = "shield not initialized";
      return false;
     }
   Update();
   datetime now = TimeTradeServer();
   if(m_blackout_now)
     {
      reason = "news blackout";
      return false;
     }
   if(InRolloverWindow(now))
     {
      reason = "rollover window";
      return false;
     }
   if(FridayNoEntry(now))
     {
      reason = "Friday no-entry hours";
      return false;
     }
   if(!SpreadOk(m_spread_now, reason))
      return false;
   if(EntriesCapReached())
     {
      reason = "max entries per firm day reached";
      return false;
     }
   if(CooldownActive())
     {
      reason = "cooldown after losing exit";
      return false;
     }
   return true;
  }

bool CExecutionShield::SpreadOk(const double spread, string &reason)
  {
   reason = "";
   if(spread <= 0.0)
     {
      reason = "no valid quote";
      return false;
     }
   if(m_cfg.max_spread_price > 0.0 && spread > m_cfg.max_spread_price)
     {
      reason = StringFormat("spread %.5f above cap %.5f", spread, m_cfg.max_spread_price);
      return false;
     }
   if(m_cfg.spread_median_mult > 0.0)
     {
      if(m_spread_count < m_cfg.spread_min_samples)
        {
         reason = StringFormat("spread median warming up (%d of %d samples)", m_spread_count, m_cfg.spread_min_samples);
         return false;
        }
      double median = SpreadMedian();
      if(median > 0.0 && spread > m_cfg.spread_median_mult * median)
        {
         reason = StringFormat("spread %.5f above %.2f x median %.5f", spread, m_cfg.spread_median_mult, median);
         return false;
        }
     }
   return true;
  }

double CExecutionShield::SpreadMedian(void)
  {
   if(m_spread_count <= 0)
      return 0.0;
   double sorted[];
   ArrayResize(sorted, m_spread_count);
   for(int i = 0; i < m_spread_count; i++)
      sorted[i] = m_spreads[i];
   ArraySort(sorted);
   int mid = m_spread_count / 2;
   if(m_spread_count % 2 == 1)
      return sorted[mid];
   return 0.5 * (sorted[mid - 1] + sorted[mid]);
  }

void CExecutionShield::AddSpreadSample(const double spread)
  {
   int window = ArraySize(m_spreads);
   if(window <= 0 || spread <= 0.0)
      return;
   m_spreads[m_spread_pos] = spread;
   m_spread_pos = (m_spread_pos + 1) % window;
   if(m_spread_count < window)
      m_spread_count++;
  }

bool CExecutionShield::InRolloverWindow(const datetime server_time)
  {
   if(m_roll_start < 0 || m_roll_end < 0)
      return false;
   MqlDateTime parts;
   TimeToStruct(server_time, parts);
   return InWindow(parts.hour * 60 + parts.min, m_roll_start, m_roll_end);
  }

bool CExecutionShield::FridayNoEntry(const datetime server_time)
  {
   if(m_cfg.friday_no_entry_hour < 0)
      return false;
   MqlDateTime parts;
   TimeToStruct(server_time, parts);
   return parts.day_of_week == 5 && parts.hour >= m_cfg.friday_no_entry_hour;
  }

bool CExecutionShield::FridayFlattenDue(const datetime server_time)
  {
   if(m_cfg.friday_flatten_hour < 0)
      return false;
   MqlDateTime parts;
   TimeToStruct(server_time, parts);
   return parts.day_of_week == 5 && parts.hour * 60 + parts.min >= m_cfg.friday_flatten_hour * 60 + m_cfg.friday_flatten_minute;
  }

bool CExecutionShield::NewsBlackoutAt(const datetime server_time)
  {
   if(m_cfg.news_source == SHIELD_NEWS_OFF)
      return false;
   if(m_cfg.news_source != SHIELD_NEWS_SESSION && m_news_source_ok)
     {
      long t = (long)server_time;
      for(int i = 0; i < m_news_count; i++)
        {
         long event_time = (long)m_news_time[i];
         if(t >= event_time - (long)m_cfg.news_before_min * 60 && t <= event_time + (long)m_cfg.news_after_min * 60)
            return true;
        }
      return false;
     }
   return SessionBlackoutAt(server_time);
  }

bool CExecutionShield::SessionBlackoutAt(const datetime server_time)
  {
   if(m_session_count <= 0 || !GuardOk())
      return false;
   datetime ny = m_guard.NewYorkFromServer(server_time);
   MqlDateTime parts;
   TimeToStruct(ny, parts);
   if(parts.day_of_week == 0 || parts.day_of_week == 6)
      return false;
   int minute = parts.hour * 60 + parts.min;
   for(int i = 0; i < m_session_count; i++)
      if(InWindow(minute, m_session_start[i], m_session_end[i]))
         return true;
   return false;
  }

bool CExecutionShield::Tier1Within(const datetime server_time, const int minutes_ahead)
  {
   if(!m_news_source_ok)
      return false;
   long t = (long)server_time;
   for(int i = 0; i < m_news_count; i++)
     {
      if(!m_news_tier1[i])
         continue;
      long lead = (long)m_news_time[i] - t;
      if(lead >= 0 && lead <= (long)minutes_ahead * 60)
         return true;
     }
   return false;
  }

bool CExecutionShield::EntriesCapReached(void)
  {
   if(m_cfg.max_entries_per_day <= 0 || !GuardOk())
      return false;
   return m_guard.EntriesToday() >= m_cfg.max_entries_per_day;
  }

bool CExecutionShield::CooldownActive(void)
  {
   if(m_cfg.cooldown_bars <= 0 || m_last_loss_exit == 0)
      return false;
   int shift = iBarShift(m_cfg.symbol, m_cfg.entry_tf, m_last_loss_exit, false);
   if(shift < 0)
      return true;
   return shift < m_cfg.cooldown_bars;
  }

void CExecutionShield::ClearNews(void)
  {
   ArrayResize(m_news_time, 0);
   ArrayResize(m_news_tier1, 0);
   ArrayResize(m_news_name, 0);
   m_news_count = 0;
  }

void CExecutionShield::AddNews(const datetime server_time, const string name)
  {
   ArrayResize(m_news_time, m_news_count + 1);
   ArrayResize(m_news_tier1, m_news_count + 1);
   ArrayResize(m_news_name, m_news_count + 1);
   m_news_time[m_news_count] = server_time;
   m_news_tier1[m_news_count] = IsTier1Name(name);
   m_news_name[m_news_count] = name;
   m_news_count++;
  }

bool CExecutionShield::IsTier1Name(const string name)
  {
   string upper = name;
   StringToUpper(upper);
   for(int i = 0; i < m_keyword_count; i++)
      if(m_keywords[i] != "" && StringFind(upper, m_keywords[i]) >= 0)
         return true;
   return false;
  }

bool CExecutionShield::CurrencyWanted(const string currency)
  {
   string wanted[];
   ushort comma = StringGetCharacter(",", 0);
   int count = StringSplit(m_cfg.news_currencies, comma, wanted);
   for(int i = 0; i < count; i++)
     {
      string item = wanted[i];
      StringTrimLeft(item);
      StringTrimRight(item);
      if(item != "" && item == currency)
         return true;
     }
   return false;
  }

bool CExecutionShield::LoadNewsCsv(void)
  {
   ClearNews();
   if(!GuardOk())
      return false;
   ResetLastError();
   int handle = FileOpen(m_cfg.news_csv_file, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, '\t', CP_UTF8);
   if(handle == INVALID_HANDLE)
      return false;
   ushort comma = StringGetCharacter(",", 0);
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line == "" || StringFind(line, "time_gmt") == 0)
         continue;
      string fields[];
      int count = StringSplit(line, comma, fields);
      if(count < 5)
         continue;
      datetime gmt = StringToTime(fields[0]);
      if(gmt <= 0)
         continue;
      string currency = fields[1];
      StringTrimLeft(currency);
      StringTrimRight(currency);
      if(!CurrencyWanted(currency))
         continue;
      if(StringToInteger(fields[2]) < (long)m_cfg.news_min_importance)
         continue;
      AddNews(m_guard.ServerFromGmt(gmt), fields[4]);
     }
   FileClose(handle);
   return m_news_count > 0;
  }

bool CExecutionShield::RefreshCalendar(void)
  {
   m_last_calendar_refresh = TimeTradeServer();
   if(m_tester)
      return false;
   datetime now = TimeTradeServer();
   datetime from = (datetime)((long)now - ((long)m_cfg.news_after_min + 60) * 60);
   datetime to = (datetime)((long)now + 36 * 3600);
   string currencies[];
   ushort comma = StringGetCharacter(",", 0);
   int count = StringSplit(m_cfg.news_currencies, comma, currencies);
   datetime times[];
   string names[];
   int found = 0;
   bool any_ok = false;
   for(int c = 0; c < count; c++)
     {
      string currency = currencies[c];
      StringTrimLeft(currency);
      StringTrimRight(currency);
      if(currency == "")
         continue;
      MqlCalendarValue values[];
      ResetLastError();
      int got = (int)CalendarValueHistory(values, from, to, NULL, currency);
      int error = GetLastError();
      if(got <= 0 && error != 0)
        {
         PrintFormat("ExecutionShield: calendar query for %s failed, error %d", currency, error);
         continue;
        }
      any_ok = true;
      int total = ArraySize(values);
      for(int i = 0; i < total; i++)
        {
         MqlCalendarEvent calendar_event;
         if(!CalendarEventById(values[i].event_id, calendar_event))
            continue;
         if(calendar_event.importance < m_cfg.news_min_importance)
            continue;
         ArrayResize(times, found + 1);
         ArrayResize(names, found + 1);
         times[found] = (datetime)((long)values[i].time + (long)m_cfg.news_shift_min * 60);
         names[found] = calendar_event.name;
         found++;
        }
     }
   if(!any_ok)
     {
      m_news_source_ok = false;
      m_news_source = "session";
      return false;
     }
   ClearNews();
   for(int k = 0; k < found; k++)
      AddNews(times[k], names[k]);
   m_news_source_ok = true;
   m_news_source = "calendar";
   return true;
  }

void CExecutionShield::ScanLastLosingExit(void)
  {
   datetime now = TimeTradeServer();
   if(!HistorySelect((datetime)((long)now - 7 * 86400), (datetime)((long)now + 86400)))
      return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != m_cfg.symbol || (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != m_cfg.magic)
         continue;
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      double net = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_COMMISSION)
                   + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_FEE);
      datetime when = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(net < 0.0 && when > m_last_loss_exit)
         m_last_loss_exit = when;
     }
  }

void CExecutionShield::OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(!m_ready || !GuardOk())
      return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != m_cfg.symbol || (ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != m_cfg.magic)
      return;
   long type = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
      return;
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
     {
      double net = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION)
                   + HistoryDealGetDouble(trans.deal, DEAL_SWAP) + HistoryDealGetDouble(trans.deal, DEAL_FEE);
      if(net < 0.0)
         m_last_loss_exit = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
      return;
     }
   if(entry == DEAL_ENTRY_IN && m_cfg.reconcile_tol_pct > 0.0)
     {
      ulong position = trans.position != 0 ? trans.position : (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      Reconcile(trans.deal, position);
     }
  }

void CExecutionShield::Reconcile(const ulong deal, const ulong position_ticket)
  {
   datetime when = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
   bool deal_buy = (HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_BUY);
   double intended_price = 0.0;
   double intended_sl = 0.0;
   double planned = 0.0;
   if(!m_guard.IntentFor(m_cfg.symbol, deal_buy, when, intended_price, intended_sl, planned) || planned <= 0.0)
      return;
   ulong ticket = position_ticket;
   if(ticket == 0 || !PositionSelectByTicket(ticket))
     {
      if(!PositionSelect(m_cfg.symbol))
         return;
      ticket = (ulong)PositionGetInteger(POSITION_TICKET);
     }
   bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   if(sl <= 0.0)
      sl = intended_sl;
   if(sl <= 0.0)
     {
      Print("ExecutionShield: filled position has no stop loss, closing");
      m_guard.CloseTicket(ticket, "post-fill without stop loss");
      return;
     }
   double per_lot = m_guard.WorstCaseLossPerLot(m_cfg.symbol, is_buy, open_price, sl);
   if(per_lot <= 0.0)
      return;
   double realized = per_lot * volume;
   if(realized <= planned * (1.0 + m_cfg.reconcile_tol_pct / 100.0))
      return;
   double step = SymbolInfoDouble(m_cfg.symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(m_cfg.symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0.0)
      return;
   double keep = MathFloor(planned / per_lot / step + 1e-7) * step;
   PrintFormat("ExecutionShield: post-fill risk %.2f exceeds plan %.2f by more than %.1f%%, keeping %.2f of %.2f lots",
               realized, planned, m_cfg.reconcile_tol_pct, keep, volume);
   if(keep < min_lot - 1e-9)
     {
      m_guard.CloseTicket(ticket, "post-fill risk above plan");
      return;
     }
   double cut = volume - keep;
   cut = NormalizeDouble(MathFloor(cut / step + 1e-7) * step, CPropFirmGuard::VolumeDigits(step));
   if(cut >= min_lot - 1e-9)
      m_guard.ClosePartial(ticket, cut, "post-fill risk above plan");
  }

void CExecutionShield::ParseSessions(void)
  {
   ArrayResize(m_session_start, 0);
   ArrayResize(m_session_end, 0);
   m_session_count = 0;
   string windows[];
   ushort comma = StringGetCharacter(",", 0);
   int count = StringSplit(m_cfg.session_windows_ny, comma, windows);
   for(int i = 0; i < count; i++)
     {
      int start_minute = -1;
      int end_minute = -1;
      string item = windows[i];
      StringTrimLeft(item);
      StringTrimRight(item);
      if(item == "")
         continue;
      if(!ParseWindow(item, start_minute, end_minute))
        {
         PrintFormat("ExecutionShield: session window '%s' ignored, expected HH:MM-HH:MM", item);
         continue;
        }
      ArrayResize(m_session_start, m_session_count + 1);
      ArrayResize(m_session_end, m_session_count + 1);
      m_session_start[m_session_count] = start_minute;
      m_session_end[m_session_count] = end_minute;
      m_session_count++;
     }
  }

void CExecutionShield::ParseKeywords(void)
  {
   ArrayResize(m_keywords, 0);
   m_keyword_count = 0;
   string items[];
   ushort comma = StringGetCharacter(",", 0);
   int count = StringSplit(m_cfg.tier1_keywords, comma, items);
   for(int i = 0; i < count; i++)
     {
      string item = items[i];
      StringTrimLeft(item);
      StringTrimRight(item);
      if(item == "")
         continue;
      StringToUpper(item);
      ArrayResize(m_keywords, m_keyword_count + 1);
      m_keywords[m_keyword_count] = item;
      m_keyword_count++;
     }
  }

string CExecutionShield::ExecutionModeName(const long mode)
  {
   if(mode == SYMBOL_TRADE_EXECUTION_REQUEST)
      return "REQUEST";
   if(mode == SYMBOL_TRADE_EXECUTION_INSTANT)
      return "INSTANT";
   if(mode == SYMBOL_TRADE_EXECUTION_MARKET)
      return "MARKET";
   if(mode == SYMBOL_TRADE_EXECUTION_EXCHANGE)
      return "EXCHANGE";
   return "UNKNOWN";
  }

bool CExecutionShield::ParseWindow(const string text, int &start_minute, int &end_minute)
  {
   start_minute = -1;
   end_minute = -1;
   string halves[];
   ushort dash = StringGetCharacter("-", 0);
   if(StringSplit(text, dash, halves) != 2)
      return false;
   int minutes[2];
   ushort colon = StringGetCharacter(":", 0);
   for(int i = 0; i < 2; i++)
     {
      string hm[];
      string item = halves[i];
      StringTrimLeft(item);
      StringTrimRight(item);
      if(StringSplit(item, colon, hm) != 2)
         return false;
      int hour = (int)StringToInteger(hm[0]);
      int minute = (int)StringToInteger(hm[1]);
      if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
         return false;
      minutes[i] = hour * 60 + minute;
     }
   start_minute = minutes[0];
   end_minute = minutes[1];
   return true;
  }

bool CExecutionShield::InWindow(const int minute_of_day, const int start_minute, const int end_minute)
  {
   if(start_minute == end_minute)
      return false;
   if(start_minute < end_minute)
      return minute_of_day >= start_minute && minute_of_day < end_minute;
   return minute_of_day >= start_minute || minute_of_day < end_minute;
  }

#endif
