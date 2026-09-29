import pandas as pd

df = pd.read_csv(r"C:\Users\Booth\quant_ea_lab\top_breakout_candidates.csv")
print("="*100)
print(f"{'#':<3} {'Donchian':<9} {'Trail':<6} {'Stop':<6} {'Risk':<6} {'Hold':<6} {'IS CAGR%':<11} {'OOS CAGR%':<12} {'Full CAGR%':<12} {'Full DD%':<10} {'Full PF':<8}")
print("="*100)
for idx, r in df.iterrows():
    print(f"{idx+1:<3} {int(r['donchian_window']):<9} {r['atr_trail_mult']:<6.1f} {r['atr_stop_mult']:<6.1f} {r['risk_per_trade']:<6.3f} {int(r['max_bars_hold']):<6} {r['is_cagr']*100:<11.1f} {r['oos_cagr']*100:<12.1f} {r['full_cagr']*100:<12.1f} {r['full_dd']*100:<10.1f} {r['full_pf']:<8.2f}")
print("="*100)
