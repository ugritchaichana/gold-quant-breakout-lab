import os
import subprocess
import time

terminal_path = r"C:\Program Files\IUX Markets MT5 Terminal\terminal64.exe"
ini_path = r"C:\Users\Booth\quant_ea_lab\tester.ini"
report_path = r"C:\Users\Booth\quant_ea_lab\mt5_tester_report.htm"

ini_content = f"""[Common]
Server=IUXMarkets-Live

[Tester]
Expert=Master_Gold_Breakout_EA
Symbol=XAUUSD.iux
Period=H1
Deposit=10000
Currency=USD
Leverage=100
Model=1
ExecutionMode=0
Optimization=0
FromDate=2026.01.01
ToDate=2026.09.28
Report={report_path}
ReplaceReport=1
ShutdownTerminal=1
"""

with open(ini_path, "w", encoding="utf-8") as f:
    f.write(ini_content)

print(f"Executing MT5 Strategy Tester via: {terminal_path} /config:{ini_path}")
res = subprocess.run([terminal_path, f"/config:{ini_path}"], capture_output=True, text=True, timeout=120)
print("Return code:", res.returncode)
if os.path.exists(report_path):
    print("SUCCESS: MT5 Tester Report generated at:", report_path)
else:
    print("Report file not created yet or terminal still finishing.")
