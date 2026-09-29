import numpy as np
import pandas as pd

class GoldBreakoutBacktester:
    def __init__(self, data_path, initial_capital=100000.0, risk_per_trade=0.01):
        self.df = pd.read_csv(data_path, parse_dates=['Date'], index_col='Date')
        self.initial_capital = initial_capital
        self.risk_per_trade = risk_per_trade
        self.prepare_indicators()

    def prepare_indicators(self):
        df = self.df.copy()
        
        # Calculate True Range and ATR(14)
        high_low = df['High'] - df['Low']
        high_close = (df['High'] - df['Close'].shift(1)).abs()
        low_close = (df['Low'] - df['Close'].shift(1)).abs()
        tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        df['ATR14'] = tr.rolling(window=14).mean()
        df['ATR_MA50'] = df['ATR14'].rolling(window=50).mean()
        
        # 200 SMA Macro Trend Filter
        df['SMA200'] = df['Close'].rolling(window=200).mean()
        
        self.df = df

    def run_backtest(self, donchian_window=20, atr_trail_mult=3.0, atr_stop_mult=2.5,
                     use_vol_filter=True, use_regime_filter=True, max_bars_hold=45,
                     spread_usd=0.35, slippage_usd=0.25, swap_annual_rate=-0.025,
                     start_idx=250, end_idx=None):
        """
        Executes an institutional friction-penalized simulation.
        Returns performance metrics and trade log.
        """
        df = self.df.iloc[start_idx:end_idx].copy()
        if len(df) < 50:
            return None

        # Precompute parameter-dependent Donchian channels
        # Note: shift(1) to avoid lookahead bias! Breakout is above previous N bars' high
        upper_channel = df['High'].shift(1).rolling(window=donchian_window).max().values
        lower_channel = df['Low'].shift(1).rolling(window=donchian_window).min().values

        closes = df['Close'].values
        highs = df['High'].values
        lows = df['Low'].values
        opens = df['Open'].values
        atr14 = df['ATR14'].values
        atr_ma50 = df['ATR_MA50'].values
        sma200 = df['SMA200'].values
        n_bars = len(df)
        dates = df.index

        equity = self.initial_capital
        equity_curve = [equity]
        trades = []
        
        in_position = False
        entry_price = 0.0
        position_size = 0.0
        stop_loss = 0.0
        highest_price = 0.0
        entry_bar = 0
        
        # Total friction per oz round-turn
        friction_per_unit = spread_usd + slippage_usd
        daily_swap_factor = swap_annual_rate / 252.0

        for i in range(1, n_bars):
            curr_close = closes[i]
            curr_high = highs[i]
            curr_low = lows[i]
            curr_open = opens[i]
            curr_atr = atr14[i]
            
            # Position Management (Exit logic)
            if in_position:
                bars_held = i - entry_bar
                # Apply daily swap interest drag
                equity += position_size * curr_close * daily_swap_factor
                
                # Update highest high reached during trade
                if curr_high > highest_price:
                    highest_price = curr_high
                
                # Chandelier Trailing Stop
                chandelier_stop = highest_price - (atr_trail_mult * curr_atr)
                if chandelier_stop > stop_loss:
                    stop_loss = chandelier_stop
                
                exit_triggered = False
                exit_price = 0.0
                exit_reason = ""

                # Check Stop Loss / Trailing Stop hit
                if curr_low <= stop_loss:
                    exit_triggered = True
                    # Fill price with slippage penalty
                    exit_price = min(curr_open, stop_loss) - slippage_usd
                    exit_reason = "Trailing/Stop Loss"
                
                # Check Macro Regime Breach (Price drops below SMA200)
                elif use_regime_filter and curr_close < sma200[i]:
                    exit_triggered = True
                    exit_price = curr_close - slippage_usd
                    exit_reason = "Regime Breach (Below SMA200)"
                
                # Check Stagnant Time Exit
                elif bars_held >= max_bars_hold and (curr_close - entry_price) < (0.5 * curr_atr):
                    exit_triggered = True
                    exit_price = curr_close - slippage_usd
                    exit_reason = "Time-Based Stagnation Exit"

                if exit_triggered:
                    gross_pnl = position_size * (exit_price - entry_price)
                    net_pnl = gross_pnl - (position_size * friction_per_unit)
                    equity += net_pnl
                    
                    trades.append({
                        'entry_date': dates[entry_bar],
                        'exit_date': dates[i],
                        'entry_price': entry_price,
                        'exit_price': exit_price,
                        'size': position_size,
                        'pnl': net_pnl,
                        'return_pct': (exit_price / entry_price) - 1.0,
                        'bars_held': bars_held,
                        'exit_reason': exit_reason
                    })
                    
                    in_position = False
                    position_size = 0.0
            
            # Entry Logic (Only if flat and past warmup)
            if not in_position and not np.isnan(upper_channel[i]) and not np.isnan(curr_atr):
                # 1. Breakout trigger: Current high breaks above upper Donchian
                breakout = curr_high > upper_channel[i]
                
                # 2. Macro Regime Filter: Price > SMA200
                regime_ok = (curr_close > sma200[i]) if use_regime_filter else True
                
                # 3. Volatility Expansion Filter: ATR14 > 50-day average ATR
                vol_ok = (curr_atr > atr_ma50[i]) if use_vol_filter else True
                
                if breakout and regime_ok and vol_ok:
                    # Realistic entry price: Max of Open and Breakout level + slippage
                    entry_price = max(curr_open, upper_channel[i]) + slippage_usd
                    
                    # Initial Stop Loss
                    stop_distance = atr_stop_mult * curr_atr
                    if stop_distance > 0:
                        stop_loss = entry_price - stop_distance
                        
                        # Position Sizing: Risk exactly 1% of total equity
                        risk_capital = equity * self.risk_per_trade
                        position_size = risk_capital / stop_distance
                        
                        # Cap max leverage: Maximum 3.0x portfolio leverage
                        max_units = (equity * 3.0) / entry_price
                        position_size = min(position_size, max_units)
                        
                        in_position = True
                        highest_price = entry_price
                        entry_bar = i

            equity_curve.append(equity)

        # Performance Metrics Calculation
        equity_series = pd.Series(equity_curve)
        returns = equity_series.pct_change().dropna()
        
        total_days = (dates[-1] - dates[0]).days
        years = max(total_days / 365.25, 0.1)
        total_return = (equity / self.initial_capital) - 1.0
        cagr = (equity / self.initial_capital) ** (1.0 / years) - 1.0 if equity > 0 else -1.0
        
        # Maximum Drawdown
        running_max = equity_series.cummax()
        drawdowns = (equity_series - running_max) / running_max
        max_dd = drawdowns.min()
        
        # Risk-Adjusted Ratios
        ann_vol = returns.std() * np.sqrt(252) if len(returns) > 1 else 0.0
        risk_free = 0.025
        sharpe = (cagr - risk_free) / ann_vol if ann_vol > 0 else 0.0
        
        downside_returns = returns[returns < 0]
        downside_vol = downside_returns.std() * np.sqrt(252) if len(downside_returns) > 1 else 0.0
        sortino = (cagr - risk_free) / downside_vol if downside_vol > 0 else 0.0
        calmar = cagr / abs(max_dd) if max_dd < 0 else 0.0
        
        n_trades = len(trades)
        win_trades = [t for t in trades if t['pnl'] > 0]
        win_rate = len(win_trades) / n_trades if n_trades > 0 else 0.0
        
        gross_profit = sum(t['pnl'] for t in win_trades)
        gross_loss = abs(sum(t['pnl'] for t in trades if t['pnl'] <= 0))
        profit_factor = gross_profit / gross_loss if gross_loss > 0 else (999.0 if gross_profit > 0 else 0.0)

        return {
            'cagr': cagr,
            'total_return': total_return,
            'max_dd': max_dd,
            'sharpe': sharpe,
            'sortino': sortino,
            'calmar': calmar,
            'volatility': ann_vol,
            'n_trades': n_trades,
            'win_rate': win_rate,
            'profit_factor': profit_factor,
            'final_equity': equity,
            'trades': trades,
            'equity_curve': equity_series
        }

if __name__ == "__main__":
    backtester = GoldBreakoutBacktester(r"C:\Users\Booth\quant_ea_lab\data\gold_daily.csv")
    res = backtester.run_backtest()
    print("Baseline Test Result (2005-2026):")
    print(f"Total Return: {res['total_return']*100:.2f}% | CAGR: {res['cagr']*100:.2f}%")
    print(f"Max Drawdown: {res['max_dd']*100:.2f}% | Sharpe: {res['sharpe']:.2f} | Sortino: {res['sortino']:.2f}")
    print(f"Trades: {res['n_trades']} | Win Rate: {res['win_rate']*100:.2f}% | Profit Factor: {res['profit_factor']:.2f}")
