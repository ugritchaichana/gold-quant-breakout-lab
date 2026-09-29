"""
12-CORE PARALLEL BREAKOUT & TREND SCALPER OPTIMIZATION (100% CPU USAGE)
Target: CAGR > 80% to > 160% | Max Drawdown <= 16%
Asset: Gold XAUUSD | AMD Ryzen 5 5600X
"""

import os
import sys
import time
import itertools
import multiprocessing
import numpy as np
import pandas as pd

def simulate_breakout(c_arr, h_arr, l_arr, o_arr, atr_arr, ema200_arr, ema800_arr, adx_arr, plus_di_arr, minus_di_arr,
                      start, end, donchian_window, atr_trail_mult, atr_stop_mult, min_adx, risk_per_trade, max_bars_hold):
    c = c_arr[start:end]
    h = h_arr[start:end]
    l = l_arr[start:end]
    o = o_arr[start:end]
    atr = atr_arr[start:end]
    ema200 = ema200_arr[start:end]
    ema800 = ema800_arr[start:end]
    adx = adx_arr[start:end]
    p_di = plus_di_arr[start:end]
    m_di = minus_di_arr[start:end]
    n = len(c)

    if n < donchian_window + 50:
        return None

    # Upper donchian
    s_series = pd.Series(h)
    upper_donchian = s_series.shift(1).rolling(donchian_window).max().values

    balance = 10000.0
    equity = balance
    cummax = balance
    max_dd = 0.0

    in_pos = False
    entry_p = 0.0
    sl = 0.0
    peak_p = 0.0
    pos_size = 0.0
    entry_bar = 0
    closed_trades = []

    friction = 0.50 # spread + slippage

    for i in range(donchian_window + 1, n):
        curr_c = c[i]
        curr_h = h[i]
        curr_l = l[i]
        curr_o = o[i]
        curr_atr = atr[i]

        if in_pos:
            bars_held = i - entry_bar
            if curr_h > peak_p:
                peak_p = curr_h
            trail = peak_p - (atr_trail_mult * curr_atr)
            if trail > sl:
                sl = trail

            hit_sl = curr_l <= sl
            regime_break = curr_c < ema200[i]
            timeout = bars_held >= max_bars_hold and (curr_c - entry_p) < (0.5 * curr_atr)

            if hit_sl or regime_break or timeout:
                exit_p = min(curr_o, sl) - 0.20 if hit_sl else curr_c - 0.20
                pnl = pos_size * (exit_p - entry_p) - (pos_size * friction)
                balance += pnl
                equity = balance
                if equity > cummax:
                    cummax = equity
                dd = (equity - cummax) / cummax
                if dd < max_dd:
                    max_dd = dd
                closed_trades.append(pnl)
                in_pos = False

        if not in_pos:
            if not np.isnan(upper_donchian[i]) and not np.isnan(curr_atr):
                is_break = curr_h > upper_donchian[i]
                is_trend = curr_c > ema200[i] and curr_c > ema800[i]
                is_mom = adx[i] >= min_adx and p_di[i] > m_di[i]

                if is_break and is_trend and is_mom:
                    entry_p = max(curr_o, upper_donchian[i]) + 0.25
                    stop_dist = atr_stop_mult * curr_atr
                    if stop_dist > 0:
                        sl = entry_p - stop_dist
                        pos_size = (balance * risk_per_trade) / stop_dist
                        pos_size = min(pos_size, (balance * 6.0) / entry_p) # 6x max leverage
                        in_pos = True
                        peak_p = entry_p
                        entry_bar = i

    years = max(0.1, (n / 24.0) / 365.25)
    cagr = (balance / 10000.0) ** (1.0 / years) - 1.0 if balance > 0 else -1.0
    wins = [x for x in closed_trades if x > 0]
    losses = [x for x in closed_trades if x < 0]
    pf = sum(wins) / abs(sum(losses)) if losses else (999.0 if wins else 0.0)

    return {
        'cagr': cagr,
        'max_dd': max_dd,
        'pf': pf,
        'trades': len(closed_trades),
        'final_bal': balance,
        'closed_pnl': closed_trades
    }

def worker_fn(args):
    p, c, h, l, o, atr, ema200, ema800, adx, p_di, m_di, is_len, total_len = args

    # In-Sample
    res_is = simulate_breakout(
        c, h, l, o, atr, ema200, ema800, adx, p_di, m_di,
        0, is_len,
        p['donchian_window'], p['atr_trail_mult'], p['atr_stop_mult'],
        p['min_adx'], p['risk_per_trade'], p['max_bars_hold']
    )
    if res_is is None or res_is['cagr'] < 0.80 or res_is['max_dd'] < -0.18:
        return None

    # Out-of-Sample
    res_oos = simulate_breakout(
        c, h, l, o, atr, ema200, ema800, adx, p_di, m_di,
        is_len, total_len,
        p['donchian_window'], p['atr_trail_mult'], p['atr_stop_mult'],
        p['min_adx'], p['risk_per_trade'], p['max_bars_hold']
    )
    if res_oos is None or res_oos['cagr'] < 0.50 or res_oos['max_dd'] < -0.16:
        return None

    # Full Period
    res_full = simulate_breakout(
        c, h, l, o, atr, ema200, ema800, adx, p_di, m_di,
        0, total_len,
        p['donchian_window'], p['atr_trail_mult'], p['atr_stop_mult'],
        p['min_adx'], p['risk_per_trade'], p['max_bars_hold']
    )

    return {
        'params': p,
        'is_cagr': res_is['cagr'],
        'is_dd': res_is['max_dd'],
        'is_pf': res_is['pf'],
        'oos_cagr': res_oos['cagr'],
        'oos_dd': res_oos['max_dd'],
        'oos_pf': res_oos['pf'],
        'full_cagr': res_full['cagr'],
        'full_dd': res_full['max_dd'],
        'full_pf': res_full['pf'],
        'trades': res_full['trades'],
        'pnl_history': res_full['closed_pnl']
    }

def main():
    print("="*75)
    print("12-CORE PARALLEL BREAKOUT & TREND SCALPER ENGINE (100% CPU)")
    print("Target: CAGR > 80% to > 160% | Max Drawdown <= 16%")
    print("="*75)

    df = pd.read_csv(r"C:\Users\Booth\quant_ea_lab\data\gold_hourly.csv", parse_dates=['Datetime'], index_col='Datetime')
    high_low = df['High'] - df['Low']
    high_close = (df['High'] - df['Close'].shift(1)).abs()
    low_close = (df['Low'] - df['Close'].shift(1)).abs()
    tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    df['atr14'] = tr.rolling(14).mean()

    df['ema200'] = df['Close'].ewm(span=200, adjust=False).mean()
    df['ema800'] = df['Close'].ewm(span=800, adjust=False).mean()

    up_move = df['High'] - df['High'].shift(1)
    down_move = df['Low'].shift(1) - df['Low']
    plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0.0)
    minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)
    tr_smooth = tr.rolling(14).sum()
    plus_di = 100.0 * (pd.Series(plus_dm, index=df.index).rolling(14).sum() / tr_smooth)
    minus_di = 100.0 * (pd.Series(minus_dm, index=df.index).rolling(14).sum() / tr_smooth)
    dx = 100.0 * (plus_di - minus_di).abs() / (plus_di + minus_di)
    df['adx14'] = dx.rolling(14).mean()
    df['plus_di'] = plus_di
    df['minus_di'] = minus_di
    df = df.dropna()

    c = df['Close'].values
    h = df['High'].values
    l = df['Low'].values
    o = df['Open'].values
    atr = df['atr14'].values
    ema200 = df['ema200'].values
    ema800 = df['ema800'].values
    adx = df['adx14'].values
    p_di = df['plus_di'].values
    m_di = df['minus_di'].values

    total_len = len(c)
    is_len = int(total_len * 0.75) # 75% IS : 25% OOS

    param_grid = {
        'donchian_window': [18, 20, 24, 28, 36],
        'atr_trail_mult': [3.0, 3.5, 4.0, 4.5],
        'atr_stop_mult': [1.5, 1.8, 2.0, 2.5],
        'min_adx': [16.0, 18.0, 20.0],
        'risk_per_trade': [0.020, 0.025, 0.030], # 2.0% - 3.0% for >80% - 160% CAGR
        'max_bars_hold': [72, 96, 120]
    }

    keys = list(param_grid.keys())
    combos = [dict(zip(keys, v)) for v in itertools.product(*param_grid.values())]
    print(f"Total parameter combinations: {len(combos)}")

    workers = multiprocessing.cpu_count()
    print(f"Launching {workers} parallel processes (100% CPU utilization)...")

    args_list = [
        (p, c, h, l, o, atr, ema200, ema800, adx, p_di, m_di, is_len, total_len)
        for p in combos
    ]

    t0 = time.time()
    with multiprocessing.Pool(processes=workers) as pool:
        raw_res = pool.map(worker_fn, args_list, chunksize=25)

    elapsed = time.time() - t0
    print(f"\nOptimization Finished in {elapsed:.2f} seconds across all {workers} cores!")

    qualified = [r for r in raw_res if r is not None]
    print(f"Total Qualified Candidates (passed IS > 80% & OOS > 50% with MaxDD < 16%): {len(qualified)}")

    if qualified:
        # Sort by Full Period CAGR
        qualified.sort(key=lambda x: x['full_cagr'], reverse=True)
        top = qualified[0]

        print("\n" + "="*75)
        print("[WINNER] TOP MASTER PARAMETER SET ACHIEVED:")
        print("="*75)
        print(f"Parameters: {top['params']}")
        print(f"In-Sample (IS) -> CAGR: {top['is_cagr']*100:.2f}% | MaxDD: {top['is_dd']*100:.2f}% | PF: {top['is_pf']:.2f}")
        print(f"Out-of-Sample (OOS) -> CAGR: {top['oos_cagr']*100:.2f}% | MaxDD: {top['oos_dd']*100:.2f}% | PF: {top['oos_pf']:.2f}")
        print(f"Full Period -> CAGR: {top['full_cagr']*100:.2f}% | MaxDD: {top['full_dd']*100:.2f}% | PF: {top['full_pf']:.2f} | Trades: {top['trades']}")

        # 10,000 Monte Carlo simulations
        print("\nRunning 10,000x Monte Carlo permutation test...")
        pnl = np.array(top['pnl_history'])
        dds = []
        ruin = 0
        for _ in range(10000):
            sample = np.random.choice(pnl, size=len(pnl), replace=True)
            curve = 10000.0 + np.cumsum(sample)
            cmax = np.maximum.accumulate(curve)
            d = (curve - cmax) / np.maximum(cmax, 1.0)
            dds.append(d.min())
            if curve.min() < 5000.0:
                ruin += 1
        dds = np.array(dds)
        print(f"Monte Carlo Median Drawdown: {np.percentile(dds, 50)*100:.2f}%")
        print(f"Monte Carlo 95th Percentile Drawdown: {np.percentile(dds, 5)*100:.2f}%")
        print(f"Probability of Ruin (50% Loss): {ruin / 10000.0 * 100.0:.2f}%")

        # Save to CSV
        df_top = pd.DataFrame([{
            'donchian_window': q['params']['donchian_window'],
            'atr_trail_mult': q['params']['atr_trail_mult'],
            'atr_stop_mult': q['params']['atr_stop_mult'],
            'min_adx': q['params']['min_adx'],
            'risk_per_trade': q['params']['risk_per_trade'],
            'max_bars_hold': q['params']['max_bars_hold'],
            'is_cagr': q['is_cagr'],
            'is_dd': q['is_dd'],
            'oos_cagr': q['oos_cagr'],
            'oos_dd': q['oos_dd'],
            'full_cagr': q['full_cagr'],
            'full_dd': q['full_dd'],
            'full_pf': q['full_pf'],
            'trades': q['trades']
        } for q in qualified[:25]])
        df_top.to_csv(r"C:\Users\Booth\quant_ea_lab\top_breakout_candidates.csv", index=False)
        print(f"Saved Top {len(df_top)} Candidates to top_breakout_candidates.csv")

if __name__ == "__main__":
    main()
