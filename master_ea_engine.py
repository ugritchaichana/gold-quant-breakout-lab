"""
Master Gold Breakout Engine - Python Autonomous Execution & Live Forward-Testing Runner
Grounded in Walk-Forward Robustness Plateau Analysis
"""

import time
import datetime
import numpy as np
import pandas as pd

class MasterGoldEngine:
    def __init__(self, symbol="XAUUSD", initial_balance=10000.0,
                 donchian_window=24, atr_trail_mult=4.0, atr_stop_mult=2.0,
                 min_adx=18.0, risk_pct=0.015):
        self.symbol = symbol
        self.balance = initial_balance
        self.equity = initial_balance
        self.high_water_mark = initial_balance
        
        # Master Parameters
        self.donchian_window = donchian_window
        self.atr_trail_mult = atr_trail_mult
        self.atr_stop_mult = atr_stop_mult
        self.min_adx = min_adx
        self.risk_pct = risk_pct
        
        # State Tracking
        self.in_position = False
        self.entry_price = 0.0
        self.stop_loss = 0.0
        self.peak_price = 0.0
        self.position_size = 0.0
        self.bars_in_trade = 0
        self.trade_history = []
        self.is_frozen = False

    def update_account(self, unrealized_pnl=0.0):
        self.equity = self.balance + unrealized_pnl
        if self.balance > self.high_water_mark:
            self.high_water_mark = self.balance
            
        current_dd_pct = ((self.high_water_mark - self.equity) / self.high_water_mark) * 100.0
        return current_dd_pct

    def on_bar(self, bar_df):
        """
        Receives latest OHLCV bar history and executes trading logic.
        """
        current_dd = self.update_account()
        
        # Tier 3 Circuit Breaker
        if current_dd >= 15.0:
            if not self.is_frozen:
                print(f"[CIRCUIT BREAKER] Tier 3 Triggered: Max Drawdown {current_dd:.2f}%. Liquidating and Freezing System!")
                self.close_position(bar_df['Close'].iloc[-1], "Tier 3 Circuit Breaker")
                self.is_frozen = True
            return

        # Tier 2 Circuit Breaker
        if current_dd >= 10.0 and self.in_position:
            print(f"[CIRCUIT BREAKER] Tier 2 Triggered: Drawdown {current_dd:.2f}%. De-leveraging position.")
            self.close_position(bar_df['Close'].iloc[-1], "Tier 2 Circuit Breaker")
            return

        # Calculate Indicators
        df = bar_df.copy()
        high_low = df['High'] - df['Low']
        high_close = (df['High'] - df['Close'].shift(1)).abs()
        low_close = (df['Low'] - df['Close'].shift(1)).abs()
        tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        atr14 = tr.rolling(14).mean().iloc[-1]
        
        ema200 = df['Close'].ewm(span=200, adjust=False).mean().iloc[-1]
        ema800 = df['Close'].ewm(span=800, adjust=False).mean().iloc[-1]
        
        # ADX(14)
        up_move = df['High'] - df['High'].shift(1)
        down_move = df['Low'].shift(1) - df['Low']
        plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0.0)
        minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)
        tr_smooth = tr.rolling(14).sum()
        plus_di = 100.0 * (pd.Series(plus_dm, index=df.index).rolling(14).sum() / tr_smooth).iloc[-1]
        minus_di = 100.0 * (pd.Series(minus_dm, index=df.index).rolling(14).sum() / tr_smooth).iloc[-1]
        dx = 100.0 * abs(plus_di - minus_di) / (plus_di + minus_di)
        adx14 = dx # single bar approximation or rolling
        
        curr_close = df['Close'].iloc[-1]
        curr_high = df['High'].iloc[-1]
        curr_low = df['Low'].iloc[-1]
        
        # Donchian Channel
        upper_donchian = df['High'].iloc[-self.donchian_window-1:-1].max()

        # 1. Manage Active Position
        if self.in_position:
            self.bars_in_trade += 1
            if curr_high > self.peak_price:
                self.peak_price = curr_high
                
            # Chandelier Trailing Stop
            chandelier_sl = self.peak_price - (self.atr_trail_mult * atr14)
            if chandelier_sl > self.stop_loss:
                self.stop_loss = chandelier_sl

            # Exit Checks
            if curr_low <= self.stop_loss:
                self.close_position(self.stop_loss, "Trailing Stop")
            elif curr_close < ema200:
                self.close_position(curr_close, "Macro Regime Breach (< EMA200)")
            elif self.bars_in_trade >= 120 and (curr_close - self.entry_price) < (0.5 * atr14):
                self.close_position(curr_close, "Time Stagnation Exit")

        # 2. Check New Entry
        elif not self.is_frozen:
            is_breakout = curr_high > upper_donchian
            is_trend = (curr_close > ema200) and (curr_close > ema800)
            is_momentum = (plus_di > minus_di)
            
            if is_breakout and is_trend and is_momentum:
                risk_effective = self.risk_pct * 0.5 if current_dd >= 5.0 else self.risk_pct
                stop_dist = self.atr_stop_mult * atr14
                if stop_dist > 0:
                    risk_dollars = self.equity * risk_effective
                    units = risk_dollars / stop_dist
                    self.entry_position(curr_close, stop_dist, units)

    def entry_position(self, price, stop_dist, units):
        self.in_position = True
        self.entry_price = price
        self.stop_loss = price - stop_dist
        self.peak_price = price
        self.position_size = units
        self.bars_in_trade = 0
        print(f"[ORDER BUY] Price: {price:.2f} | SL: {self.stop_loss:.2f} | Size: {units:.2f} oz")

    def close_position(self, exit_price, reason):
        pnl = self.position_size * (exit_price - self.entry_price)
        self.balance += pnl
        self.equity = self.balance
        self.trade_history.append({
            'entry': self.entry_price,
            'exit': exit_price,
            'pnl': pnl,
            'reason': reason,
            'balance': self.balance
        })
        print(f"[ORDER CLOSE] Exit: {exit_price:.2f} | PnL: ${pnl:.2f} | Reason: {reason} | Balance: ${self.balance:.2f}")
        self.in_position = False
        self.position_size = 0.0

if __name__ == "__main__":
    print("Master Gold Engine initialized and ready for Forward Testing feed.")
