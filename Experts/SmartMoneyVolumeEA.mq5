//+------------------------------------------------------------------+
//|                                          SmartMoneyVolumeEA.mq5   |
//|   Автоматический советник на базе индикатора SmartMoneyVolume     |
//|   Архитектура "мост": EA загружает индикатор через iCustom,       |
//|   читает его Entry-буферы (стрелки точки входа) и исполняет        |
//|   сделки с расчётом объёма по риску, безубытком и трейлингом.      |
//|                                            Copyright 2026 Mago201 |
//+------------------------------------------------------------------+
//  ВАЖНО про конфигурацию стратегии:
//  В MQL5 действует жёсткий лимит — не более 63 аргументов у iCustom.
//  У индикатора SmartMoneyVolume ~149 входов, причём entry-параметры
//  расположены в конце списка, поэтому передать их через iCustom нельзя
//  (префиксом до них не добраться). Поэтому советник запускает индикатор
//  с его ЗНАЧЕНИЯМИ ПО УМОЛЧАНИЮ. Чтобы изменить набор условий входа
//  (score-режим, Premium/Discount, RR, grab->CHoCH и т.д.), измените
//  значения по умолчанию во входах самого индикатора SmartMoneyVolume.mq5
//  и перекомпилируйте его — советник подхватит новые дефолты.
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.10"
#property strict
#property description "Автоторговля по entry-сигналам индикатора SmartMoneyVolume (iCustom-мост) + риск-менеджмент."

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
input group "=== Источник сигналов (индикатор) ==="
input string InpIndicatorName = "SmartMoneyVolume"; // Имя индикатора в MQL5/Indicators (с подпапкой при необходимости)
input int    InpSignalScanBars = 120;        // Сколько последних баров сканировать на свежий сигнал
input bool   InpDebugLog       = false;       // Печатать в журнал найденные сигналы/входы

input group "=== SL/TP (ATR) ==="
input int    InpAtrPeriod    = 14;           // Период ATR советника (для SL/TP)
input double InpSLATR        = 1.50;         // SL = ATR * множитель
input double InpRR           = 1.50;         // R:R (TP = риск * RR)

input group "=== Управление капиталом ==="
input ENUM_RISK_MODE InpRiskMode = RISK_PERCENT;  // Режим расчёта объёма
input double InpFixedLots     = 0.10;        // Фиксированный лот (для RISK_FIXED_LOT)
input double InpRiskPercent   = 1.0;         // Риск на сделку, % от баланса (для RISK_PERCENT)
input double InpMaxLots       = 0.0;         // Ограничение макс. лота (0=только биржевой максимум)

input group "=== Управление позицией ==="
input int    InpMaxPositions  = 1;           // Макс. одновременно открытых позиций (по этому EA)
input bool   InpCloseOnReverse= true;        // Закрывать противоположную позицию при встречном сигнале
input bool   InpUseBreakeven  = true;        // Перевод в безубыток
input double InpBeTriggerR    = 0.70;        // Безубыток при прибыли >= R
input double InpBeLockR       = 0.05;        // Зафиксировать прибыль (в R) при безубытке
input bool   InpUseTrailing   = false;       // Трейлинг-стоп
input double InpTrailStartR   = 1.00;        // Старт трейлинга при прибыли >= R
input double InpTrailDistR    = 1.00;        // Дистанция трейлинга (в R от текущей цены)

input group "=== Фильтры и лимиты ==="
input int    InpMaxTradesPerDay = 0;         // Макс. входов в день (0=без лимита)
input bool   InpUseSession      = false;     // Фильтр сессии на уровне EA
input int    InpSessStartHour   = 8;         // Старт окна (час сервера)
input int    InpSessEndHour     = 21;        // Конец окна (час сервера)
input int    InpMaxSpreadPts    = 0;         // Макс. спред в пунктах сейчас (0=выкл)
input int    InpCooldownBars    = 0;         // Пауза между входами EA, баров (0=выкл)

input group "=== Исполнение ==="
input long   InpMagic        = 26012027;     // Magic number
input int    InpSlippagePts  = 20;           // Допустимое проскальзывание (пункты)
input string InpComment      = "SmartMoneyVolume";  // Комментарий к ордерам
input bool   InpSymbolGuard  = false;        // Предупреждать, если символ не похож на золото

//+==================================================================+
//| ГЛОБАЛЬНЫЕ ОБЪЕКТЫ И ПЕРЕМЕННЫЕ                                    |
//+==================================================================+
CTrade   trade;

int      gIndHandle = INVALID_HANDLE;        // хендл индикатора (iCustom)
int      gAtrHandle = INVALID_HANDLE;        // ATR советника

#define  BUF_ENTRY_UP  2                      // индекс буфера EntryUp в индикаторе
#define  BUF_ENTRY_DN  3                      // индекс буфера EntryDn в индикаторе

datetime gLastBarTime    = 0;                 // детект нового бара (для дневного лимита)
datetime gLastSignalTime = 0;                 // время бара последнего обработанного сигнала
bool     gPrimed         = false;             // пропустить уже существующий сигнал при старте

datetime gLastEntryTime  = 0;                 // время последнего входа EA (для cooldown)
int      gTradeDayKey    = -1;
int      gTradesToday    = 0;

// Реестр исходного риска (R) по тикетам позиций
ulong    gPosTicket[];
double   gPosRisk[];

//+==================================================================+
//| OnInit                                                            |
//+==================================================================+
int OnInit()
{
   gAtrHandle = iATR(_Symbol, _Period, MathMax(2, InpAtrPeriod));
   if(gAtrHandle == INVALID_HANDLE)
   {
      Print("SmartMoneyVolumeEA: не удалось создать ATR-хендл");
      return(INIT_FAILED);
   }

   // Индикатор запускается с ДЕФОЛТНЫМИ параметрами (лимит iCustom = 63 аргумента,
   // у индикатора ~149 входов — передать их нельзя; меняйте дефолты в индикаторе).
   gIndHandle = iCustom(_Symbol, _Period, InpIndicatorName);
   if(gIndHandle == INVALID_HANDLE)
   {
      Print("SmartMoneyVolumeEA: не удалось создать хендл индикатора '", InpIndicatorName,
            "'. Проверьте, что ", InpIndicatorName, ".ex5 скомпилирован в MQL5/Indicators.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(MathMax(0, InpSlippagePts));
   trade.SetTypeFillingBySymbol(_Symbol);

   gLastBarTime    = 0;
   gLastSignalTime = 0;
   gPrimed         = false;
   gLastEntryTime  = 0;
   gTradeDayKey    = -1;
   gTradesToday    = 0;
   ArrayResize(gPosTicket, 0);
   ArrayResize(gPosRisk,   0);

   if(InpSymbolGuard && !LooksLikeGold())
      Print("SmartMoneyVolumeEA: символ '", _Symbol, "' не похож на золото.");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(gIndHandle != INVALID_HANDLE) IndicatorRelease(gIndHandle);
   if(gAtrHandle != INVALID_HANDLE) IndicatorRelease(gAtrHandle);
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
   // Сопровождение позиций — каждый тик
   ManageOpenPositions();

   // Детект нового бара — только для сброса дневного лимита
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar != gLastBarTime)
   {
      gLastBarTime = curBar;
      MqlDateTime mt; TimeToStruct(curBar, mt);
      int dayKey = mt.year*1000 + mt.day_of_year;
      if(dayKey != gTradeDayKey)
      {
         gTradeDayKey = dayKey;
         gTradesToday = 0;
      }
   }

   // Сигнал читаем КАЖДЫЙ тик (iCustom может пересчитаться позже OnTick);
   // защита от дублей — по времени бара сигнала (gLastSignalTime).
   CheckForSignal();
}

//+==================================================================+
//| Чтение свежего entry-сигнала индикатора и вход                    |
//+==================================================================+
void CheckForSignal()
{
   int depth = MathMax(10, InpSignalScanBars);
   int calc  = BarsCalculated(gIndHandle);
   if(calc < depth) depth = calc;
   if(depth < 5) return;
   if(Bars(_Symbol,_Period) < depth) return;

   double up[], dn[];
   ArraySetAsSeries(up, true);
   ArraySetAsSeries(dn, true);
   if(CopyBuffer(gIndHandle, BUF_ENTRY_UP, 0, depth, up) < depth) return;
   if(CopyBuffer(gIndHandle, BUF_ENTRY_DN, 0, depth, dn) < depth) return;

   // Найти САМЫЙ СВЕЖИЙ сигнал (наименьший shift >= 1)
   int  found = -1;
   bool buy   = false;
   for(int s=1; s<depth; ++s)
   {
      if(IsSignal(up[s])) { found=s; buy=true;  break; }
      if(IsSignal(dn[s])) { found=s; buy=false; break; }
   }
   if(found < 0) return;

   datetime sigBar = iTime(_Symbol, _Period, found);

   // Прайминг: при старте запоминаем уже существующий сигнал, но НЕ торгуем его
   if(!gPrimed)
   {
      gLastSignalTime = sigBar;
      gPrimed = true;
      if(InpDebugLog) PrintFormat("SMV EA: прайминг — пропускаю существующий %s @ %s",
                                  buy?"BUY":"SELL", TimeToString(sigBar));
      return;
   }

   if(sigBar == gLastSignalTime) return;   // этот сигнал уже обработан
   gLastSignalTime = sigBar;               // помечаем обработанным (без повторов в т.ч. при стопе внутри бара)

   if(InpDebugLog) PrintFormat("SMV EA: новый сигнал %s @ %s (shift %d)",
                               buy?"BUY":"SELL", TimeToString(sigBar), found);

   // Фильтры уровня EA
   if(InpUseSession && !InSession(iTime(_Symbol,_Period,0))) return;
   if(InpMaxSpreadPts > 0)
   {
      long spr = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spr > InpMaxSpreadPts) return;
   }
   if(InpCooldownBars > 0 && gLastEntryTime != 0)
   {
      if(BarsBetween(gLastEntryTime, iTime(_Symbol,_Period,0)) < InpCooldownBars) return;
   }
   if(InpMaxTradesPerDay > 0 && gTradesToday >= InpMaxTradesPerDay) return;

   if(InpCloseOnReverse) CloseOpposite(buy);

   if(CountPositions() >= InpMaxPositions) return;
   if(HasPosition(buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL)) return;

   OpenTrade(buy);
}

// Значение буфера — валидный сигнал (не EMPTY_VALUE и положительная цена)
bool IsSignal(double v)
{
   return(v > 0.0 && v < (DBL_MAX/2.0));
}

//+==================================================================+
//| Открытие сделки с расчётом SL/TP (ATR) и объёма по риску          |
//+==================================================================+
void OpenTrade(bool buy)
{
   double atr = CurrentATR();
   if(atr <= 0.0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask<=0.0 || bid<=0.0) return;

   double entry = buy ? ask : bid;
   double risk  = InpSLATR * atr;
   double sl, tp;
   if(buy)
   {
      sl = entry - risk;
      tp = entry + risk*InpRR;
   }
   else
   {
      sl = entry + risk;
      tp = entry - risk*InpRR;
   }
   if(risk <= 0.0) return;

   if(!RespectStops(buy, entry, sl, tp)) return;

   double lots = CalcLots(MathAbs(entry - sl));
   if(lots <= 0.0) return;

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   bool ok = buy ? trade.Buy(lots, _Symbol, 0.0, sl, tp, InpComment)
                 : trade.Sell(lots, _Symbol, 0.0, sl, tp, InpComment);
   if(!ok)
   {
      Print("SmartMoneyVolumeEA: ордер не отправлен. ret=", trade.ResultRetcode(),
            " (", trade.ResultRetcodeDescription(), ")");
      return;
   }

   gLastEntryTime = iTime(_Symbol,_Period,0);
   gTradesToday++;

   if(PositionSelect(_Symbol))
   {
      ulong  tk   = (ulong)PositionGetInteger(POSITION_TICKET);
      double po   = PositionGetDouble(POSITION_PRICE_OPEN);
      double psl  = PositionGetDouble(POSITION_SL);
      double rdist= (psl>0.0) ? MathAbs(po-psl) : MathAbs(entry-sl);
      RegisterRisk(tk, rdist);
   }
}

double CurrentATR()
{
   double buf[];
   if(CopyBuffer(gAtrHandle, 0, 1, 1, buf) != 1) return(0.0);
   return(buf[0]);
}

//+==================================================================+
//| Управление открытыми позициями: безубыток + трейлинг             |
//+==================================================================+
void ManageOpenPositions()
{
   if(!InpUseBreakeven && !InpUseTrailing) { CleanupRegistry(); return; }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   long   stopsLvl = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  = stopsLvl * _Point;

   for(int idx=PositionsTotal()-1; idx>=0; --idx)
   {
      ulong ticket = PositionGetTicket(idx);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)  continue;

      long   type  = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);

      double rdist = LookupRisk(ticket);
      if(rdist <= 0.0)
      {
         rdist = (curSL>0.0) ? MathAbs(open-curSL) : 0.0;
         if(rdist > 0.0) RegisterRisk(ticket, rdist);
      }
      if(rdist <= 0.0) continue;

      double newSL = curSL;

      if(type == POSITION_TYPE_BUY)
      {
         double rNow = (bid - open) / rdist;
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
         if(newSL > curSL && (bid - newSL) >= minDist)
            trade.PositionModify(ticket, NormalizeDouble(newSL,_Digits), curTP);
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double rNow = (open - ask) / rdist;
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
//| Вспомогательные                                                   |
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

int BarsBetween(datetime fromT, datetime toT)
{
   if(fromT==0) return(1000000);
   int a = iBarShift(_Symbol, _Period, fromT, false);
   int b = iBarShift(_Symbol, _Period, toT,   false);
   if(a < 0 || b < 0) return(1000000);
   return(a - b);
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
