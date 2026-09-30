# STRESS_TESTING_PROTOCOL.md — Severe Market Friction Audit (+25% to +50%)

> **Target Standard:** Institutional Prop Firm Defense Standard (FTMO Swing $25,000)  
> **Mandate:** All strategies must prove profitable and resilient under artificial degradation of market conditions by **+25% to +50% beyond normal live trading conditions**.

---

## 1. Rationale for Stress-Testing
Retail backtests fail in live production because they assume zero slippage, ideal spreads, and instantaneous fills. In reality:
- Spreads widen by 2x to 5x during market rollovers (00:00 server time) and economic releases (CPI, Non-Farm Payrolls).
- Execution latency introduces negative price slippage on fast breakout candles.
- Weekend gap risk can leap over stop-loss orders.

If a strategy is optimized to barely breakeven under zero-friction conditions, it will collapse immediately in live execution. **Only strategies that thrive under severe artificial penalties are certified for deployment.**

---

## 2. Quantitative Stress Penalty Matrix

| Asset Class | Symbol | Normal Spread | Stress Test Spread (+50%) | Slippage Penalty | Weekend Gap Veto |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Gold** | `XAUUSD` | 20 – 25 pts ($0.20 – $0.25) | **35 – 40 pts ($0.35 – $0.40)** | 1.0 ATR tick slip on fill | Standard hold |
| **Nasdaq** | `NAS100` | 80 – 100 pts ($0.80 – $1.00) | **150 pts ($1.50)** | 2.0 pts slip on entry | Close intra-day / session |
| **Forex** | `GBPJPY` | 18 – 22 pts (1.8 – 2.2 pips) | **35 pts (3.5 pips)** | 0.5 pip slip | Veto 21:00-06:00 UTC chop |
| **Oil** | `USOIL` | 25 – 30 pts ($0.025 – $0.03) | **45 pts ($0.045)** | 1.5 pts slip | Veto Friday evening entries |
| **Crypto** | `BTCUSD` | 200 – 250 pts ($2.00 – $2.50) | **400 pts ($4.00)** | 5.0 pts slip | Strict KER >= 0.40 veto |

---

## 3. Stress-Test Evaluation Metrics

Under +50% degraded friction, a parameter set must satisfy:
1. **Profit Factor (PF):** $\ge 1.30$ (Must remain net profitable with clear margin of safety).
2. **Maximum Drawdown (Max DD):** $\le 3.50\%$ (Must never threaten the 5.0% FTMO daily loss limit).
3. **Calmar Ratio:** $\ge 2.00$ (Return must remain at least double the worst peak-to-trough drawdown).
4. **System Quality Number (SQN):** $\ge 2.00$ (Statistically robust trade distribution).
5. **Equity Linearity ($R^2$):** $\ge 0.85$ (Equity curve must remain a monotonic upward trend).

---

## 4. Implementation in the Optimization Engine

In `optimization/titans_quant_engine.py`:
- Every trade fill price is modified by:
  $$\text{Fill Price}_{\text{Buy}} = \text{Price}_{\text{Ask}} + \text{SlippagePenalty}$$
  $$\text{Fill Price}_{\text{Sell}} = \text{Price}_{\text{Bid}} - \text{SlippagePenalty}$$
- Fixed spread deduction is amplified by **$1.50\times$** before computing net PnL in R-multiples.
- Breakeven triggers require $+0.85R$ clear movement *after* accounting for full stress costs.

---

## 5. Monte Carlo Resampling (500 Permutations)
To guarantee that the sequence of trades does not depend on lucky ordering, each champion candidate is subjected to **500 Monte Carlo shuffle iterations**:
- Probability of Ruin (Equity $< \$22,500$ or $-10\%$): **Must be 0.0%**.
- 95th Percentile Worst-Case Drawdown ($DD_{95\%}$): **Must be $\le 4.0\%$**.
