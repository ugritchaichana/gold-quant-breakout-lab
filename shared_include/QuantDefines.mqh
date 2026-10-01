//+------------------------------------------------------------------+
//|                                                 QuantDefines.mqh |
//|                                  Copyright 2026, Quant EA Lab.   |
//|                         Unified 5-Model Multi-Asset Architecture |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quant EA Lab."
#property link      "https://github.com/quant-ea-lab"
#property strict

//--- Model & Asset Class Identifiers
enum ENUM_ASSET_CLASS
{
   ASSET_GOLD   = 1,   // XAUUSD (Precious Metal)
   ASSET_INDEX  = 2,   // NAS100 (US Tech Index)
   ASSET_FOREX  = 3,   // GBPJPY (High-Beta FX)
   ASSET_OIL    = 4,   // USOIL  (Energy Commodity)
   ASSET_CRYPTO = 5    // BTCUSD (Digital Asset)
};

//--- Market Regime State
enum ENUM_REGIME_TYPE
{
   REGIME_EXPANSION_BULL = 1,   // Strong Bullish Trend
   REGIME_EXPANSION_BEAR = -1,  // Strong Bearish Trend
   REGIME_SIDEWAYS_CHOP  = 0    // Low Efficiency / Congestion
};

//--- Trade Signal Direction
enum ENUM_SIGNAL_DIR
{
   SIGNAL_BUY  = 1,
   SIGNAL_NONE = 0,
   SIGNAL_SELL = -1
};

//--- Circuit Breaker Level
enum ENUM_CIRCUIT_STATUS
{
   CIRCUIT_NORMAL    = 0,
   CIRCUIT_WARNING   = 1,  // Risk scaled down by 50%
   CIRCUIT_HARD_LOCK = 2   // 100% Cash / Trading Halted
};

//--- Account Portfolio Thresholds
#define PORTFOLIO_DEFAULT_BALANCE     25000.0   // Shared $25,000 Risk Pool
#define PORTFOLIO_RISK_PER_TRADE_PCT  1.00      // 1.00% per trade ($250.00 base on $25k)
#define PORTFOLIO_MAX_CONCURRENT_RISK 2.50      // Max concurrent exposure <= 2.50%
#define PORTFOLIO_DAILY_LOSS_LIMIT    3.80      // Hard Daily Loss Limit 3.8% (Strictly <= 4.0% Daily Loss for FTMO)
#define PORTFOLIO_MAX_DD_LIMIT        4.50      // Hard Max DD Limit 4.5% (Inside FTMO 10%)

//--- Broker Server Rollover Spread Expansion Window (Blackout from 23:50 to 00:20)
#define ROLLOVER_BLACKOUT_START_HOUR  23
#define ROLLOVER_BLACKOUT_START_MIN   50
#define ROLLOVER_BLACKOUT_END_HOUR    0
#define ROLLOVER_BLACKOUT_END_MIN     20
