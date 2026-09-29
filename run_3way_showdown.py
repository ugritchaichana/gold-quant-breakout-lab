"""
3-WAY ARCHITECTURE SHOWDOWN BENCHMARK
Asset: Gold (XAUUSD.iux) | Exactly Synchronized Period: 2025.08.20 - 2026.09.28
Split: In-Sample (< 2026.06.15) vs Out-of-Sample Forward (>= 2026.06.15)
Architectures Evaluated:
  1. Option A: Pure Single H1
  2. Option B: Pure Single M15
  3. Option C: True Multi-Timeframe (H1 Trend Filter + M15 Entry + H1 ATR Chandelier Trailing)
"""

import os
import numpy as np
import pandas as pd

def calc_indicators(df):
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
    return df.dropna()

def simulate_trades(c, h, l, o, atr, ema200, ema800, adx, p_di, m_di, upper_donchian, p, bar_min, start, end, external_h1_atr=None):
    c_s = c[start:end]
    h_s = h[start:end]
    l_s = l[start:end]
    o_s = o[start:end]
    atr_s = atr[start:end]
    ema200_s = ema200[start:end]
    ema800_s = ema800[start:end]
    adx_s = adx[start:end]
    p_di_s = p_di[start:end]
    m_di_s = m_di[start:end]
    up_don_s = upper_donchian[start:end]
    ext_atr_s = external_h1_atr[start:end] if external_h1_atr is not None else atr_s

    n = len(c_s)
    balance = 10000.0
    equity = balance
    cummax = balance
    max_dd = 0.0

    in_pos = False
    entry_price = 0.0
    entry_bar = 0
    lots = 0.0
    sl_price = 0.0
    peak_price = 0.0
    closed_pnl = []
    wins_pnl = 0.0
    losses_pnl = 0.0
    win_count = 0
    loss_count = 0

    atr_trail_mult = p['atr_trail']
    atr_stop_mult = p['atr_stop']
    risk_pct = p['risk']
    min_adx = p['min_adx']
    max_hold_bars = p['max_hold']

    start_idx = max(int(p['donchian']) + 1, 805)
    for i in range(start_idx, n):
        cur_atr = ext_atr_s[i] # Uses H1 ATR if MTF, else native ATR
        if cur_atr <= 0 or np.isnan(cur_atr):
            continue

        if in_pos:
            unrealized = (c_s[i] - entry_price) * lots * 100.0
            equity = balance + unrealized
            if equity > cummax:
                cummax = equity
            dd = (equity - cummax) / cummax
            if dd < max_dd:
                max_dd = dd

            # Circuit breaker: Hard cut at -15%
            if dd <= -0.15:
                realized = (c_s[i] - entry_price) * lots * 100.0
                balance += realized
                equity = balance
                closed_pnl.append(realized)
                loss_count += 1
                losses_pnl += abs(realized)
                in_pos = False
                continue

            if h_s[i] > peak_price:
                peak_price = h_s[i]

            # Trailing stop
            new_trail = peak_price - (atr_trail_mult * cur_atr)
            if new_trail > sl_price:
                sl_price = new_trail

            if l_s[i] <= sl_price:
                exit_price = sl_price
                realized = (exit_price - entry_price) * lots * 100.0
                balance += realized
                equity = balance
                closed_pnl.append(realized)
                if realized > 0:
                    win_count += 1
                    wins_pnl += realized
                else:
                    loss_count += 1
                    losses_pnl += abs(realized)
                in_pos = False
                continue

            # Stagnation exit
            if (i - entry_bar) >= max_hold_bars:
                if (c_s[i] - entry_price) < (0.5 * cur_atr):
                    exit_price = c_s[i]
                    realized = (exit_price - entry_price) * lots * 100.0
                    balance += realized
                    equity = balance
                    closed_pnl.append(realized)
                    if realized > 0:
                        win_count += 1
                        wins_pnl += realized
                    else:
                        loss_count += 1
                        losses_pnl += abs(realized)
                    in_pos = False
                    continue

        if not in_pos:
            if c_s[i] > up_don_s[i] and c_s[i] > ema200_s[i] and c_s[i] > ema800_s[i]:
                if adx_s[i] >= min_adx and p_di_s[i] > m_di_s[i]:
                    dist_to_sl = atr_stop_mult * cur_atr
                    if dist_to_sl > 0:
                        eff_risk = risk_pct
                        cur_dd = (balance - cummax) / cummax if cummax > 0 else 0
                        if cur_dd <= -0.05:
                            eff_risk *= 0.5

                        risk_amt = balance * eff_risk
                        calc_lots = risk_amt / (dist_to_sl * 100.0)
                        max_lots = (balance * 5.0) / (c_s[i] * 100.0)
                        calc_lots = min(calc_lots, max_lots)
                        calc_lots = max(0.01, round(calc_lots, 2))

                        in_pos = True
                        entry_price = c_s[i]
                        entry_bar = i
                        lots = calc_lots
                        sl_price = entry_price - dist_to_sl
                        peak_price = entry_price

    if in_pos:
        realized = (c_s[-1] - entry_price) * lots * 100.0
        balance += realized
        closed_pnl.append(realized)
        if realized > 0:
            win_count += 1
            wins_pnl += realized
        else:
            loss_count += 1
            losses_pnl += abs(realized)

    years = (n * bar_min) / (60.0 * 24.0 * 365.25)
    cagr = (balance / 10000.0) ** (1.0 / years) - 1.0 if years > 0 and balance > 0 else 0.0
    pf = (wins_pnl / losses_pnl) if losses_pnl > 0 else (99.0 if wins_pnl > 0 else 1.0)
    win_rate = (win_count / (win_count + loss_count) * 100.0) if (win_count + loss_count) > 0 else 0.0

    return {
        'cagr': cagr,
        'dd': max_dd,
        'pf': pf,
        'win_rate': win_rate,
        'trades': win_count + loss_count,
        'final_balance': balance,
        'pnl': closed_pnl
    }

def run_showdown():
    print("=" * 90)
    print("EMPIRICAL 3-WAY ARCHITECTURE SHOWDOWN (EXACT MATCHED PERIOD: 2025.08.20 - 2026.09.28)")
    print("=" * 90)

    # 1. Load data
    m15_file = r"C:\Users\Booth\quant_ea_lab\data\gold_m15.csv"
    h1_file = r"C:\Users\Booth\quant_ea_lab\data\gold_h1.csv"

    df_m15 = calc_indicators(pd.read_csv(m15_file, parse_dates=['Datetime'], index_col='Datetime'))
    df_h1 = calc_indicators(pd.read_csv(h1_file, parse_dates=['Datetime'], index_col='Datetime'))

    df_m15 = df_m15[df_m15.index >= '2025-08-20'].copy()
    df_h1 = df_h1[df_h1.index >= '2025-08-20'].copy()

    # Split boundaries
    split_date = '2026-06-15'
    
    # -------------------------------------------------------------
    # OPTION A: Single H1 Pure
    # -------------------------------------------------------------
    h1_c, h1_h, h1_l, h1_o = df_h1['Close'].values, df_h1['High'].values, df_h1['Low'].values, df_h1['Open'].values
    h1_atr = df_h1['atr14'].values
    h1_ema200 = df_h1['ema200'].values
    h1_ema800 = df_h1['ema800'].values
    h1_adx = df_h1['adx14'].values
    h1_p_di = df_h1['plus_di'].values
    h1_m_di = df_h1['minus_di'].values
    h1_donchian_val = pd.Series(h1_h).shift(1).rolling(28).max().values

    p_a = {'donchian': 28, 'atr_trail': 3.8, 'atr_stop': 1.8, 'risk': 0.035, 'min_adx': 18.0, 'max_hold': 48}
    h1_is_len = int((df_h1.index < split_date).sum())
    h1_total = len(df_h1)

    res_a_full = simulate_trades(h1_c, h1_h, h1_l, h1_o, h1_atr, h1_ema200, h1_ema800, h1_adx, h1_p_di, h1_m_di, h1_donchian_val, p_a, 60, 0, h1_total)
    res_a_is = simulate_trades(h1_c, h1_h, h1_l, h1_o, h1_atr, h1_ema200, h1_ema800, h1_adx, h1_p_di, h1_m_di, h1_donchian_val, p_a, 60, 0, h1_is_len)
    res_a_oos = simulate_trades(h1_c, h1_h, h1_l, h1_o, h1_atr, h1_ema200, h1_ema800, h1_adx, h1_p_di, h1_m_di, h1_donchian_val, p_a, 60, h1_is_len, h1_total)

    # -------------------------------------------------------------
    # OPTION B: Single M15 Pure
    # -------------------------------------------------------------
    m15_c, m15_h, m15_l, m15_o = df_m15['Close'].values, df_m15['High'].values, df_m15['Low'].values, df_m15['Open'].values
    m15_atr = df_m15['atr14'].values
    m15_ema200 = df_m15['ema200'].values
    m15_ema800 = df_m15['ema800'].values
    m15_adx = df_m15['adx14'].values
    m15_p_di = df_m15['plus_di'].values
    m15_m_di = df_m15['minus_di'].values
    m15_donchian_val = pd.Series(m15_h).shift(1).rolling(96).max().values

    p_b = {'donchian': 96, 'atr_trail': 5.0, 'atr_stop': 1.6, 'risk': 0.030, 'min_adx': 18.0, 'max_hold': 144}
    m15_is_len = int((df_m15.index < split_date).sum())
    m15_total = len(df_m15)

    res_b_full = simulate_trades(m15_c, m15_h, m15_l, m15_o, m15_atr, m15_ema200, m15_ema800, m15_adx, m15_p_di, m15_m_di, m15_donchian_val, p_b, 15, 0, m15_total)
    res_b_is = simulate_trades(m15_c, m15_h, m15_l, m15_o, m15_atr, m15_ema200, m15_ema800, m15_adx, m15_p_di, m15_m_di, m15_donchian_val, p_b, 15, 0, m15_is_len)
    res_b_oos = simulate_trades(m15_c, m15_h, m15_l, m15_o, m15_atr, m15_ema200, m15_ema800, m15_adx, m15_p_di, m15_m_di, m15_donchian_val, p_b, 15, m15_is_len, m15_total)

    # -------------------------------------------------------------
    # OPTION C: True Multi-Timeframe (H1 Macro Filter + M15 Entry + H1 ATR Trailing)
    # -------------------------------------------------------------
    # Forward-fill H1 indicators onto M15 index
    df_m15_mtf = df_m15.copy()
    h1_indicators = df_h1[['atr14', 'ema200', 'ema800', 'adx14', 'plus_di', 'minus_di']].rename(columns={
        'atr14': 'h1_atr', 'ema200': 'h1_ema200', 'ema800': 'h1_ema800',
        'adx14': 'h1_adx', 'plus_di': 'h1_p_di', 'minus_di': 'h1_m_di'
    })
    # Merge as-of
    df_mtf = pd.merge_asof(df_m15_mtf, h1_indicators, left_index=True, right_index=True, direction='backward').dropna()

    mtf_c = df_mtf['Close'].values
    mtf_h = df_mtf['High'].values
    mtf_l = df_mtf['Low'].values
    mtf_o = df_mtf['Open'].values
    mtf_atr_h1 = df_mtf['h1_atr'].values
    mtf_ema200_h1 = df_mtf['h1_ema200'].values
    mtf_ema800_h1 = df_mtf['h1_ema800'].values
    mtf_adx_h1 = df_mtf['h1_adx'].values
    mtf_p_di_h1 = df_mtf['h1_p_di'].values
    mtf_m_di_h1 = df_mtf['h1_m_di'].values
    # M15 Entry Trigger: 48 bars (12 Hours) or 96 bars (24 Hours)
    mtf_donchian_val = pd.Series(mtf_h).shift(1).rolling(48).max().values

    p_c = {'donchian': 48, 'atr_trail': 4.2, 'atr_stop': 1.6, 'risk': 0.030, 'min_adx': 18.0, 'max_hold': 144}
    mtf_is_len = int((df_mtf.index < split_date).sum())
    mtf_total = len(df_mtf)

    res_c_full = simulate_trades(mtf_c, mtf_h, mtf_l, mtf_o, mtf_atr_h1, mtf_ema200_h1, mtf_ema800_h1, mtf_adx_h1, mtf_p_di_h1, mtf_m_di_h1, mtf_donchian_val, p_c, 15, 0, mtf_total, external_h1_atr=mtf_atr_h1)
    res_c_is = simulate_trades(mtf_c, mtf_h, mtf_l, mtf_o, mtf_atr_h1, mtf_ema200_h1, mtf_ema800_h1, mtf_adx_h1, mtf_p_di_h1, mtf_m_di_h1, mtf_donchian_val, p_c, 15, 0, mtf_is_len, external_h1_atr=mtf_atr_h1)
    res_c_oos = simulate_trades(mtf_c, mtf_h, mtf_l, mtf_o, mtf_atr_h1, mtf_ema200_h1, mtf_ema800_h1, mtf_adx_h1, mtf_p_di_h1, mtf_m_di_h1, mtf_donchian_val, p_c, 15, mtf_is_len, mtf_total, external_h1_atr=mtf_atr_h1)

    print("\n" + "=" * 90)
    print("SHOWDOWN RESULTS SUMMARY:")
    print("=" * 90)
    print(f"{'Metric':<30} | {'Option A (Single H1)':<20} | {'Option B (Single M15)':<20} | {'Option C (True MTF Hybrid)':<20}")
    print("-" * 96)
    print(f"{'Full Period CAGR':<30} | +{res_a_full['cagr']*100:<18.1f}% | +{res_b_full['cagr']*100:<18.1f}% | +{res_c_full['cagr']*100:<18.1f}%")
    print(f"{'OOS Forward CAGR (Recent 3M)':<30} | +{res_a_oos['cagr']*100:<18.1f}% | +{res_b_oos['cagr']*100:<18.1f}% | +{res_c_oos['cagr']*100:<18.1f}%")
    print(f"{'In-Sample CAGR (10M Trend)':<30} | +{res_a_is['cagr']*100:<18.1f}% | +{res_b_is['cagr']*100:<18.1f}% | +{res_c_is['cagr']*100:<18.1f}%")
    print(f"{'Maximum Drawdown':<30} | {res_a_full['dd']*100:<18.1f}% | {res_b_full['dd']*100:<18.1f}% | {res_c_full['dd']*100:<18.1f}%")
    print(f"{'Profit Factor':<30} | {res_a_full['pf']:<19.2f} | {res_b_full['pf']:<19.2f} | {res_c_full['pf']:<19.2f}")
    print(f"{'Win Rate (%)':<30} | {res_a_full['win_rate']:<18.1f}% | {res_b_full['win_rate']:<18.1f}% | {res_c_full['win_rate']:<18.1f}%")
    print(f"{'Total Trades Executed':<30} | {res_a_full['trades']:<19d} | {res_b_full['trades']:<19d} | {res_c_full['trades']:<19d}")
    print(f"{'Final Balance ($10,000 Init)':<30} | ${res_a_full['final_balance']:<18,.2f} | ${res_b_full['final_balance']:<18,.2f} | ${res_c_full['final_balance']:<18,.2f}")
    print("=" * 96)

if __name__ == "__main__":
    run_showdown()
