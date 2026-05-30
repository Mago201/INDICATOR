//+------------------------------------------------------------------+
//|                                              GoldScalperPro.mq5   |
//|       Intraday / Scalping signals for Gold (XAUUSD)              |
//|       Trend EMA stack + Daily VWAP bias + RSI pullback trigger   |
//|       + session / volatility / spread filters + ATR SL/TP        |
//|       + history win-rate stats dashboard                         |
//|                                            Copyright 2026 Mago201|
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

//--- Plot 1: BUY arrow
#property indicator_label1  "BUY"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  3
//--- Plot 2: SELL arrow
#property indicator_label2  "SELL"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3
//--- Plot 3: EMA fast
#property indicator_label3  "EMA fast"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  1
//--- Plot 4: EMA slow
#property indicator_label4  "EMA slow"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_width4  1
//--- Plot 5: EMA trend
#property indicator_label5  "EMA trend"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGray
#property indicator_width5  2
//--- Plot 6: VWAP
#property indicator_label6  "VWAP"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_width6  1

//+==================================================================+
//| ВХОДНЫЕ ПАРАМЕТРЫ                                                 |
//+==================================================================+
input group "=== Тренд (EMA stack) ==="
input int    InpEmaFast      = 8;            // Быстрая EMA
input int    InpEmaSlow      = 21;           // Средняя EMA
input int    InpEmaTrend     = 50;           // Трендовая EMA (фильтр направления)
input bool   InpShowEMA      = true;         // Показывать линии EMA

input group "=== VWAP (дневной, bias) ==="
input bool   InpUseVWAP      = true;         // Требовать совпадения с VWAP (цена выше=BUY, ниже=SELL)
input bool   InpShowVWAP     = true;         // Рисовать линию VWAP

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

input group "=== Прочие фильтры ==="
input int    InpMaxSpreadPts = 0;            // Макс. спред в пунктах (0=выкл; для live)
input int    InpCooldownBars = 3;            // Пауза между сигналами одного направления (баров)
input double InpMinDistATR   = 0.0;          // Мин. дистанция от прошлого сигнала (ATR; 0=выкл)

input group "=== Отрисовка ==="
input bool   InpShowArrows   = true;         // Стрелки сигналов
input double InpArrowOffATR  = 0.6;          // Отступ стрелки от свечи (доли ATR)
input int    InpBuyArrow     = 233;          // Wingdings код стрелки BUY
input int    InpSellArrow    = 234;          // Wingdings код стрелки SELL
input bool   InpShowLevels   = true;         // Рисовать SL/TP последних сигналов
input int    InpLevelsCount  = 4;            // Сколько последних сигналов с SL/TP
input int    InpLevelsBars   = 18;           // Длина линий SL/TP вправо (баров)
input color  InpSLColor      = clrCrimson;   // Цвет SL
input color  InpTPColor      = clrSeaGreen;  // Цвет TP

input group "=== Алерты ==="
input bool   InpAlert        = true;         // Popup/звуковой алерт на свежем сигнале
input bool   InpAlertPush    = false;        // Push-уведомление (SendNotification)

input group "=== Dashboard / статистика ==="
input bool             InpShowDash   = true;          // Панель со статистикой
input ENUM_BASE_CORNER InpDashCorner = CORNER_LEFT_UPPER;
input int              InpDashX      = 12;             // Отступ X
input int              InpDashY      = 16;             // Отступ Y
input int              InpDashFont   = 9;              // Размер шрифта
input color            InpDashText   = clrWhite;       // Цвет текста
input color            InpDashAccent = clrGold;        // Цвет акцента
input color            InpDashBg     = C'25,28,38';    // Фон панели
input int              InpStatMaxFwd = 300;            // Макс. баров вперёд для оценки TP/SL

input group "=== Производительность / прочее ==="
input int    InpMaxBars      = 2500;         // Глубина анализа (баров; 0 = вся история)
input bool   InpSymbolGuard  = true;         // Предупреждать, если символ не похож на золото
input string InpPrefix       = "GSP_";       // Префикс объектов

//+==================================================================+
//| БУФЕРЫ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ                                    |
//+==================================================================+
double BufBuy[];
double BufSell[];
double BufEmaF[];
double BufEmaS[];
double BufEmaT[];
double BufVWAP[];

double gRsi[];
double gAtr[];

int    hEmaF = INVALID_HANDLE;
int    hEmaS = INVALID_HANDLE;
int    hEmaT = INVALID_HANDLE;
int    hRsi  = INVALID_HANDLE;
int    hAtr  = INVALID_HANDLE;

datetime gLastBar      = 0;   // время последнего обработанного бара (детект нового бара)
datetime gLastAlertBar = 0;   // против повторного алерта на том же баре
int      gLastBuyBar   = -100000;
int      gLastSellBar  = -100000;
double   gLastBuyPrice = 0.0;
double   gLastSellPrice= 0.0;

// Статистика по истории
int      gSigTotal=0, gWins=0, gLosses=0, gOpen=0;
double   gSumR=0.0;           // суммарный результат в R
double   gBuyCnt=0, gSellCnt=0;

// Для отрисовки SL/TP последних сигналов
datetime gSigTime[];
double   gSigEntry[];
double   gSigSL[];
double   gSigTP[];
int      gSigDir[];           // 1 buy, -1 sell

//+==================================================================+
//| OnInit                                                            |
//+==================================================================+
int OnInit()
{
   SetIndexBuffer(0, BufBuy,  INDICATOR_DATA);
   SetIndexBuffer(1, BufSell, INDICATOR_DATA);
   SetIndexBuffer(2, BufEmaF, INDICATOR_DATA);
   SetIndexBuffer(3, BufEmaS, INDICATOR_DATA);
   SetIndexBuffer(4, BufEmaT, INDICATOR_DATA);
   SetIndexBuffer(5, BufVWAP, INDICATOR_DATA);

   ArraySetAsSeries(BufBuy,  false);
   ArraySetAsSeries(BufSell, false);
   ArraySetAsSeries(BufEmaF, false);
   ArraySetAsSeries(BufEmaS, false);
   ArraySetAsSeries(BufEmaT, false);
   ArraySetAsSeries(BufVWAP, false);
   ArraySetAsSeries(gRsi,    false);
   ArraySetAsSeries(gAtr,    false);

   PlotIndexSetInteger(0, PLOT_ARROW, InpBuyArrow);
   PlotIndexSetInteger(1, PLOT_ARROW, InpSellArrow);
   PlotIndexSetDouble (0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (5, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Скрыть линии EMA/VWAP, если выключены
   if(!InpShowEMA)
   {
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, clrNONE);
      PlotIndexSetInteger(3, PLOT_LINE_COLOR, 0, clrNONE);
      PlotIndexSetInteger(4, PLOT_LINE_COLOR, 0, clrNONE);
   }
   if(!InpShowVWAP)
      PlotIndexSetInteger(5, PLOT_LINE_COLOR, 0, clrNONE);

   IndicatorSetString(INDICATOR_SHORTNAME, "GoldScalperPro");

   hEmaF = iMA(_Symbol, _Period, MathMax(1, InpEmaFast),  0, MODE_EMA, PRICE_CLOSE);
   hEmaS = iMA(_Symbol, _Period, MathMax(1, InpEmaSlow),  0, MODE_EMA, PRICE_CLOSE);
   hEmaT = iMA(_Symbol, _Period, MathMax(1, InpEmaTrend), 0, MODE_EMA, PRICE_CLOSE);
   hRsi  = iRSI(_Symbol, _Period, MathMax(2, InpRsiPeriod), PRICE_CLOSE);
   hAtr  = iATR(_Symbol, _Period, MathMax(2, InpAtrPeriod));

   if(hEmaF==INVALID_HANDLE || hEmaS==INVALID_HANDLE || hEmaT==INVALID_HANDLE ||
      hRsi==INVALID_HANDLE  || hAtr==INVALID_HANDLE)
   {
      Print("GoldScalperPro: не удалось создать индикаторные хендлы");
      return(INIT_FAILED);
   }

   gLastBar = 0;
   gLastAlertBar = 0;
   gLastBuyBar = -100000;  gLastSellBar = -100000;
   gLastBuyPrice = 0.0;    gLastSellPrice = 0.0;
   ArrayResize(gSigTime,0); ArrayResize(gSigEntry,0);
   ArrayResize(gSigSL,0);   ArrayResize(gSigTP,0);   ArrayResize(gSigDir,0);

   ClearAll();
   if(InpSymbolGuard && !LooksLikeGold())
      Comment("GoldScalperPro: символ '", _Symbol,
              "' не похож на золото. Индикатор рассчитан под XAUUSD/GOLD.");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(hEmaF!=INVALID_HANDLE) IndicatorRelease(hEmaF);
   if(hEmaS!=INVALID_HANDLE) IndicatorRelease(hEmaS);
   if(hEmaT!=INVALID_HANDLE) IndicatorRelease(hEmaT);
   if(hRsi !=INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAtr !=INVALID_HANDLE) IndicatorRelease(hAtr);
   ClearAll();
   Comment("");
}

bool LooksLikeGold()
{
   string s = _Symbol;
   StringToUpper(s);
   return(StringFind(s,"XAU")>=0 || StringFind(s,"GOLD")>=0 || StringFind(s,"GLD")>=0);
}

void ClearAll()
{
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;--i)
   {
      string nm = ObjectName(0,i,-1,-1);
      if(StringFind(nm, InpPrefix)==0) ObjectDelete(0,nm);
   }
}

//+==================================================================+
//| OnCalculate                                                       |
//+==================================================================+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int warmup = MathMax(InpEmaTrend, MathMax(InpRsiPeriod, InpAtrPeriod)) + InpPullbackLookback + 5;
   if(rates_total < warmup + 5) return(0);

   // Готовность буферов индикаторов
   if(BarsCalculated(hEmaF) < rates_total || BarsCalculated(hEmaS) < rates_total ||
      BarsCalculated(hEmaT) < rates_total || BarsCalculated(hRsi)  < rates_total ||
      BarsCalculated(hAtr)  < rates_total)
      return(prev_calculated);

   // Копируем индикаторы целиком (как series=false: [0]=старый, [rt-1]=текущий)
   if(CopyBuffer(hEmaF,0,0,rates_total,BufEmaF) < rates_total) return(prev_calculated);
   if(CopyBuffer(hEmaS,0,0,rates_total,BufEmaS) < rates_total) return(prev_calculated);
   if(CopyBuffer(hEmaT,0,0,rates_total,BufEmaT) < rates_total) return(prev_calculated);
   if(CopyBuffer(hRsi, 0,0,rates_total,gRsi)    < rates_total) return(prev_calculated);
   if(CopyBuffer(hAtr, 0,0,rates_total,gAtr)    < rates_total) return(prev_calculated);

   int startBar = warmup;
   if(InpMaxBars > 0)
      startBar = MathMax(warmup, rates_total - InpMaxBars);

   // На первом проходе обнуляем стрелки по всей истории
   if(prev_calculated <= 0)
      for(int i=0;i<rates_total;++i){ BufBuy[i]=EMPTY_VALUE; BufSell[i]=EMPTY_VALUE; }

   // Прятать EMA/VWAP вне окна анализа (CopyBuffer заполняет весь буфер реальными значениями)
   for(int i=0;i<startBar && i<rates_total;++i)
   {
      BufEmaF[i]=EMPTY_VALUE; BufEmaS[i]=EMPTY_VALUE;
      BufEmaT[i]=EMPTY_VALUE; BufVWAP[i]=EMPTY_VALUE;
   }

   // VWAP (дневной, с обнулением на новой дате сервера) — пересчёт каждый тик, дёшево
   ComputeVWAP(rates_total, startBar, time, high, low, close, tick_volume);

   bool isNewBar = (time[rates_total-1] != gLastBar);
   bool firstScan = (prev_calculated <= 0);

   // Сигналы и статистику пересчитываем только на новом баре / первом проходе:
   // закрытые бары не меняются, форминг-бар сигналов не даёт.
   if(isNewBar || firstScan)
   {
      RecomputeSignals(rates_total, startBar, time, open, high, low, close, spread);
      if(InpShowLevels) DrawLevels();
      if(InpShowDash)   DashUpdate(rates_total, time, close);
   }

   gLastBar = time[rates_total-1];
   return(rates_total);
}

//+==================================================================+
//| VWAP (anchored daily)                                             |
//+==================================================================+
void ComputeVWAP(int rt, int startBar,
                 const datetime &time[], const double &high[],
                 const double &low[], const double &close[],
                 const long &tick_volume[])
{
   double cumPV=0.0, cumV=0.0;
   int curDay = -1;
   for(int i=startBar;i<rt;++i)
   {
      MqlDateTime mt; TimeToStruct(time[i], mt);
      int dayKey = mt.year*1000 + mt.day_of_year;
      if(dayKey != curDay)
      {
         curDay = dayKey;
         cumPV = 0.0; cumV = 0.0;   // новый торговый день — обнуляем VWAP
      }
      double tp = (high[i]+low[i]+close[i])/3.0;
      double v  = (double)tick_volume[i];
      cumPV += tp * v;
      cumV  += v;
      BufVWAP[i] = (cumV>0.0) ? (cumPV/cumV) : close[i];
   }
}

//+==================================================================+
//| Пересчёт сигналов + статистика винрейта                           |
//+==================================================================+
void RecomputeSignals(int rt, int startBar,
                      const datetime &time[], const double &open[],
                      const double &high[], const double &low[],
                      const double &close[], const int &spread[])
{
   // сброс
   gSigTotal=0; gWins=0; gLosses=0; gOpen=0; gSumR=0.0; gBuyCnt=0; gSellCnt=0;
   gLastBuyBar=-100000; gLastSellBar=-100000; gLastBuyPrice=0; gLastSellPrice=0;
   ArrayResize(gSigTime,0); ArrayResize(gSigEntry,0);
   ArrayResize(gSigSL,0);   ArrayResize(gSigTP,0);   ArrayResize(gSigDir,0);

   for(int i=startBar;i<rt;++i){ BufBuy[i]=EMPTY_VALUE; BufSell[i]=EMPTY_VALUE; }

   int lastClosed = rt - 2;        // последний полностью закрытый бар
   if(lastClosed < startBar) return;

   double point = _Point;

   for(int i=startBar;i<=lastClosed;++i)
   {
      double atr = gAtr[i];
      if(atr <= 0.0) continue;

      // --- фильтры контекста ---
      if(InpUseSession && !InSession(time[i])) continue;
      if(InpAtrMinPts>0 && atr < InpAtrMinPts*point) continue;
      if(InpAtrMaxPts>0 && atr > InpAtrMaxPts*point) continue;
      if(InpMaxSpreadPts>0 && spread[i] > InpMaxSpreadPts) continue;

      // --- тренд (EMA stack) ---
      bool up   = (BufEmaF[i] > BufEmaS[i] && BufEmaS[i] > BufEmaT[i]);
      bool down = (BufEmaF[i] < BufEmaS[i] && BufEmaS[i] < BufEmaT[i]);

      // --- bias по VWAP ---
      if(InpUseVWAP)
      {
         double vw = BufVWAP[i];
         if(vw!=EMPTY_VALUE)
         {
            up   = up   && (close[i] > vw);
            down = down && (close[i] < vw);
         }
      }

      // --- откат к быстрой EMA + провал/всплеск RSI в окне ---
      double tol = InpPullbackATR * atr;
      bool taggedBuy=false, taggedSell=false;
      double rsiMin=101.0, rsiMax=-1.0;
      int from = i - InpPullbackLookback; if(from < startBar) from = startBar;
      for(int k=from;k<=i;++k)
      {
         if(low[k]  <= BufEmaF[k] + tol) taggedBuy  = true;  // тег быстрой EMA снизу
         if(high[k] >= BufEmaF[k] - tol) taggedSell = true;  // тег быстрой EMA сверху
         if(gRsi[k] < rsiMin) rsiMin = gRsi[k];
         if(gRsi[k] > rsiMax) rsiMax = gRsi[k];
      }

      // --- триггер импульса на текущем баре ---
      bool rsiTurnUp   = (gRsi[i] > gRsi[i-1]);
      bool rsiTurnDn   = (gRsi[i] < gRsi[i-1]);
      bool bullBar     = (close[i] > open[i]);
      bool bearBar     = (close[i] < open[i]);

      bool buy = up && taggedBuy &&
                 rsiMin <= InpRsiBuyDip &&
                 gRsi[i] >= InpRsiMid && gRsi[i] < InpRsiOverbought &&
                 rsiTurnUp && bullBar && close[i] > BufEmaF[i];

      bool sell = down && taggedSell &&
                  rsiMax >= InpRsiSellPop &&
                  gRsi[i] <= InpRsiMid && gRsi[i] > InpRsiOversold &&
                  rsiTurnDn && bearBar && close[i] < BufEmaF[i];

      if(!buy && !sell) continue;

      // --- cooldown / min distance ---
      if(buy)
      {
         if(InpCooldownBars>0 && (i - gLastBuyBar) < InpCooldownBars) continue;
         if(InpMinDistATR>0.0 && gLastBuyPrice>0.0 &&
            MathAbs(close[i]-gLastBuyPrice) < InpMinDistATR*atr) continue;
      }
      else
      {
         if(InpCooldownBars>0 && (i - gLastSellBar) < InpCooldownBars) continue;
         if(InpMinDistATR>0.0 && gLastSellPrice>0.0 &&
            MathAbs(close[i]-gLastSellPrice) < InpMinDistATR*atr) continue;
      }

      // --- расчёт SL/TP ---
      double entry = close[i];
      double risk  = InpSLATR * atr;
      double sl, tp;
      if(buy)
      {
         sl = entry - risk;
         if(InpSLUseSwing)
         {
            double lo = SwingLow(i, InpSwingLookback, low);
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
            double hi = SwingHigh(i, InpSwingLookback, high);
            if(hi>0.0) sl = MathMax(sl, hi + 0.10*atr);
         }
         risk = sl - entry;
         tp = entry - risk*InpRR;
      }
      if(risk <= 0.0) continue;

      // --- отметка стрелки ---
      double off = InpArrowOffATR * atr;
      if(InpShowArrows)
      {
         if(buy)  BufBuy[i]  = low[i]  - off;
         else     BufSell[i] = high[i] + off;
      }

      gSigTotal++;
      if(buy){ gBuyCnt++; gLastBuyBar=i; gLastBuyPrice=entry; }
      else   { gSellCnt++; gLastSellBar=i; gLastSellPrice=entry; }

      // --- forward-test для статистики винрейта ---
      int outcome = ForwardTest(i, rt, buy, sl, tp, high, low);
      if(outcome==1){ gWins++;  gSumR += InpRR; }
      else if(outcome==-1){ gLosses++; gSumR -= 1.0; }
      else gOpen++;

      // --- сохранить для отрисовки SL/TP ---
      PushSignal(time[i], entry, sl, tp, buy?1:-1);

      // --- алерт на свежем (только что закрытом) баре ---
      if(i==lastClosed) MaybeAlert(buy, entry, sl, tp, time[i]);
   }
}

// Возврат: 1=TP первым (win), -1=SL первым (loss), 0=не определено
int ForwardTest(int i, int rt, bool buy, double sl, double tp,
                const double &high[], const double &low[])
{
   int jmax = MathMin(rt-1, i + InpStatMaxFwd);
   for(int j=i+1;j<=jmax;++j)
   {
      if(buy)
      {
         bool hitSL = (low[j]  <= sl);
         bool hitTP = (high[j] >= tp);
         if(hitSL && hitTP) return(-1);   // консервативно: считаем убытком
         if(hitTP) return(1);
         if(hitSL) return(-1);
      }
      else
      {
         bool hitSL = (high[j] >= sl);
         bool hitTP = (low[j]  <= tp);
         if(hitSL && hitTP) return(-1);
         if(hitTP) return(1);
         if(hitSL) return(-1);
      }
   }
   return(0);
}

double SwingLow(int i, int lookback, const double &low[])
{
   double m = low[i];
   int from = i - lookback; if(from < 0) from = 0;
   for(int k=from;k<=i;++k) if(low[k] < m) m = low[k];
   return(m);
}
double SwingHigh(int i, int lookback, const double &high[])
{
   double m = high[i];
   int from = i - lookback; if(from < 0) from = 0;
   for(int k=from;k<=i;++k) if(high[k] > m) m = high[k];
   return(m);
}

void PushSignal(datetime t, double entry, double sl, double tp, int dir)
{
   int n = ArraySize(gSigTime);
   ArrayResize(gSigTime, n+1);  gSigTime[n]=t;
   ArrayResize(gSigEntry,n+1);  gSigEntry[n]=entry;
   ArrayResize(gSigSL,   n+1);  gSigSL[n]=sl;
   ArrayResize(gSigTP,   n+1);  gSigTP[n]=tp;
   ArrayResize(gSigDir,  n+1);  gSigDir[n]=dir;
}

bool InSession(datetime t)
{
   MqlDateTime mt; TimeToStruct(t, mt);
   int h = mt.hour;
   int s = InpSessStartHour, e = InpSessEndHour;
   if(s == e) return(true);                 // окно 24ч
   if(s < e)  return(h >= s && h < e);       // обычное окно
   return(h >= s || h < e);                  // окно через полночь
}

//+==================================================================+
//| Отрисовка SL/TP последних сигналов                                |
//+==================================================================+
void DrawLevels()
{
   // удалить прежние линии уровней
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;--i)
   {
      string nm = ObjectName(0,i,-1,-1);
      if(StringFind(nm, InpPrefix+"lv_")==0) ObjectDelete(0,nm);
   }

   int n = ArraySize(gSigTime);
   if(n==0) return;
   int show = MathMin(InpLevelsCount, n);
   long secs = (long)PeriodSeconds(_Period) * InpLevelsBars;

   for(int s=0;s<show;++s)
   {
      int idx = n-1-s;
      datetime t1 = gSigTime[idx];
      datetime t2 = t1 + (datetime)secs;
      string base = InpPrefix+"lv_"+IntegerToString((long)t1);

      DrawSeg(base+"_sl", t1, gSigSL[idx], t2, gSigSL[idx], InpSLColor, STYLE_DASH);
      DrawSeg(base+"_tp", t1, gSigTP[idx], t2, gSigTP[idx], InpTPColor, STYLE_DOT);
      DrawSeg(base+"_en", t1, gSigEntry[idx], t2, gSigEntry[idx],
              gSigDir[idx]>0?InpTPColor:InpSLColor, STYLE_DOT);
   }
}

void DrawSeg(string name, datetime t1, double p1, datetime t2, double p2,
             color clr, ENUM_LINE_STYLE style)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t1);
   ObjectSetDouble (0,name,OBJPROP_PRICE,0,p1);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,t2);
   ObjectSetDouble (0,name,OBJPROP_PRICE,1,p2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

//+==================================================================+
//| Алерты                                                            |
//+==================================================================+
void MaybeAlert(bool buy, double entry, double sl, double tp, datetime t)
{
   if(!InpAlert && !InpAlertPush) return;
   if(TimeCurrent() - t > PeriodSeconds()*2) return;   // не алертим историю
   if(gLastAlertBar == t) return;                       // один раз на бар
   gLastAlertBar = t;

   string dir = buy ? "BUY" : "SELL";
   string msg = StringFormat("%s %s: %s @ %s | SL %s | TP %s",
                  _Symbol, TFToStr(_Period), dir,
                  DoubleToString(entry,_Digits),
                  DoubleToString(sl,_Digits),
                  DoubleToString(tp,_Digits));
   if(InpAlert)     Alert(msg);
   if(InpAlertPush) SendNotification(msg);
}

string TFToStr(ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   StringReplace(s, "PERIOD_", "");
   return(s);
}

//+==================================================================+
//| Dashboard                                                         |
//+==================================================================+
void DashUpdate(int rt, const datetime &time[], const double &close[])
{
   int i = rt-1;
   double atr = gAtr[i];
   double winrate = (gWins+gLosses>0) ? (100.0*gWins/(gWins+gLosses)) : 0.0;
   double pf = (gLosses>0) ? ((gWins*InpRR)/(double)gLosses) : (gWins>0?999.0:0.0);
   double expR = (gWins+gLosses>0) ? (gSumR/(gWins+gLosses)) : 0.0;

   // bias
   string bias = "FLAT";
   color  biasClr = InpDashText;
   bool up   = (BufEmaF[i]>BufEmaS[i] && BufEmaS[i]>BufEmaT[i]);
   bool down = (BufEmaF[i]<BufEmaS[i] && BufEmaS[i]<BufEmaT[i]);
   double vw = BufVWAP[i];
   if(InpUseVWAP && vw!=EMPTY_VALUE)
   {
      up   = up   && close[i]>vw;
      down = down && close[i]<vw;
   }
   if(up){ bias="BULL"; biasClr=clrLime; }
   else if(down){ bias="BEAR"; biasClr=clrTomato; }

   bool sess = (!InpUseSession) || InSession(time[i]);
   long spr  = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   int x=InpDashX, y=InpDashY, lh=InpDashFont+7, w=232;
   int lines=12;
   DashBg(x-6, y-6, w, lines*lh+10);

   int yy=y;
   DashLabel("t0", x, yy, "GoldScalperPro  v1.00", InpDashAccent, InpDashFont+1); yy+=lh+2;
   DashLabel("t1", x, yy, _Symbol+"  "+TFToStr(_Period), InpDashText, InpDashFont); yy+=lh;
   DashLabel("t2", x, yy, "Bias:   "+bias, biasClr, InpDashFont); yy+=lh;
   DashLabel("t3", x, yy, "Session:"+(sess?" OPEN":" closed"),
             sess?clrLime:clrGray, InpDashFont); yy+=lh;
   DashLabel("t4", x, yy, "ATR:    "+DoubleToString(atr/_Point,0)+" pts",
             InpDashText, InpDashFont); yy+=lh;
   DashLabel("t5", x, yy, "Spread: "+IntegerToString(spr)+" pts",
             InpDashText, InpDashFont); yy+=lh;
   DashLabel("t6", x, yy, "------- stats (hist) -------", InpDashAccent, InpDashFont); yy+=lh;
   DashLabel("t7", x, yy, "Signals:"+IntegerToString(gSigTotal)+
             "  (B"+IntegerToString((int)gBuyCnt)+"/S"+IntegerToString((int)gSellCnt)+")",
             InpDashText, InpDashFont); yy+=lh;
   DashLabel("t8", x, yy, "Win/Loss:"+IntegerToString(gWins)+"/"+IntegerToString(gLosses)+
             "  open "+IntegerToString(gOpen), InpDashText, InpDashFont); yy+=lh;
   color wrClr = (winrate>=60.0)?clrLime:((winrate>=50.0)?InpDashAccent:clrTomato);
   DashLabel("t9", x, yy, "Win-rate:"+DoubleToString(winrate,1)+"%", wrClr, InpDashFont+1); yy+=lh;
   DashLabel("t10",x, yy, "Profit f:"+DoubleToString(pf,2)+
             "  RR "+DoubleToString(InpRR,2), InpDashText, InpDashFont); yy+=lh;
   DashLabel("t11",x, yy, "Expectancy:"+DoubleToString(expR,3)+" R", InpDashText, InpDashFont);
}

void DashBg(int x,int y,int w,int h)
{
   string nm = InpPrefix+"dash_bg";
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,nm,OBJPROP_CORNER,InpDashCorner);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nm,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,nm,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,InpDashBg);
   ObjectSetInteger(0,nm,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,C'70,75,90');
   ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
}

void DashLabel(string key,int x,int y,string text,color clr,int fs)
{
   string nm = InpPrefix+"dash_"+key;
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,nm,OBJPROP_CORNER,InpDashCorner);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fs);
   ObjectSetString (0,nm,OBJPROP_FONT,"Consolas");
   ObjectSetString (0,nm,OBJPROP_TEXT,text);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
}
//+------------------------------------------------------------------+
