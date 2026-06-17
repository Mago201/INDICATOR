//+------------------------------------------------------------------+
//|                                              GoldScalperEA.mq5    |
//|     Scalping Expert Advisor (trend pullback) + optional          |
//|     martingale.  Multi-symbol.                                   |
//|                                            Copyright 2026 Mago201|
//+------------------------------------------------------------------+
//  ВНИМАНИЕ / РИСК:
//  - Мартингейл МАТЕМАТИЧЕСКИ ведёт к сливу счёта на длинной дистанции:
//    одна затяжная серия убытков обнуляет депозит. Это не страховка, а
//    отложенный крупный риск. По умолчанию мартингейл ВЫКЛЮЧЕН.
//  - Встроены предохранители (equity-stop, кап шагов мартингейла). Не
//    отключайте их, не понимая последствий.
//  - Сначала ТОЛЬКО «Тестер стратегий» MT5 и демо-счёт. Реальные деньги —
//    только те, потерю которых вы готовы принять.
//  - Это инструмент, а не гарантия прибыли. «Грааль-советника» не существует.
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.00"
#property strict
#property description "Scalping EA (trend pullback) with optional, capped martingale and equity-stop. Test on demo first. No profit guarantee."

#include <Trade/Trade.mqh>
CTrade   trade;

//+==================================================================+
//| ВХОДНЫЕ ПАРАМЕТРЫ                                                 |
//+==================================================================+
input group "=== Стратегия (вход: тренд + откат) ==="
input int    InpEmaFast        = 8;        // Быстрая EMA
input int    InpEmaSlow        = 21;       // Средняя EMA
input int    InpEmaTrend       = 50;       // Трендовая EMA
input int    InpRsiPeriod      = 14;       // Период RSI
input double InpRsiBuyDip      = 42.0;     // BUY: RSI на откате опускался <=
input double InpRsiSellPop     = 58.0;     // SELL: RSI на откате поднимался >=
input double InpRsiMid         = 50.0;     // Середина RSI (триггер)
input double InpRsiOverbought  = 72.0;     // Не покупать выше
input double InpRsiOversold    = 28.0;     // Не продавать ниже
input int    InpAtrPeriod      = 14;       // Период ATR
input int    InpPullbackLookback = 6;      // Окно отката (баров)
input double InpPullbackATR    = 0.20;     // Допуск касания EMA (доли ATR)
input bool   InpRequirePullback = true;    // false = больше сделок (вход по тренду+импульсу)

input group "=== Сделка: SL / TP ==="
input double InpSLATR          = 1.20;     // SL = ATR * множитель
input double InpRR             = 1.00;     // TP = риск * RR (1.0 = выше частота попаданий)
input ulong  InpSlippagePts    = 20;       // Проскальзывание (пункты)
input long   InpMagic          = 20260530; // Magic number

input group "=== Money management ==="
input bool   InpRiskByPercent  = true;     // true = лот по риску %, false = фикс-лот
input double InpFixedLot       = 0.01;     // Фиксированный лот (если риск % выкл)
input double InpRiskPercent    = 1.0;      // Риск на сделку, % (база до мартингейла)
input bool   InpRiskUseEquity  = false;    // База риска: эквити (иначе баланс)

input group "=== Мартингейл (ОПАСНО — по умолчанию ВЫКЛ) ==="
input bool   InpUseMartingale  = false;    // Включить мартингейл (умножать лот после убытка)
input double InpMartMultiplier = 2.0;      // Множитель лота на каждый шаг
input int    InpMartMaxSteps   = 5;        // Макс. шагов; после максимума — СБРОС (ограничение риска)
input bool   InpMartResetOnWin = true;     // Сброс шага после прибыльной сделки

input group "=== Защита (НЕ отключайте без понимания) ==="
input double InpEquityStopPct  = 25.0;     // Стоп всей торговли при просадке от пика, % (0=выкл)
input bool   InpCloseAllOnStop = true;     // При срабатывании equity-stop закрыть все позиции
input int    InpMaxSpreadPts   = 0;        // Макс. спред в пунктах (0=выкл)
input bool   InpOneTradeAtTime = true;     // Не более одной позиции одновременно

input group "=== Сессия (часы сервера) ==="
input bool   InpUseSession     = true;     // Торговать только в окне
input int    InpSessStartHour  = 8;        // Старт окна
input int    InpSessEndHour    = 21;       // Конец окна

input group "=== Прочее ==="
input bool   InpAlertOnTrade   = false;    // Алерт при открытии сделки
input string InpComment        = "GSEA";   // Комментарий к ордеру

//+==================================================================+
//| ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ                                             |
//+==================================================================+
int      hEmaF=INVALID_HANDLE, hEmaS=INVALID_HANDLE, hEmaT=INVALID_HANDLE;
int      hRsi=INVALID_HANDLE,  hAtr=INVALID_HANDLE;

double   emaF[], emaS[], emaT[], rsiB[], atrB[];
double   hi[], lo[], op[], cl[];

datetime gLastBar   = 0;
int      gMartStep  = 0;       // текущий шаг мартингейла (0 = базовый лот)
double   gPeakEquity= 0.0;
bool     gHalted    = false;   // сработал equity-stop
bool     gHadPos    = false;   // была ли наша позиция на прошлом тике

//+==================================================================+
//| OnInit / OnDeinit                                                 |
//+==================================================================+
int OnInit()
{
   hEmaF = iMA(_Symbol,_Period, MathMax(1,InpEmaFast),  0, MODE_EMA, PRICE_CLOSE);
   hEmaS = iMA(_Symbol,_Period, MathMax(1,InpEmaSlow),  0, MODE_EMA, PRICE_CLOSE);
   hEmaT = iMA(_Symbol,_Period, MathMax(1,InpEmaTrend), 0, MODE_EMA, PRICE_CLOSE);
   hRsi  = iRSI(_Symbol,_Period, MathMax(2,InpRsiPeriod), PRICE_CLOSE);
   hAtr  = iATR(_Symbol,_Period, MathMax(2,InpAtrPeriod));
   if(hEmaF==INVALID_HANDLE||hEmaS==INVALID_HANDLE||hEmaT==INVALID_HANDLE||
      hRsi==INVALID_HANDLE ||hAtr==INVALID_HANDLE)
   {
      Print("GoldScalperEA: не удалось создать индикаторные хендлы");
      return(INIT_FAILED);
   }

   ArraySetAsSeries(emaF,true); ArraySetAsSeries(emaS,true); ArraySetAsSeries(emaT,true);
   ArraySetAsSeries(rsiB,true); ArraySetAsSeries(atrB,true);
   ArraySetAsSeries(hi,true);   ArraySetAsSeries(lo,true);
   ArraySetAsSeries(op,true);   ArraySetAsSeries(cl,true);

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);

   gLastBar    = 0;
   gMartStep   = 0;
   gPeakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   gHalted     = false;
   gHadPos     = HasPosition();

   if(InpUseMartingale)
      Print("GoldScalperEA: ВНИМАНИЕ — включён мартингейл. Высокий риск потери депозита. Тестируйте на демо.");

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

//+==================================================================+
//| OnTick                                                            |
//+==================================================================+
void OnTick()
{
   // 1) пик эквити + equity-stop (каждый тик)
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > gPeakEquity) gPeakEquity = eq;
   if(InpEquityStopPct > 0.0 && gPeakEquity > 0.0 &&
      (gPeakEquity - eq) / gPeakEquity * 100.0 >= InpEquityStopPct)
   {
      if(!gHalted)
      {
         if(InpCloseAllOnStop) CloseAllOurs();
         gHalted = true;
         Print("GoldScalperEA: EQUITY-STOP сработал (просадка >= ", InpEquityStopPct,
               "% от пика). Торговля остановлена. Снимите/переставьте советник для сброса.");
         if(InpAlertOnTrade) Alert(_Symbol," GoldScalperEA: equity-stop, торговля остановлена");
      }
   }

   // 2) детект закрытия нашей позиции -> обновить мартингейл (каждый тик)
   bool nowPos = HasPosition();
   if(gHadPos && !nowPos)
      UpdateMartingaleOnClose();
   gHadPos = nowPos;

   if(gHalted) return;

   // 3) действия только на НОВОМ баре
   datetime bt = iTime(_Symbol,_Period,0);
   if(bt == gLastBar) return;
   gLastBar = bt;

   // фильтры контекста
   if(InpMaxSpreadPts > 0 && (long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPts) return;
   if(InpUseSession && !InSession(TimeCurrent())) return;
   if(InpOneTradeAtTime && HasPosition()) return;

   double atrv = 0.0;
   int dir = GetSignal(atrv);
   if(dir != 0 && atrv > 0.0)
      OpenTrade(dir, atrv);
}

//+==================================================================+
//| Сигнал на последнем ЗАКРЫТОМ баре (shift=1). 1 buy, -1 sell, 0    |
//+==================================================================+
int GetSignal(double &atrOut)
{
   atrOut = 0.0;
   int need = InpPullbackLookback + 5;
   if(CopyBuffer(hEmaF,0,0,need,emaF) < need) return 0;
   if(CopyBuffer(hEmaS,0,0,need,emaS) < need) return 0;
   if(CopyBuffer(hEmaT,0,0,need,emaT) < need) return 0;
   if(CopyBuffer(hRsi ,0,0,need,rsiB) < need) return 0;
   if(CopyBuffer(hAtr ,0,0,need,atrB) < need) return 0;
   if(CopyHigh(_Symbol,_Period,0,need,hi) < need) return 0;
   if(CopyLow (_Symbol,_Period,0,need,lo) < need) return 0;
   if(CopyOpen(_Symbol,_Period,0,need,op) < need) return 0;
   if(CopyClose(_Symbol,_Period,0,need,cl) < need) return 0;

   double atr = atrB[1];
   if(atr <= 0.0) return 0;
   atrOut = atr;

   bool up   = (emaF[1] > emaS[1] && emaS[1] > emaT[1]);
   bool down = (emaF[1] < emaS[1] && emaS[1] < emaT[1]);

   double tol = InpPullbackATR * atr;
   bool tagBuy=false, tagSell=false;
   double rmin=101.0, rmax=-1.0;
   for(int k=1;k<=InpPullbackLookback;++k)
   {
      if(lo[k] <= emaF[k] + tol) tagBuy  = true;
      if(hi[k] >= emaF[k] - tol) tagSell = true;
      if(rsiB[k] < rmin) rmin = rsiB[k];
      if(rsiB[k] > rmax) rmax = rsiB[k];
   }

   bool buy = up &&
              (!InpRequirePullback || (tagBuy && rmin <= InpRsiBuyDip)) &&
              rsiB[1] >= InpRsiMid && rsiB[1] < InpRsiOverbought &&
              rsiB[1] > rsiB[2] && cl[1] > op[1] && cl[1] > emaF[1];

   bool sell = down &&
               (!InpRequirePullback || (tagSell && rmax >= InpRsiSellPop)) &&
               rsiB[1] <= InpRsiMid && rsiB[1] > InpRsiOversold &&
               rsiB[1] < rsiB[2] && cl[1] < op[1] && cl[1] < emaF[1];

   if(buy)  return 1;
   if(sell) return -1;
   return 0;
}

//+==================================================================+
//| Открытие сделки                                                   |
//+==================================================================+
void OpenTrade(int dir, double atr)
{
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pt  = _Point;
   double slDist = InpSLATR * atr;

   // уважать минимальную дистанцию стопов брокера
   int    minStop = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (minStop + 2) * pt;
   if(slDist < minDist) slDist = minDist;

   double lot = FinalLot(slDist);
   if(lot <= 0.0) return;

   bool ok=false;
   if(dir > 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = NormalizeDouble(ask - slDist, dg);
      double tp  = NormalizeDouble(ask + slDist * InpRR, dg);
      ok = trade.Buy(lot, _Symbol, ask, sl, tp, InpComment);
   }
   else
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = NormalizeDouble(bid + slDist, dg);
      double tp  = NormalizeDouble(bid - slDist * InpRR, dg);
      ok = trade.Sell(lot, _Symbol, bid, sl, tp, InpComment);
   }

   if(ok && InpAlertOnTrade)
      Alert(_Symbol, " GoldScalperEA: ", (dir>0?"BUY":"SELL"), " ", DoubleToString(lot,2), " lot");
   if(!ok)
      Print("GoldScalperEA: ордер не открыт, retcode=", trade.ResultRetcode(),
            " (", trade.ResultRetcodeDescription(), ")");
}

//+==================================================================+
//| Размер лота: база (риск % или фикс) * мартингейл                  |
//+==================================================================+
double BaseLot(double slDist)
{
   if(!InpRiskByPercent) return InpFixedLot;

   double base = InpRiskUseEquity ? AccountInfoDouble(ACCOUNT_EQUITY)
                                   : AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = base * InpRiskPercent / 100.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0 || slDist <= 0.0) return InpFixedLot;
   double lossPerLot = (slDist / tickSize) * tickVal;
   if(lossPerLot <= 0.0) return InpFixedLot;
   return riskMoney / lossPerLot;
}

double FinalLot(double slDist)
{
   double lot = BaseLot(slDist);
   if(InpUseMartingale && gMartStep > 0)
      lot *= MathPow(InpMartMultiplier, gMartStep);
   return NormalizeLot(lot);
}

double NormalizeLot(double lot)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0.0) lot = MathFloor(lot / step) * step;
   if(mn > 0.0 && lot < mn) lot = mn;
   if(mx > 0.0 && lot > mx) lot = mx;
   return lot;
}

//+==================================================================+
//| Мартингейл: обновление шага по результату закрытой сделки         |
//+==================================================================+
void UpdateMartingaleOnClose()
{
   if(!InpUseMartingale) { gMartStep = 0; return; }

   double profit = LastClosedProfit();
   if(profit < 0.0)
   {
      gMartStep++;
      // кап: после максимума — СБРОС (ограничиваем рост лота, а не наращиваем бесконечно)
      if(gMartStep > InpMartMaxSteps)
      {
         gMartStep = 0;
         Print("GoldScalperEA: достигнут лимит шагов мартингейла — сброс (защита от runaway-лота).");
      }
   }
   else
   {
      if(InpMartResetOnWin) gMartStep = 0;
   }
}

// Прибыль последнего закрытого нашего трейда (по последней OUT-сделке)
double LastClosedProfit()
{
   datetime from = TimeCurrent() - 7*24*3600;
   if(!HistorySelect(from, TimeCurrent() + 60)) return 0.0;

   double   profit = 0.0;
   datetime best   = 0;
   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; --i)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if((long)HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      if(t >= best)
      {
         best   = t;
         profit = HistoryDealGetDouble(d, DEAL_PROFIT)
                + HistoryDealGetDouble(d, DEAL_SWAP)
                + HistoryDealGetDouble(d, DEAL_COMMISSION);
      }
   }
   return profit;
}

//+==================================================================+
//| Позиции по нашему символу+magic                                   |
//+==================================================================+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
   }
   return false;
}

void CloseAllOurs()
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         trade.PositionClose(tk);
   }
}

//+==================================================================+
//| Фильтр сессии (часы сервера)                                      |
//+==================================================================+
bool InSession(datetime t)
{
   MqlDateTime mt; TimeToStruct(t, mt);
   int h = mt.hour;
   int s = InpSessStartHour, e = InpSessEndHour;
   if(s == e) return(true);
   if(s < e)  return(h >= s && h < e);
   return(h >= s || h < e);
}
//+------------------------------------------------------------------+
