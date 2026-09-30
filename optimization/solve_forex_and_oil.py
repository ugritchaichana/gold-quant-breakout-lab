import os
import sqlite3
import numpy as np
import pandas as pd

MARKET_DB = r"C:\Users\Booth\quant_ea_lab\data\market_history.db"

def load_data(symbol, timeframe='hourly'):
    conn = sqlite3.connect(MARKET_DB)
    tbl = f"{symbol.lower()}_{timeframe}"
    df = pd.read_sql_query(f"SELECT * FROM {tbl}", conn)
    conn.close()
    
    date_col = 'Datetime' if 'Datetime' in df.columns else 'Date'
    close = df['Close'].values
    high = df['High'].values
    low = df['Low'].values
    atr = df['atr14'].values
    ema_fast = df['ema100'].values if 'ema100' in df.columns else df['ema50'].values
    ema_slow = df['ema200'].values
    n = len(close)

    period = 20
    ker = np.zeros(n)
    for i in range(period, n):
        net_change = abs(close[i] - close[i - period])
        path = np.sum(np.abs(np.diff(close[i - period : i + 1])))
        ker[i] = (net_change / path) if path > 0 else 0.0

    hours = None
    if 'Datetime' in df.columns:
        hours = pd.to_datetime(df['Datetime'], utc=True).dt.hour.values

    return {
        'n': n, 'c': close, 'h': high, 'l': low, 'atr': atr,
        'ema_fast': ema_fast, 'ema_slow': ema_slow, 'ker': ker,
        'hours': hours, 'times': df[date_col].values
    }

def simulate(data, donchian, atr_stop, atr_trail, tp_r, be_r, min_ker, start_hour=None, end_hour=None, stress_r=0.05):
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
    in_pos = 0
    entry_p = sl_p = tp_p = r_dist = 0.0
    be_active = False

    start_bar = max(donchian + 2, 200)

    for i in range(start_bar, n):
        if in_pos == 1:
            if l[i] <= sl_p:
                raw_loss = -1.0 if not be_active else 0.05
                pnl_r.append(raw_loss - stress_r)
                trade_times.append(data['times'][i])
                in_pos = 0; continue
            elif h[i] >= tp_p:
                pnl_r.append(tp_r - stress_r)
                trade_times.append(data['times'][i])
                in_pos = 0; continue
            else:
                if not be_active and (h[i] - entry_p) >= (be_r * r_dist):
                    sl_p = entry_p + (0.05 * r_dist)
                    be_active = True
                if atr_trail > 0:
                    new_sl = c[i] - (atr_trail * atr[i])
                    if new_sl > sl_p and new_sl < c[i]: sl_p = new_sl

        elif in_pos == -1:
            if h[i] >= sl_p:
                raw_loss = -1.0 if not be_active else 0.05
                pnl_r.append(raw_loss - stress_r)
                trade_times.append(data['times'][i])
                in_pos = 0; continue
            elif l[i] <= tp_p:
                pnl_r.append(tp_r - stress_r)
                trade_times.append(data['times'][i])
                in_pos = 0; continue
            else:
                if not be_active and (entry_p - l[i]) >= (be_r * r_dist):
                    sl_p = entry_p - (0.05 * r_dist)
                    be_active = True
                if atr_trail > 0:
                    new_sl = c[i] + (atr_trail * atr[i])
                    if new_sl < sl_p and new_sl > c[i]: sl_p = new_sl

        if in_pos == 0:
            if start_hour is not None and end_hour is not None and hours is not None:
                if hours[i] < start_hour or hours[i] > end_hour: continue
            if ker[i-1] < min_ker: continue

            don_high = np.max(h[i - 1 - donchian : i - 1])
            don_low  = np.min(l[i - 1 - donchian : i - 1])
            macro_bull = (c[i-1] > ema_fast[i-1] and ema_fast[i-1] > ema_slow[i-1])
            macro_bear = (c[i-1] < ema_fast[i-1] and ema_fast[i-1] < ema_slow[i-1])

            if macro_bull and c[i-1] >= don_high:
                in_pos = 1; entry_p = c[i]
                r_dist = atr_stop * atr[i]
                if r_dist <= 0: in_pos = 0; continue
                sl_p = entry_p - r_dist; tp_p = entry_p + (tp_r * r_dist); be_active = False

            elif macro_bear and c[i-1] <= don_low:
                in_pos = -1; entry_p = c[i]
                r_dist = atr_stop * atr[i]
                if r_dist <= 0: in_pos = 0; continue
                sl_p = entry_p + r_dist; tp_p = entry_p - (tp_r * r_dist); be_active = False

    if len(pnl_r) < 15: return None
    pnl = np.array(pnl_r)
    trades = len(pnl)
    wins = np.sum(pnl > 0)
    win_rate = (wins / trades) * 100.0
    gp = np.sum(pnl[pnl > 0])
    gl = abs(np.sum(pnl[pnl < 0]))
    pf = (gp / gl) if gl > 0 else 99.0

    bal = 25000.0
    curve = [bal]
    for r in pnl:
        bal += bal * (0.0025 * r)
        curve.append(bal)
    eq = np.array(curve)
    peaks = np.maximum.accumulate(eq)
    dds = (eq - peaks) / peaks * 100.0
    max_dd = abs(np.min(dds))

    years = 2.0 if len(data['c']) > 5000 else 10.0
    cagr = ((eq[-1] / 25000.0) ** (1.0 / max(years, 0.1)) - 1.0) * 100.0
    calmar = (cagr / max_dd) if max_dd > 0 else 0.0

    r_mean = np.mean(pnl)
    r_std = np.std(pnl)
    sqn = (np.sqrt(trades) * (r_mean / r_std)) if r_std > 0 else 0.0
    sharpe = (r_mean / r_std * np.sqrt(trades / years)) if r_std > 0 else 0.0

    x = np.arange(len(eq))
    slope, intercept = np.polyfit(x, eq, 1)
    fitted = slope * x + intercept
    ss_res = np.sum((eq - fitted) ** 2)
    ss_tot = np.sum((eq - np.mean(eq)) ** 2)
    r2 = 1.0 - (ss_res / ss_tot) if ss_tot > 0 else 0.0

    return {
        'trades': trades, 'win_rate': win_rate, 'pf': pf,
        'cagr': cagr, 'max_dd': max_dd, 'calmar': calmar,
        'sqn': sqn, 'sharpe': sharpe, 'r2': r2, 'final_bal': eq[-1]
    }

if __name__ == "__main__":
    for sym in ['GBPJPY', 'USOIL']:
        print(f"\n=================== TESTING {sym} (HOURLY 2Y) ===================")
        data = load_data(sym, 'hourly')
        best = []
        for don in [24, 36, 48, 72, 96, 120, 144]:
            for sl in [1.5, 2.0, 2.5]:
                for trail in [3.0, 4.0, 5.0]:
                    for tp in [1.5, 1.75, 2.0, 2.5]:
                        for be in [0.85, 1.0, 1.2]:
                            for ker in [0.15, 0.20, 0.25]:
                                r = simulate(data, don, sl, trail, tp, be, ker, None, None, 0.05)
                                if r and r['pf'] >= 1.20 and r['max_dd'] <= 3.5:
                                    score = r['sqn'] * r['calmar'] * r['r2']
                                    best.append((score, don, sl, trail, tp, be, ker, r))
        best.sort(key=lambda x: x[0], reverse=True)
        print(f"Total passing sets for {sym}: {len(best)}")
        for b in best[:3]:
            score, don, sl, trail, tp, be, ker, r = b
            print(f"  Don:{don} SL:{sl} Trail:{trail} TP:{tp} BE:{be} KER:{ker} -> Win:{r['win_rate']:.1f}% PF:{r['pf']:.2f} DD:{r['max_dd']:.2f}% Calmar:{r['calmar']:.2f} SQN:{r['sqn']:.2f} R2:{r['r2']:.3f} Bal:${r['final_bal']:,.2f}")
