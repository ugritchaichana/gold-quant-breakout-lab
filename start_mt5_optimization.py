import os
import subprocess

terminal_path = r"C:\Program Files\IUX Markets MT5 Terminal\terminal64.exe"
ini_path = r"C:\Users\Booth\quant_ea_lab\tester_opt.ini"
report_path = r"C:\Users\Booth\quant_ea_lab\mt5_optimization_report.htm"

# In MT5 ini format:
# param_name=Value||Start||Step||Stop||[Y/N]
ini_content = f"""[Common]
Server=IUXMarkets-Live

[Tester]
Expert=Master_Gold_Scalper_Grid
Symbol=XAUUSD.iux
Period=M15
Deposit=10000
Currency=USD
Leverage=100
Model=1
ExecutionMode=0
Optimization=2
OptimizationCriterion=6
FromDate=2021.01.01
ToDate=2026.09.28
ForwardMode=1
ForwardDate=2025.01.01
Report={report_path}
ReplaceReport=1
ShutdownTerminal=0

[TesterInputs]
InpTrendEMA=200||200||0||0||N
InpMacroEMA=800||800||0||0||N
InpATRPeriod=14||14||0||0||N
InpRSI期的=14||14||0||0||N
InpRSIOversold=35.0||25.0||5.0||40.0||Y
InpRSIOverbought=65.0||60.0||5.0||75.0||Y
InpGridStepATR=1.2||0.8||0.2||2.0||Y
InpTakeProfitATR=2.0||1.5||0.5||3.5||Y
InpMaxGridOrders=4||3||1||6||Y
InpLotMultiplier=1.25||1.15||0.1||1.35||Y
InpBasketTPUSD=75.0||50.0||25.0||150.0||Y
InpBaseRiskPercent=2.0||1.5||0.5||3.0||Y
InpMaxSpreadUSD=0.50||0||0||0||N
InpAutoCompound=true||0||0||0||N
InpMaxBasketLossPct=15.0||0||0||0||N
InpMaxDailyLossPct=18.0||0||0||0||N
InpMagicNumber=999111||0||0||0||N
InpTradeComment=Master_Scalp_Grid||0||0||0||N
"""

with open(ini_path, "w", encoding="utf-8") as f:
    f.write(ini_content)

print(f"Created MT5 Optimization Config: {ini_path}")
print(f"Launching MT5 Terminal with 12 Core Agents: {terminal_path} /config:{ini_path}")

proc = subprocess.Popen([terminal_path, f"/config:{ini_path}"])
print(f"MT5 Process started successfully (PID: {proc.pid}).")
