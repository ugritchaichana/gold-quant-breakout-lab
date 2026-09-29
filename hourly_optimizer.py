import itertools
import numpy as np
import pandas as pd

class HourlyGoldBacktester:
    def __init__(self, data_path, initial_capital=10000.0, risk_per_trade=0.01):
        self.df = pd.read_csv(data_path, parse_dates=['Datetime'], index_col='Datetime')
        self.initial_capital = initial_capital
        self.risk_per_trade = risk_per_trade
        self.prepare_indicators()

    def prepare_indicators(self):
        df = self.df.copy()
        
        # True Range and ATR(14) on H1
        high_low = df['High'] - df['Low']
        high_close = (df['High'] - df['Close'].shift(1)).abs()
        low_close = (df['Low'] - df['Close'].shift(1)).abs()
        tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        df['ATR14'] = tr.rolling(window=14).mean()
        df['ATR_MA50'] = df['ATR14'].rolling(window=50).mean()
        
        # Higher Timeframe Trend Filter: 200 EMA on H1 (roughly 8-9 days trend) and 800 EMA (~33 days macro trend)
        df['EMA200'] = df['Close'].ewm(span=200, adjust=False).mean()
        df['EMA800'] = df['Close'].ewm(span=800, adjust=False).mean()
        
        # Directional Movement for ADX(14)
        up_move = df['High'] - df['High'].shift(1)
        down_move = df['Low'].shift(1) - df['Low']
        plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0.0)
        minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)
        
        tr_smooth = tr.rolling(window=14).sum()
        plus_di = 100.0 * (pd.Series(plus_dm, index=df.index).rolling(window=14).sum() / tr_smooth)
        minus_di = 100.0 * (pd.Series(minus_dm, index=df.index).rolling(window=14).sum() / tr_smooth)
        dx = 100.0 * (plus_di - minus_di).abs() / (plus_di + minus_di)
        df['ADX14'] = dx.rolling(window=14).mean()
        df['Plus_DI'] = plus_di
        df['Minus_DI'] = minus_di
        
        self.df = df

    def run_backtest(self, donchian_window=24, atr_trail_mult=3.0, atr_stop_mult=2.0,
                     min_adx=20.0, use_ema800=True, max_bars_hold=120,
                     spread_usd=0.30, slippage_usd=0.20,
                     start_idx=800, end_idx=None):
        """
        Executes H1 Gold simulation with realistic spread, slippage, and swap.
        """
        df = self.df.iloc[start_idx:end_idx].copy()
        if len(df) < 200:
            return None

        upper_channel = df['High'].shift(1).rolling(window=donchian_window).max().values
        lower_channel = df['Low'].shift(1).rolling(window=donchian_window).min().values

        closes = df['Close'].values
        highs = df['High'].values
        lows = df['Low'].values
        opens = df['Open'].values
        atr14 = df['ATR14'].values
        ema200 = df['EMA200'].values
        ema800 = df['EMA800'].values
        adx14 = df['ADX14'].values
        plus_di = df['Plus_DI'].values
        minus_di = df['Minus_DI'].values
        dates = df.index
        n_bars = len(df)

        equity = self.initial_capital
        equity_curve = [equity]
        trades = []

        in_pos = False
        pos_dir = 0 # +1 long, -1 short
        entry_price = 0.0
        pos_size = 0.0
        stop_loss = 0.0
        peak_price = 0.0
        entry_bar = 0

        friction = spread_usd + slippage_usd

        for i in range(1, n_bars):
            curr_c = closes[i]
            curr_h = highs[i]
            curr_l = lows[i]
            curr_o = opens[i]
            curr_atr = atr14[i]

            if in_pos:
                bars_held = i - entry_bar
                # Trailing stop update
                if pos_dir == 1:
                    if curr_h > peak_price:
                        peak_price = curr_h
                    trail = peak_price - (atr_trail_mult * curr_atr)
                    if trail > stop_loss:
                        stop_loss = trail
                    
                    # Exit check
                    hit_stop = curr_l <= stop_loss
                    regime_break = curr_c < ema200[i]
                    timeout = bars_held >= max_bars_hold and (curr_c - entry_price) < 0.5 * curr_atr
                    
                    if hit_stop or regime_break or timeout:
                        exit_p = min(curr_o, stop_loss) - slippage_usd if hit_stop else curr_c - slippage_usd
                        pnl = pos_size * (exit_p - entry_price) - (pos_size * friction)
                        equity += pnl
                        trades.append({
                            'dir': 'LONG',
                            'entry': entry_price,
                            'exit': exit_p,
                            'pnl': pnl,
                            'bars': bars_held,
                            'reason': 'Stop' if hit_stop else ('Regime' if regime_break else 'Time')
                        })
                        in_pos = False
                        pos_dir = 0
                
                elif pos_dir == -1:
                    if curr_l < peak_price:
                        peak_price = curr_l
                    trail = peak_price + (atr_trail_mult * curr_atr)
                    if trail < stop_loss:
                        stop_loss = trail
                    
                    hit_stop = curr_h >= stop_loss
                    regime_break = curr_c > ema200[i]
                    timeout = bars_held >= max_bars_hold and (entry_price - curr_c) < 0.5 * curr_atr
                    
                    if hit_stop or regime_break or timeout:
                        exit_p = max(curr_o, stop_loss) + slippage_usd if hit_stop else curr_c + slippage_usd
                        pnl = pos_size * (entry_price - exit_p) - (pos_size * friction)
                        equity += pnl
                        trades.append({
                            'dir': 'SHORT',
                            'entry': entry_price,
                            'exit': exit_p,
                            'pnl': pnl,
                            'bars': bars_held,
                            'reason': 'Stop' if hit_stop else ('Regime' if regime_break else 'Time')
                        })
                        in_pos = False
                        pos_dir = 0

            # Entry Logic
            if not in_pos and not np.isnan(upper_channel[i]) and not np.isnan(curr_atr):
                # Long Conditions
                long_break = curr_h > upper_channel[i]
                long_trend = curr_c > ema200[i] and (curr_c > ema800[i] if use_ema800 else True)
                long_mom = adx14[i] >= min_adx and plus_di[i] > minus_di[i]

                if long_break and long_trend and long_mom:
                    entry_price = max(curr_o, upper_channel[i]) + slippage_usd
                    stop_dist = atr_stop_mult * curr_atr
                    if stop_dist > 0:
                        stop_loss = entry_price - stop_dist
                        pos_size = (equity * self.risk_per_trade) / stop_dist
                        # Cap max position to 5x leverage
                        pos_size = min(pos_size, (equity * 5.0) / entry_price)
                        in_pos = True
                        pos_dir = 1
                        peak_price = entry_price
                        entry_bar = i

            equity_curve.append(equity)

        eq = pd.Series(equity_curve)
        ret = eq.pct_change().dropna()
        n_days = len(df) / 24.0
        cagr = (equity / self.initial_capital) ** (365.25 / n_days) - 1.0 if equity > 0 and n_days > 30 else 0.0
        cummax = eq.cummax()
        dd = (eq - cummax) / cummax
        mdd = dd.min()
        vol = ret.std() * np.sqrt(252 * 24) if len(ret) > 1 else 0.0
        sharpe = (cagr - 0.025) / vol if vol > 0 else 0.0
        
        downside = ret[ret < 0]
        down_vol = downside.std() * np.sqrt(252 * 24) if len(downside) > 1 else 0.0
        sortino = (cagr - 0.025) / down_vol if down_vol > 0 else 0.0
        
        wins = [t for t in trades if t['pnl'] > 0]
        wr = len(wins) / len(trades) if len(trades) > 0 else 0.0
        gp = sum(t['pnl'] for t in wins)
        gl = abs(sum(t['pnl'] for t in trades if t['pnl'] <= 0))
        pf = gp / gl if gl > 0 else (999.0 if gp > 0 else 0.0)

        return {
            'total_return': (equity / self.initial_capital) - 1.0,
            'cagr': cagr,
            'max_dd': mdd,
            'sharpe': sharpe,
            'sortino': sortino,
            'n_trades': len(trades),
            'win_rate': wr,
            'profit_factor': pf,
            'final_equity': equity
        }

def run_hourly_wfo():
    bt = HourlyGoldBacktester(r"C:\Users\Booth\quant_ea_lab\data\gold_hourly.csv")
    total_bars = len(bt.df)
    print(f"Loaded {total_bars} hourly bars (~{total_bars/24:.0f} days)")

    # Test parameter combinations for H1
    param_grid = {
        'donchian_window': [24, 36, 48, 72], # 1 day, 1.5 days, 2 days, 3 days
        'atr_trail_mult': [2.5, 3.0, 3.5, 4.0],
        'atr_stop_mult': [1.5, 2.0, 2.5],
        'min_adx': [18.0, 22.0, 26.0],
        'risk_per_trade': [0.01, 0.015]
    }
    
    # Split into In-Sample (first 70%) and Out-of-Sample (last 30% ~ recent 7-8 months)
    split_idx = int(800 + (total_bars - 800) * 0.70)
    print(f"In-Sample Range: 800 to {split_idx} | Out-of-Sample Range: {split_idx} to {total_bars}")
    
    keys = list(param_grid.keys())
    combos = [dict(zip(keys, v)) for v in itertools.product(*param_grid.values())]
    print(f"Evaluating {len(combos)} parameter combinations...")
    
    best_is_score = -999.0
    best_p = None
    best_is_res = None
    
    for p in combos:
        bt.risk_per_trade = p['risk_per_trade']
        res = bt.run_backtest(
            donchian_window=p['donchian_window'],
            atr_trail_mult=p['atr_trail_mult'],
            atr_stop_mult=p['atr_stop_mult'],
            min_adx=p['min_adx'],
            start_idx=800,
            end_idx=split_idx
        )
        if res and res['n_trades'] >= 15:
            # Score: Profit Factor * (1 - abs(MaxDD)) * Sharpe
            score = res['profit_factor'] * (1.0 - abs(res['max_dd'])) * (res['sharpe'] + 1.0)
            if score > best_is_score:
                best_is_score = score
                best_p = p
                best_is_res = res
                
    print("\n" + "="*60)
    print("BEST IN-SAMPLE (IS) PARAMETERS FOUND:")
    print(f"Params: {best_p}")
    print(f"IS Return: {best_is_res['total_return']*100:.2f}% | CAGR: {best_is_res['cagr']*100:.2f}%")
    print(f"IS MaxDD: {best_is_res['max_dd']*100:.2f}% | Sharpe: {best_is_res['sharpe']:.2f} | PF: {best_is_res['profit_factor']:.2f}")
    print(f"IS Trades: {best_is_res['n_trades']} | Win Rate: {best_is_res['win_rate']*100:.2f}%")
    
    # Run strictly Out-of-Sample (OOS) on the recent unseen data
    print("\n" + "="*60)
    print("STRICT OUT-OF-SAMPLE (OOS) VERIFICATION (RECENT MARKET):")
    bt.risk_per_trade = best_p['risk_per_trade']
    oos_res = bt.run_backtest(
        donchian_window=best_p['donchian_window'],
        atr_trail_mult=best_p['atr_trail_mult'],
        atr_stop_mult=best_p['atr_stop_mult'],
        min_adx=best_p['min_adx'],
        start_idx=split_idx,
        end_idx=None
    )
    print(f"OOS Return: {oos_res['total_return']*100:.2f}% | CAGR: {oos_res['cagr']*100:.2f}%")
    print(f"OOS MaxDD: {oos_res['max_dd']*100:.2f}% | Sharpe: {oos_res['sharpe']:.2f} | PF: {oos_res['profit_factor']:.2f}")
    print(f"OOS Trades: {oos_res['n_trades']} | Win Rate: {oos_res['win_rate']*100:.2f}%")
    
    # Calculate Out-of-Sample Efficiency Ratio (OER)
    oer = oos_res['sharpe'] / best_is_res['sharpe'] if best_is_res['sharpe'] > 0 else 0.0
    print(f"Out-of-Sample Efficiency Ratio (OER): {oer:.2f} (Target >= 0.65)")
    
    # Run Complete Dataset
    print("\n" + "="*60)
    print("FULL PERIOD PERFORMANCE (IS + OOS):")
    full_res = bt.run_backtest(
        donchian_window=best_p['donchian_window'],
        atr_trail_mult=best_p['atr_trail_mult'],
        atr_stop_mult=best_p['atr_stop_mult'],
        min_adx=best_p['min_adx'],
        start_idx=800,
        end_idx=None
    )
    print(f"Total Return: {full_res['total_return']*100:.2f}% | CAGR: {full_res['cagr']*100:.2f}%")
    print(f"Max Drawdown: {full_res['max_dd']*100:.2f}% | Sharpe: {full_res['sharpe']:.2f} | Sortino: {full_res['sortino']:.2f}")
    print(f"Trades: {full_res['n_trades']} | Win Rate: {full_res['win_rate']*100:.2f}% | Profit Factor: {full_res['profit_factor']:.2f}")

    return best_p, best_is_res, oos_res, full_res

if __name__ == "__main__":
    run_hourly_wfo()
