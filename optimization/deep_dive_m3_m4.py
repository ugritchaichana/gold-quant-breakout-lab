import sqlite3
import numpy as np
import pandas as pd
from itertools import product
from multiprocessing import Pool, cpu_count
import time

DB_PATH = "data/market_history.db"

def load_data(symbol, tf="daily"):
    conn = sqlite3.connect(DB_PATH)
    table = f"{symbol.lower()}_{tf}"
    time_col = "Date" if tf == "daily" else "Datetime"
    df = pd.read_sql_query(f"SELECT * FROM {table} ORDER BY [{time_col}] ASC", conn)
    conn.close()

    c = df['Close'].values
    h = df['High'].values
    l = df['Low'].values
    atr = df['atr14'].values
    n = len(c)

    # Calculate multiple EMAs
    ema20 = df['Close'].ewm(span=20).mean().values
    ema50 = df['Close'].ewm(span=50).mean().values
    ema100 = df['Close'].ewm(span=100).mean().values
    ema200 = df['Close'].ewm(span=200).mean().values

    # Calculate KER for 10 and 20 periods
    period = 20
    ker20 = np.zeros(n)
    for i in range(period, n):
        net_change = abs(c[i] - c[i - period])
        path = np.sum(np.abs(np.diff(c[i - period : i + 1])))
        ker20[i] = (net_change / path) if path > 0 else 0.0

    return {
        'n': n, 'c': c, 'h': h, 'l': l, 'atr': atr,
        'ema20': ema20, 'ema50': ema50, 'ema100': ema100, 'ema200': ema200,
        'ker20': ker20, 'times': df[time_col].values
    }

def evaluate_scenario(args):
    data, don, sl_m, trail_m, tp_r, be_r, min_ker, ema_type, stress_r = args
    n = data['n']
    c = data['c']
    h = data['h']
    l = data['l']
    atr = data['atr']
    ker = data['ker20']

    if ema_type == '50_200':
        ema_f = data['ema50']
        ema_s = data['ema200']
    elif ema_type == '20_50':
        ema_f = data['ema20']
        ema_s = data['ema50']
    elif ema_type == '50_100':
        ema_f = data['ema50']
        ema_s = data['ema100']
    else:
        ema_f = data['ema20']
        ema_s = data['ema100']

    pnl_r = []
    in_pos = 0
    entry_p = sl_p = tp_p = r_dist = 0.0
    be_active = False
    start_bar = max(don + 2, 200)

    for i in range(start_bar, n):
        if in_pos == 1:
            if l[i] <= sl_p:
                raw_loss = -1.0 if not be_active else 0.05
                pnl_r.append(raw_loss - stress_r)
                in_pos = 0; continue
            elif h[i] >= tp_p:
                pnl_r.append(tp_r - stress_r)
                in_pos = 0; continue
            else:
                if not be_active and (h[i] - entry_p) >= (be_r * r_dist):
                    sl_p = entry_p + (0.05 * r_dist)
                    be_active = True
                if trail_m > 0:
                    new_sl = c[i] - (trail_m * atr[i])
                    if new_sl > sl_p and new_sl < c[i]: sl_p = new_sl

        elif in_pos == -1:
            if h[i] >= sl_p:
                raw_loss = -1.0 if not be_active else 0.05
                pnl_r.append(raw_loss - stress_r)
                in_pos = 0; continue
            elif l[i] <= tp_p:
                pnl_r.append(tp_r - stress_r)
                in_pos = 0; continue
            else:
                if not be_active and (entry_p - l[i]) >= (be_r * r_dist):
                    sl_p = entry_p - (0.05 * r_dist)
                    be_active = True
                if trail_m > 0:
                    new_sl = c[i] + (trail_m * atr[i])
                    if new_sl < sl_p and new_sl > c[i]: sl_p = new_sl

        if in_pos == 0:
            if ker[i-1] < min_ker: continue
            don_h = np.max(h[i - 1 - don : i - 1])
            don_l = np.min(l[i - 1 - don : i - 1])
            bull = (c[i-1] > ema_f[i-1] and ema_f[i-1] > ema_s[i-1])
            bear = (c[i-1] < ema_f[i-1] and ema_f[i-1] < ema_s[i-1])

            if bull and c[i-1] >= don_h:
                in_pos = 1; entry_p = c[i]; r_dist = sl_m * atr[i]
                if r_dist <= 0: in_pos = 0; continue
                sl_p = entry_p - r_dist; tp_p = entry_p + (tp_r * r_dist); be_active = False

            elif bear and c[i-1] <= don_l:
                in_pos = -1; entry_p = c[i]; r_dist = sl_m * atr[i]
                if r_dist <= 0: in_pos = 0; continue
                sl_p = entry_p + r_dist; tp_p = entry_p - (tp_r * r_dist); be_active = False

    if len(pnl_r) < 25: return None
    pnl = np.array(pnl_r)
    trades = len(pnl)
    wins = np.sum(pnl > 0)
    wr = (wins / trades) * 100.0
    gp = np.sum(pnl[pnl > 0])
    gl = abs(np.sum(pnl[pnl < 0]))
    pf = (gp / gl) if gl > 0 else 99.0

    # Curve calculation at 1.0% risk
    bal = 25000.0
    curve = [bal]
    for r in pnl:
        bal += bal * (0.01 * r)
        curve.append(bal)

    eq = np.array(curve)
    peaks = np.maximum.accumulate(eq)
    dds = (eq - peaks) / peaks * 100.0
    max_dd = abs(np.min(dds))
    gain = (eq[-1] / 25000.0 - 1.0) * 100.0
    cagr = ((eq[-1] / 25000.0) ** (1.0 / 10.75) - 1.0) * 100.0
    calmar = cagr / max_dd if max_dd > 0 else 0.0
    sqn = np.sqrt(trades) * (np.mean(pnl) / np.std(pnl)) if np.std(pnl) > 0 else 0.0

    # Linearity R2
    x = np.arange(len(eq))
    r2 = 0.0
    if np.std(eq) > 0 and np.std(x) > 0:
        r2 = float(np.corrcoef(x, eq)[0, 1] ** 2)

    return {
        'don': don, 'sl_m': sl_m, 'trail_m': trail_m, 'tp_r': tp_r,
        'be_r': be_r, 'min_ker': min_ker, 'ema_type': ema_type,
        'trades': trades, 'wr': wr, 'pf': pf, 'max_dd': max_dd,
        'cagr': cagr, 'calmar': calmar, 'sqn': sqn, 'r2': r2,
        'final_bal': eq[-1]
    }

def run_deep_dive(symbol, stress_r=0.045):
    print(f"\n=======================================================")
    print(f"   STARTING DEEP DIVE RESEARCH FOR {symbol.upper()} (10.75 YEARS)")
    print(f"=======================================================")
    data = load_data(symbol, "daily")
    
    # Grid with wider search space and higher KER to eliminate whipsaws
    donchian_grid = [10, 15, 20, 25, 30, 35, 40, 50, 60]
    sl_grid = [1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.5]
    trail_grid = [2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0]
    tp_grid = [1.25, 1.50, 1.75, 2.00, 2.50, 3.00]
    be_grid = [0.70, 0.85, 1.00, 1.15]
    ker_grid = [0.15, 0.20, 0.25, 0.30, 0.35, 0.40] # Higher KER!
    ema_grid = ['50_200', '20_50', '50_100', '20_100']

    # Sample smart combinations
    tasks = []
    for don, sl, trail, tp, be, ker, ema in product(
        donchian_grid, sl_grid, trail_grid, tp_grid, be_grid, ker_grid, ema_grid
    ):
        if trail < sl: continue # trail should generally be >= stop
        tasks.append((data, don, sl, trail, tp, be, ker, ema, stress_r))

    print(f"Total parameter combinations to explore for {symbol}: {len(tasks):,}")
    t0 = time.time()
    
    with Pool(processes=12) as pool:
        results = pool.map(evaluate_scenario, tasks, chunksize=500)
    
    valid = [r for r in results if r is not None]
    print(f"Evaluated in {time.time()-t0:.2f}s. Valid candidates (>=25 trades): {len(valid):,}")

    # Sort by SQN and R2
    valid.sort(key=lambda x: (x['sqn'] * 0.5 + x['pf'] * 0.3 + x['r2'] * 2.0 - x['max_dd'] * 0.1), reverse=True)

    print("\n--- TOP 10 STRATEGIES BY INSTITUTIONAL SCORE ---")
    header = f"{'Rank':<4} | {'Don':<3} | {'SL':<4} | {'Trail':<5} | {'TP':<4} | {'BE':<4} | {'KER':<4} | {'EMA':<6} | {'Trades':<6} | {'WR%':<5} | {'PF':<5} | {'MaxDD%':<6} | {'SQN':<5} | {'R2':<5}"
    print(header)
    print("-" * len(header))
    for idx, r in enumerate(valid[:10]):
        print(f"{idx+1:<4} | {r['don']:<3} | {r['sl_m']:<4.1f} | {r['trail_m']:<5.1f} | {r['tp_r']:<4.2f} | {r['be_r']:<4.2f} | {r['min_ker']:<4.2f} | {r['ema_type']:<6} | {r['trades']:<6} | {r['wr']:<5.1f} | {r['pf']:<5.2f} | {r['max_dd']:<6.2f} | {r['sqn']:<5.2f} | {r['r2']:<5.3f}")

    return valid[0] if valid else None

if __name__ == '__main__':
    top_fx = run_deep_dive('gbpjpy', stress_r=0.045)
    top_oil = run_deep_dive('usoil', stress_r=0.045)
