//+------------------------------------------------------------------+
//|                                         QuantPositionManager.mqh |
//|                                  Copyright 2026, Quant EA Lab.   |
//|                         Unified 5-Model Multi-Asset Architecture |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quant EA Lab."
#property link      "https://github.com/quant-ea-lab"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "QuantDefines.mqh"

//+------------------------------------------------------------------+
//| Class CQuantPositionManager                                      |
//+------------------------------------------------------------------+
class CQuantPositionManager
{
private:
   CTrade            m_trade;
   CPositionInfo     m_position;

public:
   CQuantPositionManager() {}
   ~CQuantPositionManager() {}

   void Init(ulong magic_number, ulong deviation = 20)
   {
      m_trade.SetExpertMagicNumber(magic_number);
      m_trade.SetDeviationInPoints(deviation);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   }

   //--- Universal Instrument Risk Lot Normalizer
   double CalculateNormalizedLots(string symbol, double risk_usd, double sl_distance_price)
   {
      double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double step_lot   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double min_lot    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      if(tick_size <= 0.0 || tick_value <= 0.0 || sl_distance_price <= 0.0) 
         return min_lot;
      
      double sl_ticks = sl_distance_price / tick_size;
      double raw_lots = risk_usd / (sl_ticks * tick_value);
      
      double lots = MathFloor(raw_lots / step_lot) * step_lot;
      if(lots < min_lot) lots = min_lot;
      if(lots > max_lot) lots = max_lot;
      
      return lots;
   }

   //--- Margin Safety Pre-Check (Prevents Error 10019 No Money)
   bool HasSufficientMargin(string symbol, ENUM_ORDER_TYPE order_type, double volume, double price)
   {
      double margin_required = 0.0;
      if(!OrderCalcMargin(order_type, symbol, volume, price, margin_required))
         return false;
         
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      // Require at least 2.5x buffer of free margin
      return (free_margin >= (margin_required * 2.5));
   }

   //--- Execute Buy Breakout Order
   bool OpenBuy(string symbol, double volume, double sl_price, double tp_price, string comment = "")
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(!HasSufficientMargin(symbol, ORDER_TYPE_BUY, volume, ask))
      {
         PrintFormat("[QuantPositionManager] Insufficient free margin for %s BUY %.2f lots", symbol, volume);
         return false;
      }
      return m_trade.Buy(volume, symbol, ask, sl_price, tp_price, comment);
   }

   //--- Execute Sell Breakout Order
   bool OpenSell(string symbol, double volume, double sl_price, double tp_price, string comment = "")
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(!HasSufficientMargin(symbol, ORDER_TYPE_SELL, volume, bid))
      {
         PrintFormat("[QuantPositionManager] Insufficient free margin for %s SELL %.2f lots", symbol, volume);
         return false;
      }
      return m_trade.Sell(volume, symbol, bid, sl_price, tp_price, comment);
   }

   //--- Manage Position: Fast Breakeven Lock & Ratchet Trailing Stop
   void ManageTrailingAndBE(ulong magic_number, string symbol, double be_r_trigger, double r_distance, double atr_trail_dist)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != magic_number || m_position.Symbol() != symbol) continue;

         double open_price = m_position.PriceOpen();
         double current_sl = m_position.StopLoss();
         double current_tp = m_position.TakeProfit();
         ENUM_POSITION_TYPE pos_type = m_position.PositionType();
         ulong ticket = m_position.Ticket();

         if(pos_type == POSITION_TYPE_BUY)
         {
            double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            double profit_dist = bid - open_price;

            // 1. Fast Breakeven Lock at +0.85R
            if(r_distance > 0 && profit_dist >= (be_r_trigger * r_distance))
            {
               double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
               double be_level = open_price + (10.0 * point);
               if(current_sl < be_level)
               {
                  m_trade.PositionModify(ticket, be_level, current_tp);
                  current_sl = be_level;
               }
            }

            // 2. Ratchet ATR Trailing Stop
            if(atr_trail_dist > 0)
            {
               double new_sl = bid - atr_trail_dist;
               if(new_sl > current_sl && new_sl < bid)
               {
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
         else if(pos_type == POSITION_TYPE_SELL)
         {
            double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double profit_dist = open_price - ask;

            // 1. Fast Breakeven Lock at +0.85R
            if(r_distance > 0 && profit_dist >= (be_r_trigger * r_distance))
            {
               double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
               double be_level = open_price - (10.0 * point);
               if(current_sl > be_level || current_sl == 0.0)
               {
                  m_trade.PositionModify(ticket, be_level, current_tp);
                  current_sl = be_level;
               }
            }

            // 2. Ratchet ATR Trailing Stop
            if(atr_trail_dist > 0)
            {
               double new_sl = ask + atr_trail_dist;
               if((current_sl == 0.0 || new_sl < current_sl) && new_sl > ask)
               {
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
      }
   }
};
