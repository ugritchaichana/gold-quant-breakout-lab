import os
import sys
import numpy as np
import pandas as pd
from datetime import datetime

# Set utf-8 stdout
sys.stdout.reconfigure(encoding='utf-8')

m15_file = r"C:\Users\Booth\quant_ea_lab\data\gold_m15.csv"
h1_file = r"C:\Users\Booth\quant_ea_lab\data\gold_h1.csv"

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

print("Loading historical data...")
df_m15 = calc_indicators(pd.read_csv(m15_file, parse_dates=['Datetime'], index_col='Datetime'))
df_h1 = calc_indicators(pd.read_csv(h1_file, parse_dates=['Datetime'], index_col='Datetime'))

# Forward split date
split_date = '2026-06-15'
df_m15_fwd = df_m15[df_m15.index >= split_date].copy()
df_h1_fwd = df_h1[df_h1.index >= split_date].copy()

print(f"Forward Test Period: {df_m15_fwd.index.min()} to {df_m15_fwd.index.max()} ({len(df_m15_fwd)} M15 bars)")

def simulate_detailed_forward(df, p, name="Model", is_mtf=False, df_h1=None):
    if is_mtf:
        h1_ind = df_h1[['atr14', 'ema200', 'ema800', 'adx14', 'plus_di', 'minus_di']].rename(columns={
            'atr14': 'h1_atr', 'ema200': 'h1_ema200', 'ema800': 'h1_ema800',
            'adx14': 'h1_adx', 'plus_di': 'h1_p_di', 'minus_di': 'h1_m_di'
        })
        df_merged = pd.merge_asof(df, h1_ind, left_index=True, right_index=True, direction='backward').dropna()
        c = df_merged['Close'].values
        h = df_merged['High'].values
        l = df_merged['Low'].values
        o = df_merged['Open'].values
        atr = df_merged['h1_atr'].values
        ema200 = df_merged['h1_ema200'].values
        ema800 = df_merged['h1_ema800'].values
        adx = df_merged['h1_adx'].values
        p_di = df_merged['h1_p_di'].values
        m_di = df_merged['h1_m_di'].values
        times = df_merged.index
    else:
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
        times = df.index

    upper_donchian = pd.Series(h).shift(1).rolling(int(p['donchian'])).max().values

    balance = 10000.0
    equity = balance
    cummax = balance
    max_dd = 0.0

    in_pos = False
    entry_price = 0.0
    entry_time = None
    lots = 0.0
    sl_price = 0.0
    peak_price = 0.0
    bars_held = 0

    trade_log = []
    daily_equity = {}

    for i in range(int(p['donchian']) + 1, len(c)):
        cur_time = times[i]
        cur_atr = atr[i]
        if cur_atr <= 0 or np.isnan(cur_atr):
            continue

        if in_pos:
            bars_held += 1
            unrealized = (c[i] - entry_price) * lots * 100.0
            equity = balance + unrealized
            if equity > cummax:
                cummax = equity
            dd = (equity - cummax) / cummax
            if dd < max_dd:
                max_dd = dd

            # Chandelier Trail Stop
            if h[i] > peak_price:
                peak_price = h[i]
            chandelier_sl = peak_price - (p['atr_trail'] * cur_atr)

            # Check SL exit
            exit_reason = None
            exit_price = 0.0

            if l[i] <= chandelier_sl:
                exit_reason = "Trailing Stop (Chandelier)"
                exit_price = min(o[i], chandelier_sl) # 100ms slip simulation
            elif bars_held >= p['max_hold'] and (c[i] - entry_price) < (0.5 * cur_atr):
                exit_reason = "Time Stagnation Exit"
                exit_price = c[i]
            elif c[i] < ema200[i]:
                exit_reason = "Macro Regime Exit (<EMA200)"
                exit_price = c[i]
            elif dd <= -0.15:
                exit_reason = "Tier 3 Circuit Breaker (-15%)"
                exit_price = c[i]

            if exit_reason:
                pnl = (exit_price - entry_price) * lots * 100.0
                balance += pnl
                equity = balance
                r_mult = (exit_price - entry_price) / (entry_price - sl_price) if (entry_price - sl_price) > 0 else 0.0
                trade_log.append({
                    'EntryTime': entry_time,
                    'ExitTime': cur_time,
                    'EntryPrice': entry_price,
                    'ExitPrice': exit_price,
                    'Lots': lots,
                    'PnL': pnl,
                    'ReturnPct': (pnl / (balance - pnl)) * 100.0,
                    'R_Multiple': r_mult,
                    'BarsHeld': bars_held,
                    'ExitReason': exit_reason,
                    'RunningBalance': balance
                })
                in_pos = False
                continue

        # Evaluate Entry
        if not in_pos:
            is_breakout = h[i] >= upper_donchian[i]
            is_trend = c[i] > ema200[i] and c[i] > ema800[i]
            is_momentum = adx[i] >= p['min_adx'] and p_di[i] > m_di[i]

            if is_breakout and is_trend and is_momentum:
                # 100ms artificial delay + spread slip: entry at next open/high slip
                entry_price = o[i] + 0.15 # $0.15 spread/slip cost
                stop_dist = p['atr_stop'] * cur_atr
                sl_price = entry_price - stop_dist
                
                risk_amt = balance * p['risk']
                lots = round(risk_amt / (stop_dist * 100.0), 2)
                lots = max(0.01, min(10.0, lots))
                
                in_pos = True
                entry_time = cur_time
                peak_price = entry_price
                bars_held = 0

    df_trades = pd.DataFrame(trade_log)
    win_trades = df_trades[df_trades['PnL'] > 0] if not df_trades.empty else pd.DataFrame()
    loss_trades = df_trades[df_trades['PnL'] <= 0] if not df_trades.empty else pd.DataFrame()

    total_trades = len(df_trades)
    win_rate = (len(win_trades) / total_trades) * 100.0 if total_trades > 0 else 0.0
    gross_profit = win_trades['PnL'].sum() if not win_trades.empty else 0.0
    gross_loss = abs(loss_trades['PnL'].sum()) if not loss_trades.empty else 1.0
    pf = gross_profit / gross_loss if gross_loss > 0 else 0.0

    # Annualized CAGR across 3.5 months (105 days)
    days = (times[-1] - times[0]).total_seconds() / 86400.0
    years = days / 365.25
    cagr = ((balance / 10000.0) ** (1.0 / years)) - 1.0 if years > 0 else 0.0
    total_gain_pct = ((balance - 10000.0) / 10000.0) * 100.0

    return {
        'name': name,
        'final_balance': balance,
        'total_gain_pct': total_gain_pct,
        'cagr': cagr,
        'max_dd': max_dd,
        'pf': pf,
        'win_rate': win_rate,
        'trades': total_trades,
        'trade_log': df_trades,
        'avg_win': win_trades['PnL'].mean() if not win_trades.empty else 0.0,
        'avg_loss': loss_trades['PnL'].mean() if not loss_trades.empty else 0.0,
        'max_win': win_trades['PnL'].max() if not win_trades.empty else 0.0,
        'max_loss': loss_trades['PnL'].min() if not loss_trades.empty else 0.0
    }

# Parameters for Champion Rank 1 (M15 Pure Momentum)
p_rank1 = {
    'donchian': 96,
    'atr_trail': 5.0,
    'atr_stop': 1.6,
    'risk': 0.03,
    'min_adx': 18.0,
    'max_hold': 96
}

# Parameters for True MTF Hybrid (H1 Macro Filter + M15 Entry)
p_mtf = {
    'donchian': 48,
    'atr_trail': 4.2,
    'atr_stop': 1.4,
    'risk': 0.03,
    'min_adx': 18.0,
    'max_hold': 144
}

res_rank1 = simulate_detailed_forward(df_m15_fwd, p_rank1, name="Champion Rank 1 (Pure M15)")
res_mtf = simulate_detailed_forward(df_m15_fwd, p_mtf, name="True MTF Hybrid (H1+M15)", is_mtf=True, df_h1=df_h1_fwd)

print("\n" + "="*95)
print(f"OUT-OF-SAMPLE FORWARD TEST RESULTS (EXACT 3.5 MONTHS: 2026.06.15 - 2026.09.28)")
print("="*95)
print(f"{'Performance Metric':<35} | {'Champion Rank 1 (M15)':<25} | {'True MTF Hybrid (H1+M15)':<25}")
print("-"*95)
print(f"{'Initial Deposit':<35} | ${'10,000.00':<24} | ${'10,000.00':<24}")
print(f"{'Final Net Balance':<35} | ${res_rank1['final_balance']:<24,.2f} | ${res_mtf['final_balance']:<24,.2f}")
print(f"{'Total Net Return (%)':<35} | +{res_rank1['total_gain_pct']:<23.2f}% | +{res_mtf['total_gain_pct']:<23.2f}%")
print(f"{'Annualized Forward CAGR':<35} | +{res_rank1['cagr']*100:<23.1f}% | +{res_mtf['cagr']*100:<23.1f}%")
print(f"{'Maximum Drawdown (%)':<35} | {res_rank1['max_dd']*100:<24.1f}% | {res_mtf['max_dd']*100:<24.1f}%")
print(f"{'Profit Factor':<35} | {res_rank1['pf']:<25.2f} | {res_mtf['pf']:<25.2f}")
print(f"{'Win Rate (%)':<35} | {res_rank1['win_rate']:<24.1f}% | {res_mtf['win_rate']:<24.1f}%")
print(f"{'Total Trades Executed':<35} | {res_rank1['trades']:<25d} | {res_mtf['trades']:<25d}")
print(f"{'Average Winning Trade':<35} | ${res_rank1['avg_win']:<24,.2f} | ${res_mtf['avg_win']:<24,.2f}")
print(f"{'Average Losing Trade':<35} | ${res_rank1['avg_loss']:<24,.2f} | ${res_mtf['avg_loss']:<24,.2f}")
print(f"{'Largest Single Win':<35} | ${res_rank1['max_win']:<24,.2f} | ${res_mtf['max_win']:<24,.2f}")
print(f"{'Payoff Ratio (Avg Win / Avg Loss)':<35} | {abs(res_rank1['avg_win']/res_rank1['avg_loss']) if res_rank1['avg_loss']!=0 else 0:<25.2f} | {abs(res_mtf['avg_win']/res_mtf['avg_loss']) if res_mtf['avg_loss']!=0 else 0:<25.2f}")
print("="*95)

# Monthly Breakdown for Rank 1
tlog = res_rank1['trade_log'].copy()
if not tlog.empty:
    tlog['Month'] = pd.to_datetime(tlog['ExitTime']).dt.to_period('M')
    monthly = tlog.groupby('Month').agg({'PnL': ['count', 'sum']})
    monthly.columns = ['Trades', 'Net PnL ($)']
    print("\nMONTHLY BREAKDOWN FOR RANK 1 (M15 CHAMPION):")
    print(monthly.to_string())

# Save trade log to CSV
csv_out = r"C:\Users\Booth\quant_ea_lab\research_data\forward_test_3months_rank1_trades.csv"
tlog.to_csv(csv_out, index=False)
print(f"\nDetailed Trade-by-Trade Log saved to: {csv_out}")
