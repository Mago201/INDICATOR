//+------------------------------------------------------------------+
//|                                            GoldScalperProEA.mq5   |
//|   Автоматический советник на базе индикатора GoldScalperPro       |
//|   Trend EMA stack + Daily VWAP bias + RSI pullback trigger        |
//|   + session / volatility / spread filters + ATR SL/TP             |
//|   + расчёт лота по % риска, безубыток, трейлинг, лимит сделок      |
//|                                            Copyright 2026 Mago201 |
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.00"
#property strict
#property description "Автоторговля по стратегии GoldScalperPro (XAUUSD). EMA stack + VWAP + RSI pullback."

#include <Trade/Trade.mqh>

//+==================================================================+
//| ПЕРЕЧИСЛЕНИЯ                                                       |
//+==================================================================+
enum ENUM_RISK_MODE
{
   RISK_FIXED_LOT  = 0,   // Фиксированный лот
   RISK_PERCENT    = 1    // % риска от баланса на сделку
};

//+==================================================================+
//| ВХОДНЫЕ ПАРАМЕТРЫ                                                 |
//+==================================================================+
input group "=== Тренд (EMA stack) ==="
input int    InpEmaFast      = 8;            // Быстрая EMA
input int    InpEmaSlow      = 21;           // Средняя EMA
input int    InpEmaTrend     = 50;           // Трендовая EMA (фильтр направления)

input group "=== VWAP (дневной, bias) ==="
input bool   InpUseVWAP      = true;         // Требовать совпадения с VWAP (цена выше=BUY, ниже=SELL)

input group "=== RSI (импульс на откате) ==="
input int    InpRsiPeriod    = 14;           // Период RSI
input double InpRsiBuyDip    = 42.0;         // Откат для BUY: RSI должен опуститься <= этого
input double InpRsiSellPop   = 58.0;         // Откат для SELL: RSI должен подняться >= этого
input double InpRsiMid       = 50.0;         // Середина (BUY выше, SELL ниже на триггере)
input double InpRsiOverbought= 72.0;         // Не покупать выше этого RSI
input double InpRsiOversold  = 28.0;         // Не продавать ниже этого RSI

input group "=== Откат к EMA ==="
input int    InpPullbackLookback = 6;        // Окно поиска отката (баров)
input double InpPullbackATR       = 0.20;    // Допуск касания быстрой EMA (доли ATR)

input group "=== Волатильность / ATR ==="
input int    InpAtrPeriod    = 14;           // Период ATR
input int    InpAtrMinPts    = 0;            // Мин. ATR в пунктах для торговли (0=выкл)
input int    InpAtrMaxPts    = 0;            // Макс. ATR в пунктах (0=выкл; фильтр экстремальной волы)

input group "=== Риск (SL/TP) ==="
input double InpSLATR        = 1.20;         // SL = ATR * множитель
input double InpRR           = 1.00;         // R:R (TP = риск * RR). 1.0 = высокий винрейт
input bool   InpSLUseSwing   = false;        // SL за локальный экстремум (иначе чистый ATR)
input int    InpSwingLookback= 10;           // Окно локального экстремума для SL

input group "=== Фильтр сессии (часы сервера) ==="
input bool   InpUseSession   = true;         // Торговать только в заданном окне
input int    InpSessStartHour= 8;            // Старт окна (London open ~ 8)
input int    InpSessEndHour  = 21;           // Конец окна (NY ~ 21)

input group "=== Прочие фильтры входа ==="
input int    InpMaxSpreadPts = 0;            // Макс. спред в пунктах сейчас (0=выкл)
input int    InpCooldownBars = 3;            // Пауза между входами одного направления (баров)
input double InpMinDistATR   = 0.0;          // Мин. дистанция от прошлого входа (ATR; 0=выкл)

input group "=== Управление капиталом ==="
input ENUM_RISK_MODE InpRiskMode = RISK_PERCENT;  // Режим расчёта объёма
input double InpFixedLots     = 0.10;        // Фиксированный лот (для RISK_FIXED_LOT)
input double InpRiskPercent   = 1.0;         // Риск на сделку, % от баланса (для RISK_PERCENT)
input double InpMaxLots       = 0.0;         // Ограничение макс. лота (0=без огранич., только биржевой максимум)

input group "=== Управление позицией ==="
input int    InpMaxPositions  = 1;           // Макс. одновременно открытых позиций (по этому EA)
input bool   InpCloseOnReverse= true;        // Закрывать противоположную позицию при новом сигнале
input bool   InpUseBreakeven  = true;        // Перевод в безубыток
input double InpBeTriggerR    = 0.70;        // Безубыток при прибыли >= R
input double InpBeLockR        = 0.05;       // Зафиксировать прибыль (в R) при безубытке
input bool   InpUseTrailing   = false;       // Трейлинг-стоп
input double InpTrailStartR    = 1.00;       // Старт трейлинга при прибыли >= R
input double InpTrailDistR      = 1.00;      // Дистанция трейлинга (в R от текущей цены)

input group "=== Лимиты ==="
input int    InpMaxTradesPerDay = 0;         // Макс. входов в день (0=без лимита)

input group "=== Исполнение / прочее ==="
input long   InpMagic        = 26012026;     // Magic number
input int    InpSlippagePts  = 20;           // Допустимое проскальзывание (пункты)
input string InpComment      = "GoldScalperPro";  // Комментарий к ордерам
input bool   InpSymbolGuard  = true;         // Предупреждать, если символ не похож на золото

//+==================================================================+
//| ГЛОБАЛЬНЫЕ ОБЪЕКТЫ И ПЕРЕМЕННЫЕ                                    |
//+==================================================================+
CTrade   trade;

int      hEmaF = INVALID_HANDLE;
int      hEmaS = INVALID_HANDLE;
int      hEmaT = INVALID_HANDLE;
int      hRsi  = INVALID_HANDLE;
int      hAtr  = INVALID_HANDLE;

datetime gLastBarTime  = 0;          // детект нового бара
datetime gLastBuyTime  = 0;          // время бара последнего BUY-входа
datetime gLastSellTime = 0;          // время бара последнего SELL-входа
double   gLastBuyPrice = 0.0;
double   gLastSellPrice= 0.0;

int      gTradeDayKey  = -1;         // ключ дня для лимита сделок
int      gTradesToday  = 0;

// Реестр исходного риска (R) по тикетам позиций — для безубытка/трейлинга
ulong    gPosTicket[];
double   gPosRisk[];

//+==================================================================+
//| OnInit                                                            |
//+==================================================================+
int OnInit()
{
   hEmaF = iMA(_Symbol, _Period, MathMax(1, InpEmaFast),  0, MODE_EMA, PRICE_CLOSE);
   hEmaS = iMA(_Symbol, _Period, MathMax(1, InpEmaSlow),  0, MODE_EMA, PRICE_CLOSE);
   hEmaT = iMA(_Symbol, _Period, MathMax(1, InpEmaTrend), 0, MODE_EMA, PRICE_CLOSE);
   hRsi  = iRSI(_Symbol, _Period, MathMax(2, InpRsiPeriod), PRICE_CLOSE);
   hAtr  = iATR(_Symbol, _Period, MathMax(2, InpAtrPeriod));

   if(hEmaF==INVALID_HANDLE || hEmaS==INVALID_HANDLE || hEmaT==INVALID_HANDLE ||
      hRsi==INVALID_HANDLE  || hAtr==INVALID_HANDLE)
   {
      Print("GoldScalperProEA: не удалось создать индикаторные хендлы");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(MathMax(0, InpSlippagePts));
   trade.SetTypeFillingBySymbol(_Symbol);

   gLastBarTime  = 0;
   gLastBuyTime  = 0;  gLastSellTime = 0;
   gLastBuyPrice = 0;  gLastSellPrice = 0;
   gTradeDayKey  = -1; gTradesToday = 0;
   ArrayResize(gPosTicket,0);
   ArrayResize(gPosRisk,0);

   if(InpSymbolGuard && !LooksLikeGold())
      Print("GoldScalperProEA: символ '", _Symbol,
            "' не похож на золото. Советник рассчитан под XAUUSD/GOLD.");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(hEmaF!=INVALID_HANDLE) IndicatorRelease(hEmaF);
   if(hEmaS!=INVALID_HANDLE) IndicatorRelease(hEmaS);
   if(hEmaT!=INVALID_HANDLE) IndicatorRelease(hEmaT);
   if(hRsi !=INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAtr !=INVALID_HANDLE) IndicatorRelease(hAtr);
}

bool LooksLikeGold()
{
   string s = _Symbol;
   StringToUpper(s);
   return(StringFind(s,"XAU")>=0 || StringFind(s,"GOLD")>=0 || StringFind(s,"GLD")>=0);
}

//+==================================================================+
//| OnTick                                                            |
//+==================================================================+
void OnTick()
{
   // Управление открытыми позициями выполняем на каждом тике (трейлинг/безубыток).
   ManageOpenPositions();

   // Сигналы и входы — только на закрытии бара (как в индикаторе).
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == gLastBarTime) return;
   gLastBarTime = curBar;

   // Сброс дневного лимита при смене дня сервера
   MqlDateTime mt; TimeToStruct(curBar, mt);
   int dayKey = mt.year*1000 + mt.day_of_year;
   if(dayKey != gTradeDayKey)
   {
      gTradeDayKey = dayKey;
      gTradesToday = 0;
   }

   CheckForEntry();
}

//+==================================================================+
//| Поиск входа на только что закрытом баре (shift = 1)               |
//+==================================================================+
void CheckForEntry()
{
   int need = MathMax(InpEmaTrend, MathMax(InpRsiPeriod, InpAtrPeriod))
              + InpPullbackLookback + InpSwingLookback + 10;
   if(Bars(_Symbol,_Period) < need + 3) return;

   // Готовность буферов
   if(BarsCalculated(hEmaF) < need || BarsCalculated(hEmaS) < need ||
      BarsCalculated(hEmaT) < need || BarsCalculated(hRsi)  < need ||
      BarsCalculated(hAtr)  < need)
      return;

   int depth = InpPullbackLookback + InpSwingLookback + 5;

   double emaF[], emaS[], emaT[], rsi[], atrArr[];
   ArraySetAsSeries(emaF,true); ArraySetAsSeries(emaS,true); ArraySetAsSeries(emaT,true);
   ArraySetAsSeries(rsi,true);  ArraySetAsSeries(atrArr,true);

   if(CopyBuffer(hEmaF,0,0,depth,emaF) < depth) return;
   if(CopyBuffer(hEmaS,0,0,depth,emaS) < depth) return;
   if(CopyBuffer(hEmaT,0,0,depth,emaT) < depth) return;
   if(CopyBuffer(hRsi ,0,0,depth,rsi)  < depth) return;
   if(CopyBuffer(hAtr ,0,0,depth,atrArr) < depth) return;

   double high[], low[], open[], close[];
   ArraySetAsSeries(high,true); ArraySetAsSeries(low,true);
   ArraySetAsSeries(open,true); ArraySetAsSeries(close,true);
   if(CopyHigh (_Symbol,_Period,0,depth,high)  < depth) return;
   if(CopyLow  (_Symbol,_Period,0,depth,low)   < depth) return;
   if(CopyOpen (_Symbol,_Period,0,depth,open)  < depth) return;
   if(CopyClose(_Symbol,_Period,0,depth,close) < depth) return;

   int i = 1;                       // последний закрытый бар = "i" в индикаторе
   double atr = atrArr[i];
   if(atr <= 0.0) return;

   double point = _Point;
   datetime barTime = iTime(_Symbol,_Period,i);

   // --- фильтры контекста ---
   if(InpUseSession && !InSession(barTime)) return;
   if(InpAtrMinPts>0 && atr < InpAtrMinPts*point) return;
   if(InpAtrMaxPts>0 && atr > InpAtrMaxPts*point) return;

   // --- тренд (EMA stack) ---
   bool up   = (emaF[i] > emaS[i] && emaS[i] > emaT[i]);
   bool down = (emaF[i] < emaS[i] && emaS[i] < emaT[i]);

   // --- bias по VWAP (дневной, до бара i) ---
   if(InpUseVWAP)
   {
      double vw = VWAPAtShift(i);
      if(vw > 0.0)
      {
         up   = up   && (close[i] > vw);
         down = down && (close[i] < vw);
      }
   }

   if(!up && !down) return;

   // --- откат к быстрой EMA + провал/всплеск RSI в окне ---
   double tol = InpPullbackATR * atr;
   bool taggedBuy=false, taggedSell=false;
   double rsiMin=101.0, rsiMax=-1.0;
   for(int k=i; k<=i+InpPullbackLookback; ++k)
   {
      if(low[k]  <= emaF[k] + tol) taggedBuy  = true;   // тег быстрой EMA снизу
      if(high[k] >= emaF[k] - tol) taggedSell = true;   // тег быстрой EMA сверху
      if(rsi[k] < rsiMin) rsiMin = rsi[k];
      if(rsi[k] > rsiMax) rsiMax = rsi[k];
   }

   // --- триггер импульса на баре i ---
   bool rsiTurnUp = (rsi[i] > rsi[i+1]);
   bool rsiTurnDn = (rsi[i] < rsi[i+1]);
   bool bullBar   = (close[i] > open[i]);
   bool bearBar   = (close[i] < open[i]);

   bool buy = up && taggedBuy &&
              rsiMin <= InpRsiBuyDip &&
              rsi[i] >= InpRsiMid && rsi[i] < InpRsiOverbought &&
              rsiTurnUp && bullBar && close[i] > emaF[i];

   bool sell = down && taggedSell &&
               rsiMax >= InpRsiSellPop &&
               rsi[i] <= InpRsiMid && rsi[i] > InpRsiOversold &&
               rsiTurnDn && bearBar && close[i] < emaF[i];

   if(!buy && !sell) return;

   // --- cooldown / min distance (по аналогии с индикатором) ---
   if(buy)
   {
      if(InpCooldownBars>0 && BarsSince(gLastBuyTime) < InpCooldownBars) return;
      if(InpMinDistATR>0.0 && gLastBuyPrice>0.0 &&
         MathAbs(close[i]-gLastBuyPrice) < InpMinDistATR*atr) return;
   }
   else
   {
      if(InpCooldownBars>0 && BarsSince(gLastSellTime) < InpCooldownBars) return;
      if(InpMinDistATR>0.0 && gLastSellPrice>0.0 &&
         MathAbs(close[i]-gLastSellPrice) < InpMinDistATR*atr) return;
   }

   // --- лимит сделок в день ---
   if(InpMaxTradesPerDay>0 && gTradesToday >= InpMaxTradesPerDay) return;

   // --- фильтр спреда (текущий) ---
   if(InpMaxSpreadPts>0)
   {
      long spr = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spr > InpMaxSpreadPts) return;
   }

   // --- закрытие противоположной позиции / контроль числа позиций ---
   if(InpCloseOnReverse)
      CloseOpposite(buy);

   int openCnt = CountPositions();
   if(openCnt >= InpMaxPositions) return;

   // Не открывать второй вход в ту же сторону, если такой уже есть
   if(HasPosition(buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL)) return;

   OpenTrade(buy, atr, high, low);
}

//+==================================================================+
//| Открытие сделки с расчётом SL/TP и объёма                         |
//+==================================================================+
void OpenTrade(bool buy, double atr, const double &high[], const double &low[])
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask<=0.0 || bid<=0.0) return;

   double entry = buy ? ask : bid;
   double risk  = InpSLATR * atr;
   double sl, tp;

   if(buy)
   {
      sl = entry - risk;
      if(InpSLUseSwing)
      {
         double lo = SwingLow(1, InpSwingLookback, low);
         if(lo>0.0) sl = MathMin(sl, lo - 0.10*atr);
      }
      risk = entry - sl;
      tp = entry + risk*InpRR;
   }
   else
   {
      sl = entry + risk;
      if(InpSLUseSwing)
      {
         double hi = SwingHigh(1, InpSwingLookback, high);
         if(hi>0.0) sl = MathMax(sl, hi + 0.10*atr);
      }
      risk = sl - entry;
      tp = entry - risk*InpRR;
   }
   if(risk <= 0.0) return;

   // соблюсти минимальную дистанцию стопов брокера
   if(!RespectStops(buy, entry, sl, tp)) return;

   double lots = CalcLots(MathAbs(entry - sl));
   if(lots <= 0.0) return;

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   bool ok = buy ? trade.Buy(lots, _Symbol, 0.0, sl, tp, InpComment)
                 : trade.Sell(lots, _Symbol, 0.0, sl, tp, InpComment);

   if(!ok)
   {
      Print("GoldScalperProEA: ордер не отправлен. ret=", trade.ResultRetcode(),
            " (", trade.ResultRetcodeDescription(), ")");
      return;
   }

   // зафиксировать состояние под cooldown/лимиты
   datetime barTime = iTime(_Symbol,_Period,1);
   if(buy){ gLastBuyTime=barTime;  gLastBuyPrice=entry; }
   else   { gLastSellTime=barTime; gLastSellPrice=entry; }
   gTradesToday++;

   // зарегистрировать исходный риск под безубыток/трейлинг
   if(PositionSelect(_Symbol))
   {
      ulong  tk   = (ulong)PositionGetInteger(POSITION_TICKET);
      double po   = PositionGetDouble(POSITION_PRICE_OPEN);
      double psl  = PositionGetDouble(POSITION_SL);
      double rdist= (psl>0.0) ? MathAbs(po-psl) : MathAbs(entry-sl);
      RegisterRisk(tk, rdist);
   }
}

//+==================================================================+
//| Управление открытыми позициями: безубыток + трейлинг             |
//+==================================================================+
void ManageOpenPositions()
{
   if(!InpUseBreakeven && !InpUseTrailing) { CleanupRegistry(); return; }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = _Point;
   long   stopsLvl = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  = stopsLvl * point;

   for(int idx=PositionsTotal()-1; idx>=0; --idx)
   {
      ulong ticket = PositionGetTicket(idx);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)  continue;

      long   type   = PositionGetInteger(POSITION_TYPE);
      double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL  = PositionGetDouble(POSITION_SL);
      double curTP  = PositionGetDouble(POSITION_TP);

      double rdist  = LookupRisk(ticket);
      if(rdist <= 0.0)
      {
         rdist = (curSL>0.0) ? MathAbs(open-curSL) : 0.0;
         if(rdist > 0.0) RegisterRisk(ticket, rdist);
      }
      if(rdist <= 0.0) continue;

      double newSL = curSL;

      if(type == POSITION_TYPE_BUY)
      {
         double profitDist = bid - open;          // прибыль в цене
         double rNow = profitDist / rdist;

         if(InpUseBreakeven && rNow >= InpBeTriggerR)
         {
            double be = open + InpBeLockR*rdist;
            if(be > newSL) newSL = be;
         }
         if(InpUseTrailing && rNow >= InpTrailStartR)
         {
            double tr = bid - InpTrailDistR*rdist;
            if(tr > newSL) newSL = tr;
         }
         // не ближе минимальной дистанции к цене и только в плюс
         if(newSL > curSL && (bid - newSL) >= minDist)
            trade.PositionModify(ticket, NormalizeDouble(newSL,_Digits), curTP);
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double profitDist = open - ask;
         double rNow = profitDist / rdist;

         if(InpUseBreakeven && rNow >= InpBeTriggerR)
         {
            double be = open - InpBeLockR*rdist;
            if(curSL<=0.0 || be < newSL) newSL = be;
         }
         if(InpUseTrailing && rNow >= InpTrailStartR)
         {
            double tr = ask + InpTrailDistR*rdist;
            if(curSL<=0.0 || tr < newSL) newSL = tr;
         }
         bool improved = (curSL<=0.0) ? (newSL>0.0) : (newSL < curSL);
         if(improved && (newSL - ask) >= minDist)
            trade.PositionModify(ticket, NormalizeDouble(newSL,_Digits), curTP);
      }
   }

   CleanupRegistry();
}

//+==================================================================+
//| Расчёт объёма позиции                                            |
//+==================================================================+
double CalcLots(double slDistancePrice)
{
   double minL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step<=0.0) step = 0.01;

   double lots;
   if(InpRiskMode == RISK_FIXED_LOT)
   {
      lots = InpFixedLots;
   }
   else
   {
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize<=0.0 || tickValue<=0.0 || slDistancePrice<=0.0)
         return(NormalizeLots(InpFixedLots, minL, maxL, step));

      double riskMoney  = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent/100.0;
      double riskPerLot = (slDistancePrice / tickSize) * tickValue;
      if(riskPerLot <= 0.0)
         return(NormalizeLots(InpFixedLots, minL, maxL, step));

      lots = riskMoney / riskPerLot;
   }

   if(InpMaxLots > 0.0 && lots > InpMaxLots) lots = InpMaxLots;
   return(NormalizeLots(lots, minL, maxL, step));
}

double NormalizeLots(double lots, double minL, double maxL, double step)
{
   lots = MathFloor(lots/step + 1e-9) * step;
   if(lots < minL) lots = minL;
   if(lots > maxL) lots = maxL;
   int digits = (int)MathMax(0, MathRound(-MathLog10(step)));
   return(NormalizeDouble(lots, digits));
}

//+==================================================================+
//| Минимальная дистанция стопов брокера                              |
//+==================================================================+
bool RespectStops(bool buy, double entry, double &sl, double &tp)
{
   long   stopsLvl = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  = stopsLvl * _Point;
   if(minDist <= 0.0) return(true);

   if(buy)
   {
      if((entry - sl) < minDist) sl = entry - minDist;
      if((tp - entry) < minDist) tp = entry + minDist;
   }
   else
   {
      if((sl - entry) < minDist) sl = entry + minDist;
      if((entry - tp) < minDist) tp = entry - minDist;
   }
   return(true);
}

//+==================================================================+
//| VWAP (дневной, anchored) на баре shift                            |
//+==================================================================+
double VWAPAtShift(int sh)
{
   datetime t = iTime(_Symbol,_Period,sh);
   if(t<=0) return(0.0);
   MqlDateTime mt; TimeToStruct(t, mt);
   int dayKey = mt.year*1000 + mt.day_of_year;

   // найти самый старый бар того же дня (предел поиска — сутки баров)
   int maxBack = (int)(86400 / MathMax(1, PeriodSeconds(_Period))) + 5;
   int oldest = sh;
   for(int s=sh; s<sh+maxBack; ++s)
   {
      datetime ts = iTime(_Symbol,_Period,s);
      if(ts<=0) break;
      MqlDateTime ms; TimeToStruct(ts, ms);
      int dk = ms.year*1000 + ms.day_of_year;
      if(dk != dayKey) break;
      oldest = s;
   }

   double cumPV=0.0, cumV=0.0;
   for(int s=oldest; s>=sh; --s)
   {
      double hi = iHigh (_Symbol,_Period,s);
      double lo = iLow  (_Symbol,_Period,s);
      double cl = iClose(_Symbol,_Period,s);
      double v  = (double)iTickVolume(_Symbol,_Period,s);
      double tp = (hi+lo+cl)/3.0;
      cumPV += tp*v;
      cumV  += v;
   }
   if(cumV<=0.0) return(iClose(_Symbol,_Period,sh));
   return(cumPV/cumV);
}

//+==================================================================+
//| Вспомогательные                                                   |
//+==================================================================+
bool InSession(datetime t)
{
   MqlDateTime mt; TimeToStruct(t, mt);
   int h = mt.hour;
   int s = InpSessStartHour, e = InpSessEndHour;
   if(s == e) return(true);                 // окно 24ч
   if(s < e)  return(h >= s && h < e);       // обычное окно
   return(h >= s || h < e);                  // окно через полночь
}

int BarsSince(datetime sigTime)
{
   if(sigTime==0) return(1000000);
   int sh = iBarShift(_Symbol, _Period, sigTime, false);
   if(sh < 0) return(1000000);
   return(sh - 1);                           // сигнальный бар сейчас на shift=1
}

double SwingLow(int startShift, int lookback, const double &low[])
{
   double m = low[startShift];
   int end = startShift + lookback;
   if(end >= ArraySize(low)) end = ArraySize(low)-1;
   for(int k=startShift; k<=end; ++k) if(low[k] < m) m = low[k];
   return(m);
}
double SwingHigh(int startShift, int lookback, const double &high[])
{
   double m = high[startShift];
   int end = startShift + lookback;
   if(end >= ArraySize(high)) end = ArraySize(high)-1;
   for(int k=startShift; k<=end; ++k) if(high[k] > m) m = high[k];
   return(m);
}

int CountPositions()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) n++;
   }
   return(n);
}

bool HasPosition(ENUM_POSITION_TYPE type)
{
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol  &&
         PositionGetInteger(POSITION_TYPE)==type) return(true);
   }
   return(false);
}

void CloseOpposite(bool buySignal)
{
   ENUM_POSITION_TYPE opp = buySignal ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      if(PositionGetInteger(POSITION_TYPE)==opp)
         trade.PositionClose(tk);
   }
}

//+==================================================================+
//| Реестр исходного риска по тикетам                                 |
//+==================================================================+
void RegisterRisk(ulong ticket, double riskDist)
{
   for(int i=0;i<ArraySize(gPosTicket);++i)
      if(gPosTicket[i]==ticket){ gPosRisk[i]=riskDist; return; }
   int n=ArraySize(gPosTicket);
   ArrayResize(gPosTicket,n+1); ArrayResize(gPosRisk,n+1);
   gPosTicket[n]=ticket; gPosRisk[n]=riskDist;
}

double LookupRisk(ulong ticket)
{
   for(int i=0;i<ArraySize(gPosTicket);++i)
      if(gPosTicket[i]==ticket) return(gPosRisk[i]);
   return(-1.0);
}

void CleanupRegistry()
{
   for(int i=ArraySize(gPosTicket)-1;i>=0;--i)
   {
      if(!PositionSelectByTicket(gPosTicket[i]))
      {
         int last=ArraySize(gPosTicket)-1;
         gPosTicket[i]=gPosTicket[last];
         gPosRisk[i]  =gPosRisk[last];
         ArrayResize(gPosTicket,last);
         ArrayResize(gPosRisk,last);
      }
   }
}
//+------------------------------------------------------------------+
