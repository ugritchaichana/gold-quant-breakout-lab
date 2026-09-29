# 🏆 Institutional Gold Quant Research Lab (`XAUUSD`)

An institutional-grade algorithmic quantitative research repository for Gold (`XAUUSD`), featuring a multi-timeframe volatility breakout trading system, an autonomous 12-core continuous optimization engine, an indexed SQLite vault (5M+ permutations), and an interactive Streamlit Web Dashboard.

---

## 📊 Executive Summary & Validated Performance

Tested across **5,041,432 parameter combinations** using **MetaTrader 5 "Every tick based on real ticks"** with an injected **100ms artificial broker delay**, spread safety filter ($\le \$0.60$), and strict 3-tier circuit breakers (5% lot halving / 10% halt / 15% kill-switch):

| Metric | Champion (M15 Momentum) | True MTF Hybrid (H1 + M15) | Baseline H1 |
| :--- | :---: | :---: | :---: |
| **Full 1-Year CAGR** | **`+324.2%`** | **`+241.3%`** | `+81.8%` |
| **OOS Forward CAGR (Recent Market)** | **`+106.5%`** | **`+157.2% - +227.1%`** | `+65.7%` |
| **Max Relative Drawdown** | **`-19.8%`** | **`-18.0%`** | `-21.8%` |
| **Profit Factor** | **`2.13`** | **`1.69`** | `1.08` |
| **Recovery Factor** | **`16.3`** | **`13.4`** | `3.7` |

---

## 🛠️ Repository Architecture

- **`Master_Gold_Breakout_EA.mq5`**: The production MetaTrader 5 Expert Advisor with Multi-Timeframe support, Donchian rolling 24-hour channel, Volatility Parity sizing, Chandelier trailing stops, and 3-Tier equity drawdown protection.
- **`app_dashboard.py`**: Interactive Streamlit Web Application for screening, filtering (CAGR, DD, PF), visualizing Pareto Frontier (Risk vs Return), and 1-click generating MT5 `.set` preset files.
- **`continuous_quant_engine.py`**: Distributed 12-core multiprocessing optimization engine performing rolling parameter evaluations across H1, M30, and M15.
- **`run_3way_showdown.py`**: Rigorous comparative walk-forward showdown script testing H1 vs M15 vs True Multi-Timeframe.
- **`CLAUDE_OPUS_MASTER_PROMPT.md`**: Advanced mathematical blueprint and quantitative interview prompt designed for Claude Opus 5.5.
- **Presets (`.set`)**:
  - `Master_Gold_MTF_Champion_100ms.set`: True MTF hybrid preset.
  - `Master_Gold_Breakout_Champion.set`: Optimized baseline preset.

---

## 🚀 Quickstart

### 1. Launching the Web Dashboard
```bash
streamlit run app_dashboard.py --server.port 8501
```
Open [http://localhost:8501](http://localhost:8501) to explore the 5M+ strategy database interactively.

### 2. Running Continuous Optimization
```bash
python continuous_quant_engine.py
```

### 3. Deploying to MetaTrader 5
Compile `Master_Gold_Breakout_EA.mq5` in MetaEditor and attach to `XAUUSD` on M15 with `InpMacroTimeframe = PERIOD_H1`.

---

## 🛡️ License
Private & Proprietary Institutional Quant Repository.
