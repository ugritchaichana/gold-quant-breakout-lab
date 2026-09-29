import pandas as pd
import numpy as np
from hourly_optimizer import HourlyGoldBacktester

def check_neighborhood_robustness():
    bt = HourlyGoldBacktester(r"C:\Users\Booth\quant_ea_lab\data\gold_hourly.csv")
    total_bars = len(bt.df)
    split_idx = int(800 + (total_bars - 800) * 0.70)
    
    # Neighborhood around (Donchian=24, Trail=4.0, Stop=1.5, ADX=18, Risk=0.015)
    donchian_tests = [20, 24, 28]
    trail_tests = [3.5, 4.0, 4.5]
    stop_tests = [1.5, 2.0]
    
    results = []
    print("Testing Neighborhood Stability around Peak Parameters...")
    print(f"{'Donchian':<10} {'Trail':<8} {'Stop':<8} {'OOS Ret%':<10} {'OOS PF':<8} {'OOS MaxDD%':<12} {'Full Ret%':<10} {'Full PF':<8} {'Full MaxDD%':<12}")
    print("-" * 88)
    
    for d in donchian_tests:
        for tr in trail_tests:
            for st in stop_tests:
                bt.risk_per_trade = 0.015
                # OOS
                oos = bt.run_backtest(
                    donchian_window=d,
                    atr_trail_mult=tr,
                    atr_stop_mult=st,
                    min_adx=18.0,
                    start_idx=split_idx,
                    end_idx=None
                )
                # Full
                full = bt.run_backtest(
                    donchian_window=d,
                    atr_trail_mult=tr,
                    atr_stop_mult=st,
                    min_adx=18.0,
                    start_idx=800,
                    end_idx=None
                )
                if oos and full:
                    print(f"{d:<10} {tr:<8} {st:<8} {oos['total_return']*100:<10.1f} {oos['profit_factor']:<8.2f} {oos['max_dd']*100:<12.1f} {full['total_return']*100:<10.1f} {full['profit_factor']:<8.2f} {full['max_dd']*100:<12.1f}")
                    results.append({
                        'donchian': d,
                        'trail': tr,
                        'stop': st,
                        'oos_return': oos['total_return'],
                        'oos_pf': oos['profit_factor'],
                        'oos_maxdd': oos['max_dd'],
                        'full_return': full['total_return'],
                        'full_pf': full['profit_factor'],
                        'full_maxdd': full['max_dd']
                    })

    df_res = pd.DataFrame(results)
    profitable_neighbors = (df_res['oos_return'] > 0).mean() * 100.0
    print("\n" + "="*60)
    print(f"Robustness Plateau Score: {profitable_neighbors:.1f}% of neighboring parameters are profitable in OOS!")
    print(f"Average OOS Profit Factor across plateau: {df_res['oos_pf'].mean():.2f}")
    print(f"Average Full Profit Factor across plateau: {df_res['full_pf'].mean():.2f}")
    print(f"Worst-case Drawdown across entire plateau: {df_res['full_maxdd'].min()*100:.1f}%")

if __name__ == "__main__":
    check_neighborhood_robustness()
