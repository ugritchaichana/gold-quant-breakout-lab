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
#define PORTFOLIO_RISK_PER_TRADE_PCT  0.25      // 0.25% per trade ($62.50 base)
#define PORTFOLIO_MAX_CONCURRENT_RISK 1.25      // Max concurrent exposure 1.25% (<= 5 open trades)
#define PORTFOLIO_DAILY_LOSS_LIMIT    2.00      // Hard Daily Loss Limit 2.0% (Well inside FTMO 5%)
#define PORTFOLIO_MAX_DD_LIMIT        4.50      // Hard Max DD Limit 4.5% (Inside FTMO 10%)
