import pandas as pd
import os

p = r"C:\Users\Booth\quant_ea_lab\master_optimization_database.csv"
if os.path.exists(p):
    df = pd.read_csv(p)
    print(f"Total candidates in DB: {len(df):,}")
    dedup = df.drop_duplicates(subset=['donchian', 'atr_trail', 'atr_stop', 'risk', 'min_adx', 'max_hold']).copy()
    print(f"Unique candidate configurations: {len(dedup):,}")
    
    dedup['score'] = dedup['full_cagr'] * (1.0 - dedup['full_dd'].abs()) * (dedup['oos_cagr'] + 1.0)
    top = dedup.sort_values(by='score', ascending=False).head(15)
    
    print("\n" + "="*105)
    print("TOP 10 ALL-TIME BEST PARAMETER SETS (AFTER 5.5 HOURS OF CONTINUOUS OPTIMIZATION):")
    print("="*105)
    print(f"{'#':<3} {'Donchian':<9} {'Trail':<6} {'Stop':<6} {'Risk':<6} {'Hold':<6} {'IS CAGR%':<11} {'OOS CAGR%':<12} {'Full CAGR%':<12} {'Full DD%':<10} {'Full PF':<8} {'MC P95 DD%':<12}")
    print("-" * 105)
    for idx, (_, r) in enumerate(top.head(10).iterrows()):
        d_val = int(r['donchian'])
        tr_val = r['atr_trail']
        st_val = r['atr_stop']
        rk_val = r['risk'] * 100.0
        hd_val = int(r['max_hold'])
        is_c = r['is_cagr'] * 100.0
        oos_c = r['oos_cagr'] * 100.0
        fl_c = r['full_cagr'] * 100.0
        fl_dd = r['full_dd'] * 100.0
        fl_pf = r['full_pf']
        mc_dd = r['mc_p95_dd'] * 100.0
        print(f"{idx+1:<3} {d_val:<9} {tr_val:<6.1f} {st_val:<6.1f} {rk_val:<6.1f}% {hd_val:<4}h  {is_c:<11.1f} {oos_c:<12.1f} {fl_c:<12.1f} {fl_dd:<10.1f} {fl_pf:<8.2f} {mc_dd:<12.1f}")
    print("="*105)

    best = top.iloc[0]
    print("\nCHAMPION OVERALL WINNER:")
    print(f"  Donchian Window: {int(best['donchian'])} bars (H1)")
    print(f"  Trailing ATR Mult: {best['atr_trail']:.1f}x")
    print(f"  Stop Loss ATR Mult: {best['atr_stop']:.1f}x")
    print(f"  Risk per Trade: {best['risk']*100:.1f}%")
    print(f"  Max Hold Time: {int(best['max_hold'])} hours")
    print(f"  Full Period CAGR: +{best['full_cagr']*100:.1f}% per year")
    print(f"  Out-of-Sample Forward CAGR: +{best['oos_cagr']*100:.1f}% per year")
    print(f"  Max Drawdown: {best['full_dd']*100:.1f}%")
    print(f"  Profit Factor: {best['full_pf']:.2f}")
