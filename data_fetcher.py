import os
import yfinance as yf
import pandas as pd

def fetch_and_save_data():
    data_dir = r"C:\Users\Booth\quant_ea_lab\data"
    os.makedirs(data_dir, exist_ok=True)
    
    # 1. Gold Futures (GC=F) - Proxy for Gold Spot XAU/USD
    print("Fetching Gold data (GC=F)...")
    gold = yf.download("GC=F", start="2005-01-01", interval="1d", auto_adjust=False)
    if isinstance(gold.columns, pd.MultiIndex):
        gold.columns = gold.columns.get_level_values(0)
    gold = gold[['Open', 'High', 'Low', 'Close', 'Volume']].dropna()
    gold_path = os.path.join(data_dir, "gold_daily.csv")
    gold.to_csv(gold_path)
    print(f"Saved Gold daily data: {len(gold)} bars to {gold_path}")
    print(f"Date range: {gold.index[0]} to {gold.index[-1]}")
    
    # 2. S&P 500 ETF (SPY)
    print("Fetching SPY data...")
    spy = yf.download("SPY", start="2005-01-01", interval="1d", auto_adjust=False)
    if isinstance(spy.columns, pd.MultiIndex):
        spy.columns = spy.columns.get_level_values(0)
    spy = spy[['Open', 'High', 'Low', 'Close', 'Volume']].dropna()
    spy_path = os.path.join(data_dir, "spy_daily.csv")
    spy.to_csv(spy_path)
    print(f"Saved SPY daily data: {len(spy)} bars to {spy_path}")
    
    # 3. Gold ETF (GLD)
    print("Fetching GLD data...")
    gld = yf.download("GLD", start="2005-01-01", interval="1d", auto_adjust=False)
    if isinstance(gld.columns, pd.MultiIndex):
        gld.columns = gld.columns.get_level_values(0)
    gld = gld[['Open', 'High', 'Low', 'Close', 'Volume']].dropna()
    gld_path = os.path.join(data_dir, "gld_daily.csv")
    gld.to_csv(gld_path)
    print(f"Saved GLD daily data: {len(gld)} bars to {gld_path}")
    
    # 4. Hourly data (last 730 days for fine-grained intraday verification)
    print("Fetching Gold hourly data (recent 730d)...")
    gold_h1 = yf.download("GC=F", period="730d", interval="1h", auto_adjust=False)
    if isinstance(gold_h1.columns, pd.MultiIndex):
        gold_h1.columns = gold_h1.columns.get_level_values(0)
    gold_h1 = gold_h1[['Open', 'High', 'Low', 'Close', 'Volume']].dropna()
    gold_h1_path = os.path.join(data_dir, "gold_hourly.csv")
    gold_h1.to_csv(gold_h1_path)
    print(f"Saved Gold hourly data: {len(gold_h1)} bars to {gold_h1_path}")

if __name__ == "__main__":
    fetch_and_save_data()
