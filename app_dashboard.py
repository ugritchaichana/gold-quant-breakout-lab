import streamlit as st
import sqlite3
import pandas as pd
import plotly.express as px
import os

# Set page layout
st.set_page_config(
    page_title="Institutional Gold Quant Vault | Dashboard",
    page_icon="🏆",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom Styling
st.markdown("""
<style>
    .main { background-color: #0e1117; }
    .stMetric { background-color: #1e222d; padding: 15px; border-radius: 10px; border-left: 4px solid #f59e0b; }
    div[data-testid="stExpander"] { background-color: #161a23; border-radius: 8px; }
</style>
""", unsafe_allow_html=True)

DB_PATH = r"C:\Users\Booth\quant_ea_lab\quant_vault.db"
MT5_PRESET_DIR = r"C:\Users\Booth\quant_ea_lab"

@st.cache_resource
def get_connection():
    return sqlite3.connect(DB_PATH, check_same_thread=False)

conn = get_connection()

# Header
st.title("🏆 Institutional Gold Quant Vault | Dashboard")
st.caption("Interactive Research Vault & Strategy Screener • 5,041,432 Multi-Timeframe Permutations")

# Top KPI Metrics Cards
cur = conn.cursor()
cur.execute("SELECT count(*), max(full_cagr), min(full_dd), max(full_pf), max(oos_cagr) FROM results;")
total_count, max_cagr, min_dd, max_pf, max_oos = cur.fetchone()

col1, col2, col3, col4, col5 = st.columns(5)
with col1:
    st.metric("Total Strategies Evaluated", f"{total_count:,}")
with col2:
    st.metric("Top Full 1-Yr CAGR", f"+{max_cagr*100:.1f}%")
with col3:
    st.metric("Best OOS Forward CAGR", f"+{max_oos*100:.1f}%")
with col4:
    st.metric("Lowest Max Drawdown", f"{min_dd*100:.1f}%")
with col5:
    st.metric("Peak Profit Factor", f"{max_pf:.2f}")

st.markdown("---")

# Sidebar Filters
st.sidebar.header("🔍 Strategy Filter & Screener")

timeframe_options = ["All", "M15", "M30", "H1"]
selected_tf = st.sidebar.selectbox("Timeframe Filter", timeframe_options, index=0)

min_cagr = st.sidebar.slider("Min Full CAGR (%)", min_value=0, max_value=350, value=150, step=10)
max_dd = st.sidebar.slider("Max Permitted Drawdown (%)", min_value=5, max_value=35, value=22, step=1)
min_pf = st.sidebar.slider("Min Profit Factor", min_value=1.0, max_value=2.5, value=1.5, step=0.05)
min_oos = st.sidebar.slider("Min OOS Forward CAGR (%)", min_value=0, max_value=250, value=50, step=10)

sort_by = st.sidebar.selectbox(
    "Sort Strategies By",
    ["Full CAGR (High to Low)", "OOS Forward CAGR (High to Low)", "Profit Factor (High to Low)", "Lowest Drawdown"],
    index=0
)

limit_results = st.sidebar.slider("Max Results to Display", min_value=25, max_value=500, value=100, step=25)

# Build SQL Query
conditions = []
params = []

if selected_tf != "All":
    conditions.append("timeframe = ?")
    params.append(selected_tf)

conditions.append("full_cagr >= ?")
params.append(min_cagr / 100.0)

conditions.append("abs(full_dd) <= ?")
params.append(max_dd / 100.0)

conditions.append("full_pf >= ?")
params.append(min_pf)

conditions.append("oos_cagr >= ?")
params.append(min_oos / 100.0)

where_clause = " WHERE " + " AND ".join(conditions) if conditions else ""

sort_sql = {
    "Full CAGR (High to Low)": "ORDER BY full_cagr DESC",
    "OOS Forward CAGR (High to Low)": "ORDER BY oos_cagr DESC",
    "Profit Factor (High to Low)": "ORDER BY full_pf DESC",
    "Lowest Drawdown": "ORDER BY abs(full_dd) ASC"
}[sort_by]

sql_query = f"""
SELECT 
    timeframe as 'TF',
    donchian as 'Donchian',
    atr_trail as 'Trail ATR',
    atr_stop as 'Stop ATR',
    risk as 'Risk',
    min_adx as 'Min ADX',
    max_hold as 'Max Hold',
    full_cagr as 'Full CAGR',
    oos_cagr as 'OOS CAGR',
    full_dd as 'Max DD',
    full_pf as 'Profit Factor',
    trades as 'Trades'
FROM results
{where_clause}
{sort_sql}
LIMIT {limit_results};
"""

df_results = pd.read_sql_query(sql_query, conn, params=params)

st.subheader(f"📊 Filtered Strategy Candidates ({len(df_results)} matches)")

if df_results.empty:
    st.warning("⚠️ No strategies match your strict filter criteria. Try relaxing the CAGR or Max Drawdown slider.")
else:
    # Format Display Copy
    df_display = df_results.copy()
    df_display['Full CAGR'] = df_display['Full CAGR'].apply(lambda x: f"+{x*100:.1f}%")
    df_display['OOS CAGR'] = df_display['OOS CAGR'].apply(lambda x: f"+{x*100:.1f}%")
    df_display['Max DD'] = df_display['Max DD'].apply(lambda x: f"{x*100:.1f}%")
    df_display['Risk'] = df_display['Risk'].apply(lambda x: f"{x*100:.1f}%")
    df_display['Profit Factor'] = df_display['Profit Factor'].apply(lambda x: f"{x:.2f}")

    # Tabs: Scatter Chart & Table
    tab_chart, tab_table, tab_export = st.tabs(["📈 Pareto Frontier Chart (Risk vs Return)", "📋 Strategy Ranking Table", "💾 Export MT5 Preset (.set)"])

    with tab_chart:
        fig = px.scatter(
            df_results,
            x=df_results['Max DD'].abs() * 100,
            y=df_results['Full CAGR'] * 100,
            color='TF',
            size='Profit Factor',
            hover_data=['Donchian', 'Trail ATR', 'Stop ATR', 'Risk', 'Trades'],
            labels={'x': 'Max Drawdown (%)', 'y': 'Full 1-Year CAGR (%)'},
            title="Pareto Frontier: Full CAGR vs Maximum Drawdown (Bubble Size = Profit Factor)",
            template="plotly_dark",
            color_discrete_map={"M15": "#10b981", "M30": "#3b82f6", "H1": "#f59e0b"}
        )
        fig.update_layout(height=520, margin=dict(l=20, r=20, t=40, b=20))
        st.plotly_chart(fig, use_container_width=True)

    with tab_table:
        st.dataframe(df_display, use_container_width=True, height=450)

    with tab_export:
        st.markdown("### 💾 Generate & Download MetaTrader 5 Preset (`.set`)")
        st.write("Select a strategy from the table above to generate an exact `.set` configuration file:")
        
        selected_index = st.selectbox(
            "Select Candidate to Export",
            options=range(len(df_results)),
            format_func=lambda i: f"Rank #{i+1} | {df_results.iloc[i]['TF']} | Donchian: {df_results.iloc[i]['Donchian']} | Trail: {df_results.iloc[i]['Trail ATR']}x | Stop: {df_results.iloc[i]['Stop ATR']}x | CAGR: +{df_results.iloc[i]['Full CAGR']*100:.1f}% | DD: {df_results.iloc[i]['Max DD']*100:.1f}% | PF: {df_results.iloc[i]['Profit Factor']:.2f}"
        )
        
        cand = df_results.iloc[selected_index]
        
        tf_enum = "PERIOD_M15" if cand['TF'] == 'M15' else ("PERIOD_M30" if cand['TF'] == 'M30' else "PERIOD_H1")
        
        set_content = f"""; Expert Advisor Settings generated by Quant Vault
; Timeframe: {cand['TF']} | Full CAGR: +{cand['Full CAGR']*100:.1f}% | Max DD: {cand['Max DD']*100:.1f}% | PF: {cand['Profit Factor']:.2f}
InpMacroTimeframe=16385
InpEntryTimeframe={30 if cand['TF']=='M30' else (15 if cand['TF']=='M15' else 16385)}
InpDonchianWindow={int(cand['Donchian'])}
InpATRTrailMult={float(cand['Trail ATR']):.2f}
InpATRStopMult={float(cand['Stop ATR']):.2f}
InpMinADX={float(cand['Min ADX']):.1f}
InpEMA200Period=200
InpEMA800Period=800
InpMaxBarsHold={int(cand['Max Hold'])}
InpRiskPercent={float(cand['Risk'])*100:.1f}
InpMaxLeverage=5.00
InpMaxSpreadUSD=0.60
InpTier1DrawdownPct=5.00
InpTier2DrawdownPct=10.00
InpTier3DrawdownPct=15.00
InpMagicNumber=888999
InpTradeComment=Master_XAU_{cand['TF']}
"""
        st.code(set_content, language="ini")
        
        set_filename = f"Master_Gold_{cand['TF']}_Champion_CAGR{int(cand['Full CAGR']*100)}.set"
        st.download_button(
            label=f"📥 Download {set_filename}",
            data=set_content,
            file_name=set_filename,
            mime="text/plain"
        )
        
        if st.button("💾 Save directly to quant_ea_lab folder"):
            save_path = os.path.join(MT5_PRESET_DIR, set_filename)
            with open(save_path, "w", encoding="utf-8") as f:
                f.write(set_content)
            st.success(f"Saved successfully to: {save_path}")
