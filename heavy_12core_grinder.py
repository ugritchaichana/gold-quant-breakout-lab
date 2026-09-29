"""
HEAVY MULTI-CORE 12-THREAD CONTINUOUS OPTIMIZATION GRINDER
Maximizes AMD Ryzen 5 5600X CPU usage across all 12 threads.
Runs deep multi-parameter search, Monte Carlo permutations, and Walk-Forward tests.
"""

import os
import sys
import time
import itertools
import multiprocessing
import numpy as np
import pandas as pd

def simulate_candidate(args):
    """
    Heavy simulation worker. Runs backtest + Monte Carlo on candidate parameters.
    """
    (p, closes, highs, lows, atr, ema200, ema800, rsi, is_len, total_len) = args

    # In-Sample Simulation
    res_is = run_fast_core(closes, highs, lows, atr, ema200, ema800, rsi, 0, is_len, p)
    if res_is is None or res_is['cagr'] < 0.50 or res_is['dd'] < -0.22:
        return None

    # Out-of-Sample Forward Test
    res_oos = run_fast_core(closes, highs, lows, atr, ema200, ema800, rsi, is_len, total_len, p)
    if res_oos is None or res_oos['cagr'] < 0.40 or res_oos['dd'] < -0.20:
        return None

    # Full Period Simulation
    res_full = run_fast_core(closes, highs, lows, atr, ema200, ema800, rsi, 0, total_len, p)
    if res_full is None:
        return None

    # 500x Monte Carlo permutation stress test on trade PnL
    pnl = np.array(res_full['pnl'])
    if len(pnl) < 15:
        return None

    mc_dds = []
    for _ in range(500):
        sample = np.random.choice(pnl, size=len(pnl), replace=True)
        curve = 10000.0 + np.cumsum(sample)
        cmax = np.maximum.accumulate(curve)
        dd = (curve - cmax) / np.maximum(cmax, 1.0)
        mc_dds.append(dd.min())

    median_mc_dd = float(np.percentile(mc_dds, 50))
    p95_mc_dd = float(np.percentile(mc_dds, 5))

    return {
        'params': p,
        'is_cagr': res_is['cagr'],
        'is_dd': res_is['dd'],
        'oos_cagr': res_oos['cagr'],
        'oos_dd': res_oos['dd'],
        'full_cagr': res_full['cagr'],
        'full_dd': res_full['dd'],
        'full_pf': res_full['pf'],
        'mc_median_dd': median_mc_dd,
        'mc_p95_dd': p95_mc_dd,
        'trades': res_full['trades']
    }

def run_fast_core(c_arr, h_arr, l_arr, atr_arr, ema200_arr, ema800_arr, rsi_arr, start, end, p):
    c = c_arr[start:end]
    h = h_arr[start:end]
    l = l_arr[start:end]
    atr = atr_arr[start:end]
    ema200 = ema200_arr[start:end]
    ema800 = ema800_arr[start:end]
    rsi = rsi_arr[start:end]
    n = len(c)

    if n < 100:
        return None

    balance = 10000.0
    equity = balance
    cummax = balance
    max_dd = 0.0

    basket = [] # (type: 1 buy, -1 sell, entry, lot, tp)
    closed_pnl = []

    grid_step_atr = p['grid_step_atr']
    tp_atr = p['tp_atr']
    max_orders = p['max_orders']
    lot_mult = p['lot_mult']
    base_risk = p['base_risk']
    basket_tp_usd = p['basket_tp_usd']
    rsi_buy = p['rsi_buy']
    rsi_sell = p['rsi_sell']

    for i in range(1, n):
        curr_c = c[i]
        curr_h = h[i]
        curr_l = l[i]
        curr_atr = atr[i]
        curr_rsi = rsi[i]

        if basket:
            b_type = basket[0][0]
            float_pnl = 0.0
            for pos in basket:
                if pos[0] == 1:
                    float_pnl += pos[2] * (curr_c - pos[1]) - (pos[2] * 0.40)
                else:
                    float_pnl += pos[2] * (pos[1] - curr_c) - (pos[2] * 0.40)

            equity = balance + float_pnl
            if equity > cummax:
                cummax = equity
            dd = (equity - cummax) / cummax
            if dd < max_dd:
                max_dd = dd

            hit_tp = float_pnl >= basket_tp_usd or (b_type == 1 and curr_h >= basket[0][3]) or (b_type == -1 and curr_l <= basket[0][3])
            hit_sl = (float_pnl / max(balance, 1.0)) <= -0.18

            if hit_tp or hit_sl:
                balance += float_pnl
                equity = balance
                closed_pnl.append(float_pnl)
                basket.clear()

        if not basket:
            is_bull = curr_c > ema200_arr[i] and curr_c > ema800_arr[i]
            is_bear = curr_c < ema200_arr[i] and curr_c < ema800_arr[i]

            if is_bull and curr_rsi <= rsi_buy:
                lot = max(0.01, min(10.0, round((equity * base_risk) / (2.0 * curr_atr * 100.0), 2)))
                tp = curr_c + (tp_atr * curr_atr)
                basket.append((1, curr_c + 0.20, lot, tp))
            elif is_bear and curr_rsi >= rsi_sell:
                lot = max(0.01, min(10.0, round((equity * base_risk) / (2.0 * curr_atr * 100.0), 2)))
                tp = curr_c - (tp_atr * curr_atr)
                basket.append((-1, curr_c - 0.20, lot, tp))

        elif len(basket) < max_orders:
            b_type = basket[0][0]
            step = grid_step_atr * curr_atr
            if b_type == 1:
                lowest_p = min(pos[1] for pos in basket)
                if curr_c <= (lowest_p - step):
                    next_lot = max(0.01, min(15.0, round(basket[-1][2] * lot_mult, 2)))
                    tp = curr_c + (tp_atr * curr_atr)
                    basket.append((1, curr_c + 0.20, next_lot, tp))
            elif b_type == -1:
                highest_p = max(pos[1] for pos in basket)
                if curr_c >= (highest_p + step):
                    next_lot = max(0.01, min(15.0, round(basket[-1][2] * lot_mult, 2)))
                    tp = curr_c - (tp_atr * curr_atr)
                    basket.append((-1, curr_c - 0.20, next_lot, tp))

    years = max(0.1, (n / 24.0) / 365.25)
    cagr = (balance / 10000.0) ** (1.0 / years) - 1.0 if balance > 0 else -1.0
    wins = [x for x in closed_pnl if x > 0]
    losses = [x for x in closed_pnl if x < 0]
    pf = sum(wins) / abs(sum(losses)) if losses else (999.0 if wins else 0.0)

    return {
        'cagr': cagr,
        'dd': max_dd,
        'pf': pf,
        'trades': len(closed_pnl),
        'pnl': closed_pnl
    }

def main():
    log_file = r"C:\Users\Booth\quant_ea_lab\heavy_optimizer_progress.log"
    with open(log_file, "w", encoding="utf-8") as f:
        f.write("HEAVY OPTIMIZER STARTED: Pinned across all 12 CPU cores.\n")

    df = pd.read_csv(r"C:\Users\Booth\quant_ea_lab\data\gold_hourly.csv", parse_dates=['Datetime'], index_col='Datetime')
    high_low = df['High'] - df['Low']
    high_close = (df['High'] - df['Close'].shift(1)).abs()
    low_close = (df['Low'] - df['Close'].shift(1)).abs()
    tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    df['atr14'] = tr.rolling(14).mean()

    delta = df['Close'].diff()
    gain = delta.where(delta > 0, 0.0).rolling(14).mean()
    loss = (-delta.where(delta < 0, 0.0)).rolling(14).mean()
    rs = gain / (loss + 1e-9)
    df['rsi14'] = 100.0 - (100.0 / (1.0 + rs))

    df['ema200'] = df['Close'].ewm(span=200, adjust=False).mean()
    df['ema800'] = df['Close'].ewm(span=800, adjust=False).mean()
    df = df.dropna()

    closes = df['Close'].values
    highs = df['High'].values
    lows = df['Low'].values
    atr = df['atr14'].values
    ema200 = df['ema200'].values
    ema800 = df['ema800'].values
    rsi = df['rsi14'].values

    total_len = len(closes)
    is_len = int(total_len * 0.80)

    # Dense parameter matrix for high computational load
    param_grid = {
        'grid_step_atr': [0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0],
        'tp_atr': [1.5, 2.0, 2.5, 3.0, 3.5],
        'max_orders': [2, 3, 4, 5, 6],
        'lot_mult': [1.10, 1.20, 1.25, 1.30, 1.35],
        'base_risk': [0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10],
        'basket_tp_usd': [100.0, 150.0, 200.0, 250.0, 350.0, 500.0],
        'rsi_pairs': [(30.0, 70.0), (35.0, 65.0), (40.0, 60.0), (25.0, 75.0)]
    }

    combos = []
    for g, tp, mo, lm, br, btp, (rb, rs_val) in itertools.product(
        param_grid['grid_step_atr'], param_grid['tp_atr'], param_grid['max_orders'],
        param_grid['lot_mult'], param_grid['base_risk'], param_grid['basket_tp_usd'],
        param_grid['rsi_pairs']
    ):
        combos.append({
            'grid_step_atr': g, 'tp_atr': tp, 'max_orders': mo, 'lot_mult': lm,
            'base_risk': br, 'basket_tp_usd': btp, 'rsi_buy': rb, 'rsi_sell': rs_val
        })

    total_combos = len(combos)
    num_workers = multiprocessing.cpu_count()

    msg = f"LAUNCHING 12 WORKERS ACROSS {total_combos} COMBINATIONS WITH MONTE CARLO STRESS TEST.\n"
    print(msg)
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(msg)

    args_list = [
        (c, closes, highs, lows, atr, ema200, ema800, rsi, is_len, total_len)
        for c in combos
    ]

    t0 = time.time()
    with multiprocessing.Pool(processes=num_workers) as pool:
        results = pool.map(simulate_candidate, args_list, chunksize=100)

    elapsed = time.time() - t0
    qualified = [r for r in results if r is not None]
    
    summary_msg = f"OPTIMIZATION FINISHED IN {elapsed:.1f}s ({elapsed/60.0:.2f} mins). Total Qualified: {len(qualified)}\n"
    print(summary_msg)
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(summary_msg)

    if qualified:
        qualified.sort(key=lambda x: x['full_cagr'], reverse=True)
        top_df = pd.DataFrame([{
            'grid_step_atr': q['params']['grid_step_atr'],
            'tp_atr': q['params']['tp_atr'],
            'max_orders': q['params']['max_orders'],
            'lot_mult': q['params']['lot_mult'],
            'base_risk': q['params']['base_risk'],
            'basket_tp_usd': q['params']['basket_tp_usd'],
            'full_cagr': q['full_cagr'],
            'full_dd': q['full_dd'],
            'full_pf': q['full_pf'],
            'mc_median_dd': q['mc_median_dd'],
            'mc_p95_dd': q['mc_p95_dd'],
            'trades': q['trades']
        } for q in qualified[:50]])
        
        top_df.to_csv(r"C:\Users\Booth\quant_ea_lab\heavy_optimizer_results.csv", index=False)
        print("Results successfully saved to heavy_optimizer_results.csv")

if __name__ == "__main__":
    main()
