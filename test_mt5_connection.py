import MetaTrader5 as mt5

paths = [
    r"C:\Program Files\IUX Markets MT5 Terminal\terminal64.exe",
    r"C:\Program Files\MetaTrader 5\terminal64.exe"
]

for p in paths:
    print(f"\n--- Testing connection with: {p} ---")
    if not mt5.initialize(path=p):
        print(f"Failed to initialize MT5 at {p}, error code: {mt5.last_error()}")
    else:
        print("SUCCESS! Initialized MT5.")
        version = mt5.version()
        print(f"MT5 Version: {version}")
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print(f"Terminal Name: {terminal_info.name} | Connected: {terminal_info.connected} | Path: {terminal_info.path}")
        account_info = mt5.account_info()
        if account_info:
            print(f"Account Login: {account_info.login} | Server: {account_info.server} | Balance: {account_info.balance} {account_info.currency}")
        else:
            print("No active account logged in or account_info is None.")
        
        # Check symbols
        symbols = mt5.symbols_get()
        print(f"Total symbols available: {len(symbols) if symbols else 0}")
        if symbols:
            gold_matches = [s.name for s in symbols if "XAU" in s.name.upper() or "GOLD" in s.name.upper()]
            print(f"Gold symbol variants: {gold_matches[:10]}")
            
        mt5.shutdown()
