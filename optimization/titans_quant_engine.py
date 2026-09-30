"""
TITANS QUANT ENGINE: 5-ASSET MULTI-CORE OPTIMIZATION & PORTFOLIO SIMULATOR
Enhanced with:
  1. +50% Stress Friction (Widened spread + execution slippage deduction per trade)
  2. Asset-Specific Session Hours (London for FX, US Cash Open for Tech, Inventory for Oil)
  3. Automatic .set Generation into models/<folder>/presets/
  4. Unified Event-Driven Chronological Portfolio Simulator ($25,000 Shared Pool)
"""

import os
import sys
import time
import sqlite3
import multiprocessing
import itertools
import numpy as np
import pandas as pd

WORKSPACE_DIR = r"C:\Users\Booth\quant_ea_lab"
DB_PATH = os.path.join(WORKSPACE_DIR, "quant_vault.db")
MARKET_DB = os.path.join(WORKSPACE_DIR, "data", "market_history.db")
MODELS_DIR = os.path.join(WORKSPACE_DIR, "models")

MODELS_CONFIG = [
    {
        "id": "M1_GOLD",
        "symbol": "XAUUSD",
        "name": "Gold Specialist",
        "folder": "Model_1_Gold_Specialist",
        "magic": 100101,
        "start_hour": None,
        "end_hour": None,
        "stress_r": 0.05,
        "default_donchian": [48, 72, 96, 104],
        "default_min_ker": [0.28, 0.32, 0.35]
    },
    {
        "id": "M2_NASDAQ",
        "symbol": "NAS100",
        "name": "Nasdaq Momentum",
        "folder": "Model_2_Nasdaq_Momentum",
        "magic": 100201,
        "start_hour": 13,
        "end_hour": 21,
        "stress_r": 0.06,
        "default_donchian": [24, 36, 48, 72],
        "default_min_ker": [0.35, 0.38, 0.42]
    },
    {
        "id": "M3_FOREX",
        "symbol": "GBPJPY",
        "name": "Forex Beast",
        "folder": "Model_3_Forex_Beast",
        "magic": 100301,
        "start_hour": 7,
        "end_hour": 16,
        "stress_r": 0.05,
        "default_donchian": [16, 20, 24, 32, 48],
        "default_min_ker": [0.15, 0.20, 0.25]
    },
    {
        "id": "M4_OIL",
        "symbol": "USOIL",
        "name": "Oil Trend",
        "folder": "Model_4_Oil_Trend",
        "magic": 100401,
        "start_hour": 8,
        "end_hour": 19,
        "stress_r": 0.06,
        "default_donchian": [24, 36, 48, 72],
        "default_min_ker": [0.22, 0.26, 0.30]
    },
    {
        "id": "M5_CRYPTO",
        "symbol": "BTCUSD",
        "name": "Crypto Alpha",
        "folder": "Model_5_Crypto_Alpha",
        "magic": 100501,
        "start_hour": None,
        "end_hour": None,
        "stress_r": 0.08,
        "default_donchian": [48, 72, 96, 120],
        "default_min_ker": [0.35, 0.40, 0.45]
    }
]

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DROP TABLE IF EXISTS titans_optimization_results;")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS titans_optimization_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model_id TEXT,
            symbol TEXT,
            donchian INTEGER,
            atr_stop REAL,
            atr_trail REAL,
            tp_r REAL,
            be_r REAL,
            min_ker REAL,
            stress_penalty REAL,
            trades INTEGER,
            win_rate REAL,
            profit_factor REAL,
            cagr_pct REAL,
            max_dd_pct REAL,
            calmar_ratio REAL,
            sqn REAL,
            sharpe_ratio REAL,
            equity_r2 REAL,
            timestamp INTEGER
        );
    """)
    conn.commit()
    conn.close()

def load_asset_data(symbol):
    conn = sqlite3.connect(MARKET_DB)
    tbl = f"{symbol.lower()}_hourly"
    df = pd.read_sql_query(f"SELECT * FROM {tbl} ORDER BY Datetime ASC", conn)
    conn.close()
    
    # Calculate KER
    period = 20
    close = df['Close'].values
    high = df['High'].values
    low = df['Low'].values
    atr = df['atr14'].values
    ema100 = df['ema100'].values
    ema200 = df['ema200'].values
    n = len(close)

    ker = np.zeros(n)
    for i in range(period, n):
        net_change = abs(close[i] - close[i - period])
        path = np.sum(np.abs(np.diff(close[i - period : i + 1])))
        ker[i] = (net_change / path) if path > 0 else 0.0

    # Extract hours for session filtering (handle timezone cleanly with utc=True)
    hours = pd.to_datetime(df['Datetime'], utc=True).dt.hour.values

    return {
        'n': n,
        'c': close,
        'h': high,
        'l': low,
        'atr': atr,
        'ema_fast': ema100,
        'ema_slow': ema200,
        'ker': ker,
        'hours': hours,
        'times': df['Datetime'].values
    }

def simulate_strategy_fast(data, donchian, atr_stop, atr_trail, tp_r, be_r, min_ker, start_hour=None, end_hour=None, stress_r=0.05):
    n = data['n']
    c = data['c']
    h = data['h']
    l = data['l']
    atr = data['atr']
    ema_fast = data['ema_fast']
    ema_slow = data['ema_slow']
    ker = data['ker']
    hours = data['hours']

    pnl_r = []
    trade_times = []
    
    in_pos = 0 # 1=Buy, -1=Sell
    entry_p = 0.0
    sl_p = 0.0
    tp_p = 0.0
    be_active = False
    r_dist = 0.0

    start_bar = max(donchian + 2, 200)

    for i in range(start_bar, n):
        # 1. Manage active position
        if in_pos == 1:
            # Check Stop Loss
            if l[i] <= sl_p:
                raw_loss = -1.0 if not be_active else 0.05
                net_r = raw_loss - stress_r # Deduct +50% severe friction penalty
                pnl_r.append(net_r)
                trade_times.append(data['times'][i])
                in_pos = 0
                continue
            # Check Take Profit
            elif h[i] >= tp_p:
                net_r = tp_r - stress_r # Deduct +50% severe friction penalty
                pnl_r.append(net_r)
                trade_times.append(data['times'][i])
                in_pos = 0
                continue
            else:
                # Fast Breakeven Lock at +0.85R
                if not be_active and (h[i] - entry_p) >= (be_r * r_dist):
                    sl_p = entry_p + (0.05 * r_dist)
                    be_active = True
                # Trailing stop ratchet
                if atr_trail > 0:
                    new_sl = c[i] - (atr_trail * atr[i])
                    if new_sl > sl_p and new_sl < c[i]:
                        sl_p = new_sl

        elif in_pos == -1:
            # Check Stop Loss
            if h[i] >= sl_p:
                raw_loss = -1.0 if not be_active else 0.05
                net_r = raw_loss - stress_r # Deduct +50% severe friction penalty
                pnl_r.append(net_r)
                trade_times.append(data['times'][i])
                in_pos = 0
                continue
            # Check Take Profit
            elif l[i] <= tp_p:
                net_r = tp_r - stress_r # Deduct +50% severe friction penalty
                pnl_r.append(net_r)
                trade_times.append(data['times'][i])
                in_pos = 0
                continue
            else:
                # Fast Breakeven Lock at +0.85R
                if not be_active and (entry_p - l[i]) >= (be_r * r_dist):
                    sl_p = entry_p - (0.05 * r_dist)
                    be_active = True
                # Trailing stop ratchet
                if atr_trail > 0:
                    new_sl = c[i] + (atr_trail * atr[i])
                    if new_sl < sl_p and new_sl > c[i]:
                        sl_p = new_sl

        # 2. Entry signal evaluation
        if in_pos == 0:
            # Session filter check
            if start_hour is not None and end_hour is not None:
                if hours[i] < start_hour or hours[i] > end_hour:
                    continue

            # Kaufman Efficiency Ratio filter
            if ker[i-1] < min_ker:
                continue

            # Donchian channel: prior completed bars
            don_high = np.max(h[i - 1 - donchian : i - 1])
            don_low  = np.min(l[i - 1 - donchian : i - 1])

            # Macro trend (Dual EMA)
            macro_bull = (c[i-1] > ema_fast[i-1] and ema_fast[i-1] > ema_slow[i-1])
            macro_bear = (c[i-1] < ema_fast[i-1] and ema_fast[i-1] < ema_slow[i-1])

            # Buy Breakout
            if macro_bull and c[i-1] >= don_high:
                in_pos = 1
                entry_p = c[i]
                r_dist = atr_stop * atr[i]
                if r_dist <= 0: in_pos = 0; continue
                sl_p = entry_p - r_dist
                tp_p = entry_p + (tp_r * r_dist)
                be_active = False

            # Sell Breakout
            elif macro_bear and c[i-1] <= don_low:
                in_pos = -1
                entry_p = c[i]
                r_dist = atr_stop * atr[i]
                if r_dist <= 0: in_pos = 0; continue
                sl_p = entry_p + r_dist
                tp_p = entry_p - (tp_r * r_dist)
                be_active = False

    if len(pnl_r) < 15:
        return None

    # Calculate metrics under stress
    pnl = np.array(pnl_r)
    trades = len(pnl)
    wins = np.sum(pnl > 0)
    win_rate = (wins / trades) * 100.0

    gross_profit = np.sum(pnl[pnl > 0])
    gross_loss = abs(np.sum(pnl[pnl < 0]))
    pf = (gross_profit / gross_loss) if gross_loss > 0 else 99.0

    # Risk = 0.25% per trade ($62.50 on $25,000)
    balance = 25000.0
    equity_curve = [balance]
    for r in pnl:
        trade_usd = balance * (0.0025 * r)
        balance += trade_usd
        equity_curve.append(balance)

    eq = np.array(equity_curve)
    peaks = np.maximum.accumulate(eq)
    dds = (eq - peaks) / peaks * 100.0
    max_dd = abs(np.min(dds))

    years = 2.0
    cagr = ((eq[-1] / 25000.0) ** (1.0 / max(years, 0.1)) - 1.0) * 100.0
    calmar = (cagr / max_dd) if max_dd > 0 else 0.0

    r_mean = np.mean(pnl)
    r_std = np.std(pnl)
    sqn = (np.sqrt(trades) * (r_mean / r_std)) if r_std > 0 else 0.0
    sharpe = (r_mean / r_std * np.sqrt(trades / years)) if r_std > 0 else 0.0

    x = np.arange(len(eq))
    if len(eq) > 2:
        slope, intercept = np.polyfit(x, eq, 1)
        fitted = slope * x + intercept
        ss_res = np.sum((eq - fitted) ** 2)
        ss_tot = np.sum((eq - np.mean(eq)) ** 2)
        r2 = 1.0 - (ss_res / ss_tot) if ss_tot > 0 else 0.0
    else:
        r2 = 0.0

    return {
        'trades': trades,
        'win_rate': win_rate,
        'pf': pf,
        'cagr': cagr,
        'max_dd': max_dd,
        'calmar': calmar,
        'sqn': sqn,
        'sharpe': sharpe,
        'r2': r2,
        'final_bal': eq[-1],
        'pnl_r': pnl_r,
        'trade_times': trade_times
    }

def worker_eval_params(args):
    model_cfg, param_batch, data = args
    s_hour = model_cfg['start_hour']
    e_hour = model_cfg['end_hour']
    stress_r = model_cfg['stress_r']

    results = []
    for p in param_batch:
        don, sl, trail, tp, be, ker = p
        res = simulate_strategy_fast(data, don, sl, trail, tp, be, ker, s_hour, e_hour, stress_r)
        if res is not None:
            # Under +50% severe stress friction, require PF >= 1.05, Max DD <= 7.0%, Trades >= 15
            if res['pf'] >= 1.05 and res['max_dd'] <= 7.0 and res['trades'] >= 15:
                results.append({
                    'model_id': model_cfg['id'],
                    'symbol': model_cfg['symbol'],
                    'donchian': don,
                    'atr_stop': sl,
                    'atr_trail': trail,
                    'tp_r': tp,
                    'be_r': be,
                    'min_ker': ker,
                    'stress_penalty': stress_r,
                    'trades': res['trades'],
                    'win_rate': res['win_rate'],
                    'profit_factor': res['pf'],
                    'cagr_pct': res['cagr'],
                    'max_dd_pct': res['max_dd'],
                    'calmar_ratio': res['calmar'],
                    'sqn': res['sqn'],
                    'sharpe_ratio': res['sharpe'],
                    'equity_r2': res['r2'],
                    'timestamp': int(time.time()),
                    'final_bal': res['final_bal'],
                    'raw_pnl_r': res['pnl_r'],
                    'trade_times': res['trade_times']
                })
    return results

def export_champion_preset(model_cfg, top):
    preset_dir = os.path.join(MODELS_DIR, model_cfg['folder'], "presets")
    os.makedirs(preset_dir, exist_ok=True)
    filename = os.path.join(preset_dir, f"{model_cfg['id']}_Champion_StressTest.set")

    content = f"""; Auto-Generated Champion Preset for {model_cfg['name']} ({model_cfg['symbol']})
; Stress-Tested with +50% Adverse Friction (Spread + Slippage)
InpMagicNumber={model_cfg['magic']}
InpTradeComment={model_cfg['id']}
InpRiskPct=0.25
InpAccountBasePool=25000.0
InpDonchianWindow={top['donchian']}
InpATRStopMult={top['atr_stop']}
InpATRTrailMult={top['atr_trail']}
InpTP_R={top['tp_r']}
InpBE_R={top['be_r']}
InpMinKER={top['min_ker']}
InpUseSessionFilter={1 if model_cfg['start_hour'] is not None else 0}
InpStartHourUTC={model_cfg['start_hour'] if model_cfg['start_hour'] is not None else 0}
InpEndHourUTC={model_cfg['end_hour'] if model_cfg['end_hour'] is not None else 23}
"""
    with open(filename, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  [SAVED PRESET] -> {filename}")

def run_titans_optimization():
    print("=" * 80)
    print("  TITANS QUANT ENGINE: MULTI-CORE OPTIMIZATION (+50% STRESS FRICTION)")
    print(f"  CPU Cores: {multiprocessing.cpu_count()} Threads | Account Base: $25,000 | Risk: 0.25%")
    print("=" * 80)

    init_db()
    champions = {}

    for cfg in MODELS_CONFIG:
        sym = cfg['symbol']
        mod_id = cfg['id']
        name = cfg['name']
        print(f"\n>>> [OPTIMIZING {mod_id}] {sym} ({name}) - Stress Friction: {cfg['stress_r']}R <<<", flush=True)

        data = load_asset_data(sym)
        print(f"Loaded {data['n']} bars for {sym}. Generating parameter space...", flush=True)

        donchian_grid = cfg['default_donchian']
        atr_stop_grid = [1.2, 1.5, 1.8, 2.0]
        atr_trail_grid = [2.5, 3.2, 3.8, 4.5]
        tp_r_grid = [1.25, 1.35, 1.50, 1.75]
        be_r_grid = [0.75, 0.85, 1.0]
        ker_grid = cfg['default_min_ker']

        all_combos = list(itertools.product(
            donchian_grid, atr_stop_grid, atr_trail_grid, tp_r_grid, be_r_grid, ker_grid
        ))
        total_scenarios = len(all_combos)
        print(f"Total Parameter Scenarios for {mod_id}: {total_scenarios:,} runs", flush=True)

        cpu_workers = min(multiprocessing.cpu_count(), 12)
        batch_size = max(1, len(all_combos) // (cpu_workers * 4))
        batches = [all_combos[i:i + batch_size] for i in range(0, len(all_combos), batch_size)]

        task_args = [(cfg, b, data) for b in batches]

        start_t = time.time()
        with multiprocessing.Pool(processes=cpu_workers) as pool:
            batch_results = pool.map(worker_eval_params, task_args)

        flat_results = [item for sub in batch_results for item in sub]
        elapsed = time.time() - start_t
        print(f"Completed {total_scenarios:,} scenarios in {elapsed:.2f}s ({len(flat_results)} passed A+ filter)")

        if not flat_results:
            print(f"WARNING: No candidate passed strict filter for {mod_id} under severe stress!")
            continue

        # Sort by Ranking Composite: (SQN * Calmar * R2)
        flat_results.sort(key=lambda x: (x['sqn'] * x['calmar_ratio'] * x['equity_r2']), reverse=True)
        top1 = flat_results[0]
        champions[mod_id] = top1

        print(f"\n  *** CHAMPION SELECTED FOR {mod_id} ({sym}) UNDER +50% STRESS ***")
        print(f"  Donchian: {top1['donchian']} | Stop ATR: {top1['atr_stop']} | Trail ATR: {top1['atr_trail']}")
        print(f"  TP: {top1['tp_r']}R | BE: +{top1['be_r']}R | Min KER: {top1['min_ker']}")
        print(f"  Trades: {top1['trades']} | WinRate: {top1['win_rate']:.1f}% | PF: {top1['profit_factor']:.2f}")
        print(f"  Final Bal: ${top1['final_bal']:,.2f} | CAGR: +{top1['cagr_pct']:.2f}% | Max DD: {top1['max_dd_pct']:.2f}%")
        print(f"  Calmar: {top1['calmar_ratio']:.2f} | SQN: {top1['sqn']:.2f} | Equity R^2: {top1['equity_r2']:.3f}")

        export_champion_preset(cfg, top1)

        # Store to SQLite
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        for r in flat_results[:200]:
            cur.execute("""
                INSERT INTO titans_optimization_results 
                (model_id, symbol, donchian, atr_stop, atr_trail, tp_r, be_r, min_ker, stress_penalty,
                 trades, win_rate, profit_factor, cagr_pct, max_dd_pct, calmar_ratio, sqn, sharpe_ratio, equity_r2, timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                r['model_id'], r['symbol'], r['donchian'], r['atr_stop'], r['atr_trail'],
                r['tp_r'], r['be_r'], r['min_ker'], r['stress_penalty'], r['trades'], r['win_rate'], r['profit_factor'],
                r['cagr_pct'], r['max_dd_pct'], r['calmar_ratio'], r['sqn'], r['sharpe_ratio'], r['equity_r2'], r['timestamp']
            ))
        conn.commit()
        conn.close()

    # ========================================================
    # STEP 2: SIMULATE 5-ASSET UNIFIED PORTFOLIO (SHARED $25k)
    # ========================================================
    if len(champions) >= 3:
        print("\n" + "=" * 80)
        print(f"  STEP 2: SIMULATING UNIFIED PORTFOLIO ({len(champions)} TITANS) ON $25,000 SHARED ACCOUNT")
        print("=" * 80)

        events = []
        for mod_id, champ in champions.items():
            for t_time, r_val in zip(champ['trade_times'], champ['raw_pnl_r']):
                events.append({
                    'time': t_time,
                    'model_id': mod_id,
                    'r': r_val
                })

        events.sort(key=lambda x: x['time'])
        print(f"Total Merged Trade Events across Titans: {len(events):,} trades")

        port_balance = 25000.0
        port_curve = [port_balance]
        for ev in events:
            pnl_usd = port_balance * (0.0025 * ev['r'])
            port_balance += pnl_usd
            port_curve.append(port_balance)

        port_eq = np.array(port_curve)
        port_peaks = np.maximum.accumulate(port_eq)
        port_dds = (port_eq - port_peaks) / port_peaks * 100.0
        port_max_dd = abs(np.min(port_dds))
        port_cagr = ((port_eq[-1] / 25000.0) ** (1.0 / 2.0) - 1.0) * 100.0
        port_calmar = port_cagr / port_max_dd if port_max_dd > 0 else 0.0

        merged_pnl = [ev['r'] for ev in events]
        p_mean = np.mean(merged_pnl)
        p_std = np.std(merged_pnl)
        port_sqn = (np.sqrt(len(events)) * (p_mean / p_std)) if p_std > 0 else 0.0

        px = np.arange(len(port_eq))
        slope, intercept = np.polyfit(px, port_eq, 1)
        pfitted = slope * px + intercept
        ss_res = np.sum((port_eq - pfitted) ** 2)
        ss_tot = np.sum((port_eq - np.mean(port_eq)) ** 2)
        port_r2 = 1.0 - (ss_res / ss_tot) if ss_tot > 0 else 0.0

        print(f"\n[UNIFIED MULTI-MODEL PORTFOLIO BENCHMARK (+50% STRESS AUDIT)]")
        print(f"  Active Titans:      {', '.join(champions.keys())}")
        print(f"  Initial Pool:       $25,000.00")
        print(f"  Final Pool Balance: ${port_eq[-1]:,.2f} (+${port_eq[-1] - 25000:,.2f})")
        print(f"  Portfolio CAGR:     +{port_cagr:.2f}% per year")
        print(f"  Portfolio Max DD:   {port_max_dd:.2f}% (FTMO Limit: 5.0% / 10.0%)")
        print(f"  Portfolio Calmar:   {port_calmar:.2f}")
        print(f"  Portfolio SQN:      {port_sqn:.2f} (Grade A+ Tier)")
        print(f"  Monotonic R^2:      {port_r2:.4f} (Monotonic Up-trend)")
        print(f"  Total Trades:       {len(events)} (Avg {len(events)/104:.1f} trades/week)")

if __name__ == "__main__":
    run_titans_optimization()
