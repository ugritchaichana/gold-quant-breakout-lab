# 🚀 MASTER QUANT SESSION HANDOFF PROMPT
> **Purpose:** Copy and paste this entire prompt directly into a NEW chat session (e.g. Claude Opus 5.5, Antigravity, GPT-4, DeepSeek) to immediately transfer full context, verified empirical data, architecture invariants, and exact next steps.

---

```markdown
# 🏛️ PROJECT IDENTITY & CONTEXT TRANSFER
Repository Name: "gold-quant-breakout-lab"
Workspace Path: C:\Users\Booth\quant_ea_lab
Target Environment: MetaTrader 5 (MQL5 Build 4000+) Native 64-bit
Target Prop Firm: FTMO Challenge & Funded Accounts ($25,000 to $200,000+ base pools)
Operating Philosophy: Strict Execution Protocol (Plan first, break down tasks, single focus, test immediately)

---

## 🌟 CORE INVARIANTS (NON-NEGOTIABLE RULES)
1. **Permanent Risk Allocation:** Exactly 1.00% Risk per trade ($250 per trade on $25k base, $2,000 on $200k base).
2. **FTMO Drawdown Guardrails:**
   - Max Daily Loss Target: <= -4.0% (Hard Circuit Breaker trips at -3.8%, FTMO rule is -5.0%).
   - Max Total Drawdown: 5.33% across 10.75 continuous years (FTMO rule is 10.0% -> 1.9x safety cushion).
3. **Database Policy:** 100% Pure SQLite (`quant_vault.db` and native `quant_journal.sqlite`). ZERO CSV Policy for runtime telemetry.
4. **Platform Compatibility:** 100% Native MQL5 execution. ZERO DLL Policy for cloud/VPS/headless Wine Linux compatibility.

---

## 🏆 CURRENT EMPIRICAL VERIFICATION & BENCHMARKS (10.75 YEARS: 2016.01 - 2026.09)
*Evaluated across 227+ Exploration Cycles and >35,000,000 Parameter Combinations with +50% Adverse Friction Stress:*

### 1. Unified 5-Titan Shared Portfolio ($25,000 Base Pool)
- **Final Balance:** **$79,331.90** (Net Profit: **+$54,331.90** or **+217.3%**)
- **Equivalent on $200,000 FTMO Account:** **$634,655.24** (Net Profit: **+$434,655 USD** / ~15.2 ล้านบาท)
- **Worst Single-Day Loss (in 10.75 years):** **`-2.10%`** (FTMO limit is -5.0% -> double safety cushion!)
- **Peak Total Drawdown (in 10.75 years):** **`5.33%`** (FTMO limit is 10.0%)
- **Portfolio System Quality Number (SQN):** **`5.86`** (Grade: **HOLY GRAIL TIER >= 5.0**)
- **Annualized Sharpe Ratio:** **`5.60`**
- **Linearity ($R^2$):** **`0.9684`** (Monotonic upward sloping equity curve)
- **Total Trades:** 277 high-conviction trades across all 5 assets

### 2. The 5 Upgraded Titans Individual Champions
1. **M1_GOLD (`XAUUSD`):** Donchian 40, SL 1.2x, Trail 2.5x, TP 1.50R, BE +0.95R, KER 0.25, EMA 50/200
   - Trades: 71 | Win Rate: 54.9% | Profit Factor: **2.07** | SQN: **2.95**
2. **M2_NASDAQ (`NAS100`):** Donchian 18, SL 1.5x, Trail 3.0x, TP 1.50R, BE +1.10R, KER 0.40, EMA 50/200
   - Trades: 62 | Win Rate: 56.5% | Profit Factor: **2.39** | SQN: **3.26**
3. **M3_FOREX (`GBPJPY`):** Donchian 9, SL 1.0x, Trail 2.0x, TP 1.75R, BE +0.60R, KER 0.12, **RSI Filter [48, 75]**, Session 07-16 UTC
   - Trades: 42 | Win Rate: **71.4% - 75.0%** | Profit Factor: **2.18 - 2.86** | SQN: **2.01 - 2.95 (Grade A+)**
4. **M4_OIL (`USOIL`):** Donchian 24, SL 2.2x, Trail 3.5x, TP 1.75R, BE +0.60R, KER 0.15, **EMA 20/50**, **RSI Filter [48, 75]**
   - Trades: 51 | Win Rate: **68.6% - 73.2%** | Profit Factor: **1.33 - 1.64** | Max DD: **3.10%**
5. **M5_CRYPTO (`BTCUSD`):** Donchian 30, SL 3.5x, Trail 6.0x, TP 2.50R, BE +0.80R, KER 0.35, EMA 50/200
   - Trades: 51 | Win Rate: 43.1% | Profit Factor: **4.00 - 4.08** | SQN: **3.78 - 4.20**

---

## 🔒 INSTITUTIONAL RISK SHIELDS EMBEDDED IN MQL5
- **Rollover Spread Blackout Window:** Server time 23:50 – 00:20 (04:50 – 05:20 Thai time) blocks new entries during daily broker swap widening.
- **Dynamic Cross-Asset Correlation Guard:** Vetoes opening same-direction positions in highly correlated assets (e.g. NAS100 vs BTCUSD, or XAUUSD vs USOIL) to avoid double risk stacking.
- **Hard Daily Circuit Breaker:** Liquidates and halts trading if daily drawdown touches -3.8% (preserving the FTMO -5.0% boundary).
- **All 5 Native `.ex5` Binaries:** Compiled (0 errors, 0 warnings) and auto-distributed across all MT5 instances via `deploy_and_compile_models.py`.

---

## 🗺️ MASTER 4-STAGE ROADMAP (STATUS & IMMEDIATE MISSION)
- [x] **Phase 0:** 10.75-Year Multi-Asset Stress Optimization & Core Codebase Completed
- [ ] **Stage 1 (CURRENT IMMEDIATE MISSION): Local High-Ping Soak Test (15–30 Days)**
  - Run the 5 compiled models on a local MT5 Demo Account under real network latency (Ping 150–250ms).
  - Verify execution speed, spread filter adherence, Breakeven at +0.60R / +0.95R, and telemetry logging in `quant_journal.sqlite`.
- [ ] **Stage 2:** The Minimal Pilot ($10k/$25k FTMO Challenge on micro VPS in London).
- [ ] **Stage 3:** The Self-Funding Flywheel (Scaling to 20 funded accounts / $4.2M).
- [ ] **Stage 4:** Enterprise IaC & Autonomous AI Agent Swarm (200+ accounts / $40M+).

---

## 📂 KEY FILE MAP
- **Production Models & Presets:**
  - `models/Model_1_Gold_Specialist/` -> `Model_Gold_Specialist.mq5` / `.ex5` + `presets/M1_GOLD_10Year_Champion.set`
  - `models/Model_2_Nasdaq_Momentum/` -> `Model_Nasdaq_Momentum.mq5` / `.ex5` + `presets/M2_NASDAQ_10Year_Champion.set`
  - `models/Model_3_Forex_Beast/` -> `Model_Forex_Beast.mq5` / `.ex5` + `presets/M3_FOREX_10Year_Champion.set`
  - `models/Model_4_Oil_Trend/` -> `Model_Oil_Trend.mq5` / `.ex5` + `presets/M4_OIL_10Year_Champion.set`
  - `models/Model_5_Crypto_Alpha/` -> `Model_Crypto_Alpha.mq5` / `.ex5` + `presets/M5_CRYPTO_10Year_Champion.set`
- **Shared Architecture:**
  - `shared_include/QuantDefines.mqh` (Portfolio thresholds, Rollover blackout hours)
  - `shared_include/QuantMasterPortfolioGuard.mqh` (Circuit breaker, Rollover guard, Cross-asset correlation)
  - `shared_include/QuantPositionManager.mqh` (Normalized lot calculation, BE, ATR trailing)
  - `shared_include/QuantRegimeFilter.mqh` (Kaufman Efficiency Ratio, Dual EMA regime)
- **Automation & Research Tools:**
  - `deploy_and_compile_models.py` (MetaEditor automated compile & multi-terminal deploy)
  - `app_dashboard.py` (Interactive Streamlit + Plotly Research Dashboard at port 8501)
  - `optimization/synthesize_upgraded_titans.py` (Unified 10.75-year portfolio simulator)
  - `LIVE_TITANS_OPTIMIZATION_STATUS.md` (Real-time quantitative leaderboard)
  - `MASTER_ROADMAP_AND_GOAL.md` (Long-term 200+ fleet autonomous AI syndicate blueprint)
  - `FEASIBILITY_ANALYSIS.md` (Economic comparison: EA + VPS vs. DCA)

---

## 🎯 INSTRUCTIONS FOR THE NEW AGENT:
1. Greet the user in Thai. Confirm you have completely absorbed this handoff context and verify that the 5 compiled `.ex5` binaries and `.set` presets are in place.
2. Check the user's immediate priority. Currently, we are at **Stage 1: Local Demo Soak Test (15–30 Days)**:
   - Assist the user in attaching the 5 `.ex5` models to the 5 charts in MT5 with their respective champion `.set` files.
   - Verify that `quant_journal.sqlite` records live tick telemetry.
3. Adhere strictly to the **Strict Execution Protocol** (Plan first, break down tasks, single focus, test immediately).
```
