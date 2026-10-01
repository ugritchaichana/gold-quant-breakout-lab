import sqlite3
import numpy as np
import pandas as pd
from itertools import product
from multiprocessing import Pool

conn = sqlite3.connect("data/market_history.db")
df = pd.read_sql_query("SELECT * FROM gbpjpy_daily ORDER BY Date ASC", conn)
conn.close()

c = df['Close'].values
h = df['High'].values
l = df['Low'].values
atr = df['atr14'].values
n = len(c)

# Calculate indicators
ema20 = df['Close'].ewm(span=20).mean().values
ema50 = df['Close'].ewm(span=50).mean().values
ema100 = df['Close'].ewm(span=100).mean().values
ema200 = df['Close'].ewm(span=200).mean().values

# RSI
delta = np.diff(c, prepend=c[0])
gain = np.where(delta > 0, delta, 0.0)
loss = np.where(delta < 0, -delta, 0.0)
avg_gain = pd.Series(gain).rolling(14).mean().values
avg_loss = pd.Series(loss).rolling(14).mean().values
rs = np.divide(avg_gain, avg_loss, out=np.zeros_like(avg_gain), where=avg_loss != 0)
rsi = 100 - (100 / (1 + rs))

# KER
period = 10
ker10 = np.zeros(n)
for i in range(period, n):
    net_change = abs(c[i] - c[i - period])
    path = np.sum(np.abs(np.diff(c[i - period : i + 1])))
    ker10[i] = (net_change / path) if path > 0 else 0.0

data = {
    'n': n, 'c': c, 'h': h, 'l': l, 'atr': atr,
    'ema20': ema20, 'ema50': ema50, 'ema100': ema100, 'ema200': ema200,
    'rsi': rsi, 'ker10': ker10, 'times': df['Date'].values
}

def sim_gbpjpy(params):
    don, sl_m, trail_m, tp_r, be_r, min_ker, rsi_filter, ema_mode = params
    pnl_r = []
    in_pos = 0
    entry_p = sl_p = tp_p = r_dist = 0.0
    be_active = False
    start_bar = max(don + 2, 200)

    for i in range(start_bar, n):
        if in_pos == 1:
            if l[i] <= sl_p:
                raw_loss = -1.0 if not be_active else 0.05
                pnl_r.append(raw_loss - 0.045)
                in_pos = 0; continue
            elif h[i] >= tp_p:
                pnl_r.append(tp_r - 0.045)
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
                pnl_r.append(raw_loss - 0.045)
                in_pos = 0; continue
            elif l[i] <= tp_p:
                pnl_r.append(tp_r - 0.045)
                in_pos = 0; continue
            else:
                if not be_active and (entry_p - l[i]) >= (be_r * r_dist):
                    sl_p = entry_p - (0.05 * r_dist)
                    be_active = True
                if trail_m > 0:
                    new_sl = c[i] + (trail_m * atr[i])
                    if new_sl < sl_p and new_sl > c[i]: sl_p = new_sl

        if in_pos == 0:
            if ker10[i-1] < min_ker: continue
            don_h = np.max(h[i - 1 - don : i - 1])
            don_l = np.min(l[i - 1 - don : i - 1])

            if ema_mode == '20_50':
                bull = (c[i-1] > ema20[i-1] and ema20[i-1] > ema50[i-1])
                bear = (c[i-1] < ema20[i-1] and ema20[i-1] < ema50[i-1])
            elif ema_mode == '50_100':
                bull = (c[i-1] > ema50[i-1] and ema50[i-1] > ema100[i-1])
                bear = (c[i-1] < ema50[i-1] and ema50[i-1] < ema100[i-1])
            elif ema_mode == '200_only':
                bull = (c[i-1] > ema200[i-1])
                bear = (c[i-1] < ema200[i-1])
            else:
                bull = (c[i-1] > ema50[i-1] and ema50[i-1] > ema200[i-1])
                bear = (c[i-1] < ema50[i-1] and ema50[i-1] < ema200[i-1])

            if rsi_filter:
                bull = bull and (rsi[i-1] > 50 and rsi[i-1] < 75)
                bear = bear and (rsi[i-1] < 50 and rsi[i-1] > 25)

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

    bal = 25000.0
    curve = [bal]
    for r in pnl:
        bal += bal * (0.01 * r)
        curve.append(bal)

    eq = np.array(curve)
    peaks = np.maximum.accumulate(eq)
    dds = (eq - peaks) / peaks * 100.0
    max_dd = abs(np.min(dds))
    cagr = ((eq[-1] / 25000.0) ** (1.0 / 10.75) - 1.0) * 100.0
    sqn = np.sqrt(trades) * (np.mean(pnl) / np.std(pnl)) if np.std(pnl) > 0 else 0.0

    x = np.arange(len(eq))
    r2 = 0.0
    if np.std(eq) > 0 and np.std(x) > 0:
        r2 = float(np.corrcoef(x, eq)[0, 1] ** 2)

    return {
        'don': don, 'sl_m': sl_m, 'trail_m': trail_m, 'tp_r': tp_r,
        'be_r': be_r, 'min_ker': min_ker, 'rsi': rsi_filter, 'ema': ema_mode,
        'trades': trades, 'wr': wr, 'pf': pf, 'max_dd': max_dd,
        'sqn': sqn, 'r2': r2, 'final_bal': eq[-1]
    }

if __name__ == '__main__':
    don_grid = [5, 6, 7, 8, 9, 10, 12]
    sl_grid = [0.8, 1.0, 1.2, 1.4]
    trail_grid = [1.5, 2.0, 2.5, 3.0]
    tp_grid = [1.25, 1.40, 1.50, 1.60, 1.75, 2.00]
    be_grid = [0.60, 0.70, 0.80, 0.90]
    ker_grid = [0.08, 0.10, 0.12, 0.15, 0.20]
    rsi_grid = [False, True]
    ema_grid = ['20_50', '50_100', '200_only', '50_200']

    tasks = list(product(don_grid, sl_grid, trail_grid, tp_grid, be_grid, ker_grid, rsi_grid, ema_grid))
    print(f"Testing {len(tasks):,} combinations for GBPJPY...")

    with Pool(processes=12) as pool:
        res = pool.map(sim_gbpjpy, tasks, chunksize=500)

    valid = [r for r in res if r is not None and r['pf'] > 1.3]
    valid.sort(key=lambda x: (x['sqn'] * 0.4 + x['pf'] * 0.3 + x['r2'] * 2.0 - x['max_dd'] * 0.1), reverse=True)

    print(f"\nTotal qualifying setups: {len(valid):,}")
    header = f"{'Rank':<4} | {'Don':<3} | {'SL':<3} | {'Trl':<3} | {'TP':<4} | {'BE':<4} | {'KER':<4} | {'RSI':<5} | {'EMA':<8} | {'Trades':<6} | {'WR%':<5} | {'PF':<5} | {'MaxDD%':<6} | {'SQN':<5} | {'R2':<5}"
    print(header)
    print("-" * len(header))
    for i, r in enumerate(valid[:15]):
        print(f"{i+1:<4} | {r['don']:<3} | {r['sl_m']:<3.1f} | {r['trail_m']:<3.1f} | {r['tp_r']:<4.2f} | {r['be_r']:<4.2f} | {r['min_ker']:<4.2f} | {str(r['rsi']):<5} | {r['ema']:<8} | {r['trades']:<6} | {r['wr']:<5.1f} | {r['pf']:<5.2f} | {r['max_dd']:<6.2f} | {r['sqn']:<5.2f} | {r['r2']:<5.3f}")
