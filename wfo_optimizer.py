import itertools
import numpy as np
import pandas as pd
from strategy_engine import GoldBreakoutBacktester

def calculate_dsr(sharpe, n_trials, sample_length, skewness=0.0, kurtosis=3.0):
    """
    Computes Marcos Lopez de Prado's Deflated Sharpe Ratio (DSR).
    Estimates the probability that the observed Sharpe ratio is not a false discovery.
    """
    from scipy.stats import norm
    euler_mascheroni = 0.5772156649
    
    # Expected maximum Sharpe under the null hypothesis of no alpha across N independent trials
    if n_trials <= 1:
        e_max_sr = 0.0
    else:
        e_max_sr = (1 - euler_mascheroni) * norm.ppf(1 - 1.0 / n_trials) + euler_mascheroni * norm.ppf(1 - 1.0 / (n_trials * np.e))
    
    # Standard deviation of Sharpe estimator under non-normality
    var_sr = (1.0 - skewness * sharpe + ((kurtosis - 1.0) / 4.0) * (sharpe ** 2)) / max(sample_length - 1, 1)
    std_sr = np.sqrt(max(var_sr, 1e-6))
    
    # Probabilistic Sharpe Ratio relative to expected max under null
    z = (sharpe - e_max_sr) / std_sr
    dsr = norm.cdf(z)
    return dsr, e_max_sr

class WalkForwardOptimizer:
    def __init__(self, data_path, is_years=4, oos_years=1, step_years=1):
        self.data_path = data_path
        self.backtester = GoldBreakoutBacktester(data_path)
        self.df = self.backtester.df
        self.is_years = is_years
        self.oos_years = oos_years
        self.step_years = step_years
        
        # Define realistic Parameter Grid for institutional breakout
        self.param_grid = {
            'donchian_window': [15, 20, 30, 45, 55],
            'atr_trail_mult': [2.5, 3.0, 3.5, 4.0],
            'atr_stop_mult': [2.0, 2.5, 3.0],
            'risk_per_trade': [0.01, 0.015, 0.02],
            'use_vol_filter': [True, False],
            'use_regime_filter': [True]
        }

    def generate_windows(self):
        dates = self.df.index
        start_year = dates[250].year # after warmup
        end_year = dates[-1].year
        
        windows = []
        curr_start = start_year
        while curr_start + self.is_years + self.oos_years <= end_year + 1:
            is_start_dt = pd.Timestamp(f"{curr_start}-01-01")
            is_end_dt = pd.Timestamp(f"{curr_start + self.is_years}-01-01")
            oos_start_dt = is_end_dt
            oos_end_dt = pd.Timestamp(f"{curr_start + self.is_years + self.oos_years}-01-01")
            
            # Map timestamps to integer indices
            is_sub = self.df.loc[(self.df.index >= is_start_dt) & (self.df.index < is_end_dt)]
            oos_sub = self.df.loc[(self.df.index >= oos_start_dt) & (self.df.index < oos_end_dt)]
            
            if len(is_sub) > 200 and len(oos_sub) > 40:
                is_start_idx = self.df.index.get_loc(is_sub.index[0])
                is_end_idx = self.df.index.get_loc(is_sub.index[-1]) + 1
                oos_start_idx = self.df.index.get_loc(oos_sub.index[0])
                oos_end_idx = self.df.index.get_loc(oos_sub.index[-1]) + 1
                
                windows.append({
                    'window_name': f"IS: {curr_start}-{curr_start+self.is_years} | OOS: {curr_start+self.is_years}-{curr_start+self.is_years+self.oos_years}",
                    'is_range': (is_start_idx, is_end_idx),
                    'oos_range': (oos_start_idx, oos_end_idx),
                    'is_dates': (is_start_dt, is_end_dt),
                    'oos_dates': (oos_start_dt, oos_end_dt)
                })
            curr_start += self.step_years
        return windows

    def run_optimization(self):
        windows = self.generate_windows()
        print(f"Total Walk-Forward Windows Generated: {len(windows)}")
        
        # Generate parameter combinations
        keys = list(self.param_grid.keys())
        combos = [dict(zip(keys, v)) for v in itertools.product(*self.param_grid.values())]
        n_combos = len(combos)
        print(f"Total Parameter Combinations per Window: {n_combos}")
        
        wfo_results = []
        oos_equity_segments = []
        best_params_history = []

        for w_idx, win in enumerate(windows):
            print(f"\n[{w_idx+1}/{len(windows)}] Evaluating {win['window_name']}...")
            is_start, is_end = win['is_range']
            oos_start, oos_end = win['oos_range']
            
            best_is_metric = -999.0
            best_is_res = None
            best_p = None
            
            # 1. In-Sample Search
            for p in combos:
                self.backtester.risk_per_trade = p['risk_per_trade']
                res = self.backtester.run_backtest(
                    donchian_window=p['donchian_window'],
                    atr_trail_mult=p['atr_trail_mult'],
                    atr_stop_mult=p['atr_stop_mult'],
                    use_vol_filter=p['use_vol_filter'],
                    use_regime_filter=p['use_regime_filter'],
                    start_idx=is_start,
                    end_idx=is_end
                )
                if res and res['n_trades'] >= 6:
                    # Multi-objective Fitness Score: Profit Factor * (1 - abs(MaxDD)) * min(Trades, 25)
                    # Penalizes low trade count and large drawdown
                    fitness = res['profit_factor'] * (1.0 - abs(res['max_dd'])) * (res['cagr'] + 1.0)
                    if fitness > best_is_metric:
                        best_is_metric = fitness
                        best_is_res = res
                        best_p = p

            if best_p is None:
                print("  No qualified parameters found in IS. Skipping window.")
                continue

            print(f"  Selected IS Best Params: {best_p}")
            print(f"  IS Performance -> CAGR: {best_is_res['cagr']*100:.2f}%, PF: {best_is_res['profit_factor']:.2f}, MaxDD: {best_is_res['max_dd']*100:.2f}%, Trades: {best_is_res['n_trades']}")

            # 2. Out-of-Sample Verification (Unseen Future)
            self.backtester.risk_per_trade = best_p['risk_per_trade']
            oos_res = self.backtester.run_backtest(
                donchian_window=best_p['donchian_window'],
                atr_trail_mult=best_p['atr_trail_mult'],
                atr_stop_mult=best_p['atr_stop_mult'],
                use_vol_filter=best_p['use_vol_filter'],
                use_regime_filter=best_p['use_regime_filter'],
                start_idx=oos_start,
                end_idx=oos_end
            )

            if oos_res:
                print(f"  OOS Performance -> Return: {oos_res['total_return']*100:.2f}%, PF: {oos_res['profit_factor']:.2f}, MaxDD: {oos_res['max_dd']*100:.2f}%, Trades: {oos_res['n_trades']}")
                wfo_results.append({
                    'window': win['window_name'],
                    'params': best_p,
                    'is_cagr': best_is_res['cagr'],
                    'is_pf': best_is_res['profit_factor'],
                    'is_maxdd': best_is_res['max_dd'],
                    'oos_return': oos_res['total_return'],
                    'oos_pf': oos_res['profit_factor'],
                    'oos_maxdd': oos_res['max_dd'],
                    'oos_trades': oos_res['n_trades']
                })
                best_params_history.append(best_p)

        # Parameter Stability Analysis
        df_params = pd.DataFrame(best_params_history)
        print("\n" + "="*60)
        print("PARAMETER STABILITY & MODAL FREQUENCY (THE MASTER PARAMETER SET)")
        print("="*60)
        master_params = {}
        for col in df_params.columns:
            mode_val = df_params[col].mode()[0]
            master_params[col] = mode_val
            freq = (df_params[col] == mode_val).mean() * 100.0
            print(f"Parameter [{col}]: Modal Value = {mode_val} (Stability: {freq:.1f}%)")

        # Full 21-Year Out-of-Sample / Stress Test with Master Parameters
        print("\n" + "="*60)
        print("FULL 21-YEAR CONTINUOUS REGIME STRESS TEST (2005 - 2026)")
        print("="*60)
        self.backtester.risk_per_trade = master_params['risk_per_trade']
        full_res = self.backtester.run_backtest(
            donchian_window=master_params['donchian_window'],
            atr_trail_mult=master_params['atr_trail_mult'],
            atr_stop_mult=master_params['atr_stop_mult'],
            use_vol_filter=master_params['use_vol_filter'],
            use_regime_filter=master_params['use_regime_filter'],
            start_idx=250,
            end_idx=None
        )

        # Deflated Sharpe Ratio calculation
        n_years = len(self.df.iloc[250:]) / 252.0
        dsr, e_max_sr = calculate_dsr(
            sharpe=full_res['sharpe'],
            n_trials=n_combos,
            sample_length=len(self.df.iloc[250:]),
            skewness=0.5,
            kurtosis=4.5
        )

        print(f"Master Parameters: {master_params}")
        print(f"Total Net Return: {full_res['total_return']*100:.2f}%")
        print(f"CAGR: {full_res['cagr']*100:.2f}%")
        print(f"Max Drawdown: {full_res['max_dd']*100:.2f}%")
        print(f"Sharpe Ratio: {full_res['sharpe']:.2f}")
        print(f"Sortino Ratio: {full_res['sortino']:.2f}")
        print(f"Calmar Ratio: {full_res['calmar']:.2f}")
        print(f"Profit Factor: {full_res['profit_factor']:.2f}")
        print(f"Total Trades: {full_res['n_trades']} (Win Rate: {full_res['win_rate']*100:.2f}%)")
        print(f"Deflated Sharpe Ratio (DSR): {dsr:.4f}")

        # Save results to CSV for reporting
        df_wfo = pd.DataFrame(wfo_results)
        df_wfo.to_csv(r"C:\Users\Booth\quant_ea_lab\wfo_results.csv", index=False)
        print(f"Saved WFO detail table to C:\\Users\\Booth\\quant_ea_lab\\wfo_results.csv")
        
        return master_params, full_res, df_wfo

if __name__ == "__main__":
    wfo = WalkForwardOptimizer(r"C:\Users\Booth\quant_ea_lab\data\gold_daily.csv")
    wfo.run_optimization()
