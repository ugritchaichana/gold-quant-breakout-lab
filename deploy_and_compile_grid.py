import os
import shutil
import subprocess

source_ea = r"C:\Users\Booth\quant_ea_lab\Master_Gold_Scalper_Grid.mq5"
metaeditor = r"C:\Program Files\MetaTrader 5\MetaEditor64.exe"

instances = [
    r"C:\Users\Booth\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075",
    r"C:\Users\Booth\AppData\Roaming\MetaQuotes\Terminal\3EFD9CBD5D42C604C5FB210C49B55791"
]

for inst in instances:
    if os.path.exists(inst):
        target_dir = os.path.join(inst, "MQL5", "Experts")
        os.makedirs(target_dir, exist_ok=True)
        target_file = os.path.join(target_dir, "Master_Gold_Scalper_Grid.mq5")
        shutil.copyfile(source_ea, target_file)
        print(f"Copied EA to: {target_file}")
        
        log_file = os.path.join(inst, "compile_log_grid.txt")
        compile_cmd = [metaeditor, f"/compile:{target_file}", f"/log:{log_file}"]
        res = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=30)
        
        ex5_file = target_file.replace(".mq5", ".ex5")
        if os.path.exists(log_file):
            with open(log_file, "rb") as f:
                log_content = f.read().decode("utf-16", errors="ignore").strip()
            print("Compile Log Output:")
            print(log_content)
        
        if os.path.exists(ex5_file):
            print(f"SUCCESS: Compiled .ex5 generated: {ex5_file} ({os.path.getsize(ex5_file)} bytes)")
        else:
            print(f"FAILED: .ex5 not found for {inst}")
