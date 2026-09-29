import os
import glob

appdata = os.environ.get("APPDATA", "")
terminal_dir = os.path.join(appdata, "MetaQuotes", "Terminal")

print("Checking MetaQuotes Terminal directory:", terminal_dir)
if os.path.exists(terminal_dir):
    instances = os.listdir(terminal_dir)
    print(f"Found {len(instances)} items:")
    for inst in instances:
        p = os.path.join(terminal_dir, inst)
        if os.path.isdir(p) and len(inst) == 32: # MT5 instance hash
            mql5_dir = os.path.join(p, "MQL5", "Experts")
            print(f"  Instance: {inst} -> MQL5 Experts: {os.path.exists(mql5_dir)}")
            if os.path.exists(mql5_dir):
                print(f"  MQL5 Experts Path: {mql5_dir}")
