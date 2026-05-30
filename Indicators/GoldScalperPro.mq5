//+------------------------------------------------------------------+
//|                                              GoldScalperPro.mq5   |
//|       Intraday / Scalping signals for Gold (XAUUSD)              |
//|       Trend EMA stack + Daily VWAP bias + RSI pullback trigger   |
//|       + HTF trend confirm + ATR-relative vol/spread filters      |
//|       + partial TP1/TP2 + win-rate/best-hours + symbol profiles  |
//|       + Fibonacci levels + lunar-phase overlay (no proven edge)  |
//|       Multi-symbol: gold, FX, indices, crypto (auto profile)     |
//|                                            Copyright 2026 Mago201|
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.30"
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
enum ENUM_GS_PROFILE
{
   GS_AUTO   = 0,   // Авто (определить по символу)
   GS_CUSTOM = 1,   // Вручную (мои настройки сессии)
   GS_GOLD   = 2,   // Золото / серебро (London+NY)
   GS_FX     = 3,   // FX мажоры EUR/GBP/USD (London+NY)
   GS_JPY    = 4,   // JPY/AUD/NZD (Азия+London)
   GS_INDEX  = 5,   // Индексы US/EU (US-сессия)
   GS_CRYPTO = 6    // Крипта (24/7, без фильтра сессии)
};

input group "=== Профиль инструмента (мульти-символьность) ==="
input ENUM_GS_PROFILE InpProfile = GS_AUTO;  // Профиль: задаёт окно сессии под класс актива

input group "=== Тренд (EMA stack) ==="
input int    InpEmaFast      = 8;            // Быстрая EMA
input int    InpEmaSlow      = 21;           // Средняя EMA
input int    InpEmaTrend     = 50;           // Трендовая EMA (фильтр направления)
input bool   InpShowEMA      = true;         // Показывать линии EMA

input group "=== VWAP (дневной, bias) ==="
input bool   InpUseVWAP      = true;         // Требовать совпадения с VWAP (цена выше=BUY, ниже=SELL)
input bool   InpShowVWAP     = true;         // Рисовать линию VWAP

input group "=== Подтверждение со старшего ТФ (HTF) ==="
input bool            InpUseHTF       = true;        // Требовать совпадения с трендом старшего ТФ
input ENUM_TIMEFRAMES InpHTF          = PERIOD_H1;   // Старший таймфрейм
input int             InpHtfEmaPeriod = 50;          // Период EMA на старшем ТФ (фильтр: цена выше=BUY)

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

input group "=== Волатильность / ATR (режим, символо-независимо) ==="
input int    InpAtrPeriod    = 14;           // Период ATR
input int    InpAtrAvgPeriod = 100;          // Период средней ATR (базовый «нормальный» уровень)
input double InpAtrRegimeMin = 0.0;          // Мин. ATR / средняя ATR (0=выкл; напр. 0.6 = не торговать в штиль)
input double InpAtrRegimeMax = 0.0;          // Макс. ATR / средняя ATR (0=выкл; напр. 3.0 = не торговать на всплеске)

input group "=== Риск (SL/TP) ==="
input double InpSLATR        = 1.20;         // SL = ATR * множитель
input double InpRR           = 1.00;         // R:R одиночного TP (если частичные выключены)
input bool   InpSLUseSwing   = false;        // SL за локальный экстремум (иначе чистый ATR)
input int    InpSwingLookback= 10;           // Окно локального экстремума для SL

input group "=== Частичные цели (TP1/TP2) ==="
input bool   InpUsePartialTP = true;         // Частичная фиксация: половина на TP1, остаток на TP2 (стоп в БУ)
input double InpRR1          = 1.00;         // R:R для TP1 (фиксируем половину)
input double InpRR2          = 2.00;         // R:R для TP2 (остаток после перевода в БУ)

input group "=== Фильтр сессии (часы сервера) ==="
input bool   InpUseSession   = true;         // Торговать только в заданном окне
input int    InpSessStartHour= 8;            // Старт окна (London open ~ 8)
input int    InpSessEndHour  = 21;           // Конец окна (NY ~ 21)

input group "=== Авто-анализ лучших часов (по истории) ==="
input bool   InpShowBestHours  = true;       // Считать винрейт по часам и показывать лучшие
input int    InpBestHoursMinTr = 5;          // Мин. сделок в часе для учёта
input int    InpBestHoursTopN  = 4;          // Сколько лучших часов показать в панели
input bool   InpAutoHoursApply = false;      // Автоматически торговать ТОЛЬКО в лучших часах (вместо окна сессии)
input double InpAutoHoursMinWR = 50.0;       // Порог винрейта часа для авто-допуска (%)

input group "=== Прочие фильтры ==="
input double InpMaxSpreadATR = 0.0;          // Макс. спред в долях ATR (0=выкл; напр. 0.15 = 15% ATR). Символо-независимо
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

input group "=== Фибоначчи (авто-разметка от свинга) ==="
input bool   InpShowFib       = true;        // Авто-уровни Фибоначчи от последнего свинг-импульса
input int    InpFibPivot      = 5;           // Окно пивота (баров слева/справа для свинга)
input int    InpFibExtendBars = 40;          // Длина линий вправо (баров)
input bool   InpFibShowExt    = true;        // Показывать расширения 1.272 / 1.618 (кандидаты TP)
input color  InpFibColor      = clrGoldenrod;     // Цвет уровней ретрейсмента
input color  InpFibExtColor   = clrMediumPurple;  // Цвет расширений

input group "=== Астро-оверлей: фазы Луны (БЕЗ доказанного перевеса) ==="
input bool   InpShowAstro     = false;       // Метки новолуния/полнолуния — ТОЛЬКО для вашей проверки
input color  InpAstroNewColor = C'90,90,105';     // Новолуние (вертикаль)
input color  InpAstroFullColor= C'160,160,90';    // Полнолуние (вертикаль)

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
double gAtrAvg[];           // средняя ATR (базовый уровень волатильности для режимного фильтра)
double gHtfEma[];            // EMA старшего ТФ, выровненная по барам текущего ТФ

int    hEmaF = INVALID_HANDLE;
int    hEmaS = INVALID_HANDLE;
int    hEmaT = INVALID_HANDLE;
int    hRsi  = INVALID_HANDLE;
int    hAtr  = INVALID_HANDLE;
int    hHtfEma = INVALID_HANDLE;

datetime gLastBar      = 0;   // время последнего обработанного бара (детект нового бара)
datetime gLastAlertBar = 0;   // против повторного алерта на том же баре
int      gLastBuyBar   = -100000;
int      gLastSellBar  = -100000;
double   gLastBuyPrice = 0.0;
double   gLastSellPrice= 0.0;

// Статистика по истории
int      gSigTotal=0, gWins=0, gLosses=0, gOpen=0;
double   gSumR=0.0;           // суммарный результат в R
double   gGrossWin=0.0, gGrossLoss=0.0;  // для profit factor (в R)
double   gBuyCnt=0, gSellCnt=0;
int      gTp2Hits=0;          // сколько сделок дошли до TP2
int      gHourWins[24];       // винрейт по часам (для авто-анализа лучших часов)
int      gHourLosses[24];
bool     gHourAllowed[24];    // часы, разрешённые авто-режимом (InpAutoHoursApply)

// Эффективный профиль/сессия (рассчитывается из InpProfile)
int      gSessStart = 0;
int      gSessEnd   = 24;
bool     gUseSession = true;
string   gSymClass  = "custom";

// Для отрисовки SL/TP последних сигналов
datetime gSigTime[];
double   gSigEntry[];
double   gSigSL[];
double   gSigTP[];
double   gSigTP2[];
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
   ArraySetAsSeries(gAtrAvg, false);
   ArraySetAsSeries(gHtfEma, false);

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

   ENUM_TIMEFRAMES htf = (InpHTF > _Period) ? InpHTF : _Period;  // HTF не ниже текущего
   hHtfEma = iMA(_Symbol, htf, MathMax(1, InpHtfEmaPeriod), 0, MODE_EMA, PRICE_CLOSE);

   if(hEmaF==INVALID_HANDLE || hEmaS==INVALID_HANDLE || hEmaT==INVALID_HANDLE ||
      hRsi==INVALID_HANDLE  || hAtr==INVALID_HANDLE || hHtfEma==INVALID_HANDLE)
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
   ArrayResize(gSigTP2,0);
   ArrayInitialize(gHourWins, 0);
   ArrayInitialize(gHourLosses, 0);
   ArrayInitialize(gHourAllowed, 0);

   SetupProfile();   // эффективная сессия по профилю инструмента

   ClearAll();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(hEmaF!=INVALID_HANDLE) IndicatorRelease(hEmaF);
   if(hEmaS!=INVALID_HANDLE) IndicatorRelease(hEmaS);
   if(hEmaT!=INVALID_HANDLE) IndicatorRelease(hEmaT);
   if(hRsi !=INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAtr !=INVALID_HANDLE) IndicatorRelease(hAtr);
   if(hHtfEma!=INVALID_HANDLE) IndicatorRelease(hHtfEma);
   ClearAll();
   Comment("");
}

// Определение класса инструмента по имени символа
int DetectProfile()
{
   string s = _Symbol;
   StringToUpper(s);
   if(StringFind(s,"XAU")>=0 || StringFind(s,"GOLD")>=0 || StringFind(s,"GLD")>=0 ||
      StringFind(s,"XAG")>=0 || StringFind(s,"SILVER")>=0)
      return GS_GOLD;
   if(StringFind(s,"BTC")>=0 || StringFind(s,"ETH")>=0 || StringFind(s,"USDT")>=0 ||
      StringFind(s,"CRYPTO")>=0 || StringFind(s,"XRP")>=0 || StringFind(s,"SOL")>=0)
      return GS_CRYPTO;
   if(StringFind(s,"US30")>=0 || StringFind(s,"US500")>=0 || StringFind(s,"SPX")>=0 ||
      StringFind(s,"NAS")>=0 || StringFind(s,"NDX")>=0 || StringFind(s,"DAX")>=0 ||
      StringFind(s,"GER")>=0 || StringFind(s,"UK100")>=0 || StringFind(s,"JP225")>=0 ||
      StringFind(s,"US100")>=0 || StringFind(s,"USTEC")>=0)
      return GS_INDEX;
   if(StringFind(s,"JPY")>=0 || StringFind(s,"AUD")>=0 || StringFind(s,"NZD")>=0)
      return GS_JPY;
   return GS_FX;
}

// Расчёт эффективной сессии по выбранному/определённому профилю
void SetupProfile()
{
   // по умолчанию — пользовательские настройки (CUSTOM)
   gUseSession = InpUseSession;
   gSessStart  = InpSessStartHour;
   gSessEnd    = InpSessEndHour;
   gSymClass   = "custom";

   int prof = InpProfile;
   if(prof == GS_CUSTOM) return;
   if(prof == GS_AUTO)   prof = DetectProfile();

   switch(prof)
   {
      case GS_GOLD:   gSymClass="gold";   gUseSession=true;  gSessStart=8;  gSessEnd=21; break;
      case GS_FX:     gSymClass="fx";     gUseSession=true;  gSessStart=7;  gSessEnd=20; break;
      case GS_JPY:    gSymClass="jpy/asia";gUseSession=true; gSessStart=0;  gSessEnd=16; break;
      case GS_INDEX:  gSymClass="index";  gUseSession=true;  gSessStart=13; gSessEnd=21; break;
      case GS_CRYPTO: gSymClass="crypto"; gUseSession=false; gSessStart=0;  gSessEnd=24; break;
      default: break;
   }
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

   // HTF EMA готов? (BarsCalculated в барах старшего ТФ — сравниваем с 0)
   if(InpUseHTF && BarsCalculated(hHtfEma) <= 0) return(prev_calculated);

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
      DrawFib(rates_total, startBar, time, high, low);
      DrawAstro(rates_total, startBar, time);
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
   // сброс статистики
   gSigTotal=0; gWins=0; gLosses=0; gOpen=0;
   gSumR=0.0; gGrossWin=0.0; gGrossLoss=0.0; gBuyCnt=0; gSellCnt=0; gTp2Hits=0;
   gLastBuyBar=-100000; gLastSellBar=-100000; gLastBuyPrice=0; gLastSellPrice=0;
   ArrayResize(gSigTime,0); ArrayResize(gSigEntry,0);
   ArrayResize(gSigSL,0);   ArrayResize(gSigTP,0);
   ArrayResize(gSigTP2,0);  ArrayResize(gSigDir,0);

   for(int i=startBar;i<rt;++i){ BufBuy[i]=EMPTY_VALUE; BufSell[i]=EMPTY_VALUE; }

   // выровнять EMA старшего ТФ по барам текущего ТФ
   BuildHtfEma(rt, startBar, time);

   // средняя ATR (для режимного фильтра волатильности)
   BuildAtrAvg(rt, startBar);

   // винрейт по часам — по «сырым» сигналам (без сессии/cooldown), для подсказки лучших часов
   AccumulateHourStats(rt, startBar, time, open, high, low, close, spread);

   // если включён авто-режим — определить разрешённые часы
   ComputeAllowedHours();

   int lastClosed = rt - 2;        // последний полностью закрытый бар
   if(lastClosed < startBar) return;

   for(int i=startBar;i<=lastClosed;++i)
   {
      double entry, sl, tp1, tp2;
      int dir = EvalSignal(i, startBar, time, open, high, low, close, spread, entry, sl, tp1, tp2);
      if(dir==0) continue;

      double atr = gAtr[i];

      // --- фильтр времени (профиль/сессия или авто-часы) ---
      if(!SessionAllowed(time[i])) continue;

      // --- cooldown / min distance ---
      if(dir>0)
      {
         if(InpCooldownBars>0 && (i - gLastBuyBar) < InpCooldownBars) continue;
         if(InpMinDistATR>0.0 && gLastBuyPrice>0.0 &&
            MathAbs(entry-gLastBuyPrice) < InpMinDistATR*atr) continue;
      }
      else
      {
         if(InpCooldownBars>0 && (i - gLastSellBar) < InpCooldownBars) continue;
         if(InpMinDistATR>0.0 && gLastSellPrice>0.0 &&
            MathAbs(entry-gLastSellPrice) < InpMinDistATR*atr) continue;
      }

      // --- отметка стрелки ---
      double off = InpArrowOffATR * atr;
      if(InpShowArrows)
      {
         if(dir>0) BufBuy[i]  = low[i]  - off;
         else      BufSell[i] = high[i] + off;
      }

      gSigTotal++;
      if(dir>0){ gBuyCnt++; gLastBuyBar=i; gLastBuyPrice=entry; }
      else     { gSellCnt++; gLastSellBar=i; gLastSellPrice=entry; }

      // --- forward-test (одиночный TP или TP1/TP2 с переводом в БУ) ---
      double rMult; bool tp2hit;
      int outcome = ForwardOutcome(i, rt, dir, entry, sl, tp1, tp2, high, low, rMult, tp2hit);
      if(outcome==1){ gWins++;  gGrossWin += rMult; gSumR += rMult; if(tp2hit) gTp2Hits++; }
      else if(outcome==-1){ gLosses++; gGrossLoss += (-rMult); gSumR += rMult; }
      else gOpen++;

      // --- сохранить для отрисовки SL/TP ---
      PushSignal(time[i], entry, sl, tp1, tp2, dir);

      // --- алерт на свежем (только что закрытом) баре ---
      if(i==lastClosed) MaybeAlert(dir>0, entry, sl, tp1, tp2, time[i]);
   }
}

// Оценка сигнала на баре i БЕЗ фильтров сессии/cooldown (применяются снаружи).
// Возврат: 1 buy, -1 sell, 0 нет. Заполняет entry/sl/tp1/tp2.
int EvalSignal(int i, int startBar,
               const datetime &time[], const double &open[],
               const double &high[], const double &low[],
               const double &close[], const int &spread[],
               double &entry, double &sl, double &tp1, double &tp2)
{
   entry=0; sl=0; tp1=0; tp2=0;
   double atr = gAtr[i];
   if(atr <= 0.0) return 0;

   // режимный фильтр волатильности: ATR относительно своей средней (символо-независимо)
   if(InpAtrRegimeMin>0.0 || InpAtrRegimeMax>0.0)
   {
      double avg = (i<ArraySize(gAtrAvg)) ? gAtrAvg[i] : 0.0;
      if(avg>0.0)
      {
         double ratio = atr/avg;
         if(InpAtrRegimeMin>0.0 && ratio < InpAtrRegimeMin) return 0;
         if(InpAtrRegimeMax>0.0 && ratio > InpAtrRegimeMax) return 0;
      }
   }
   // спред-фильтр в долях ATR (символо-независимо)
   if(InpMaxSpreadATR>0.0 && ((double)spread[i]*_Point) > InpMaxSpreadATR*atr) return 0;

   // тренд (EMA stack)
   bool up   = (BufEmaF[i] > BufEmaS[i] && BufEmaS[i] > BufEmaT[i]);
   bool down = (BufEmaF[i] < BufEmaS[i] && BufEmaS[i] < BufEmaT[i]);

   // bias по VWAP
   if(InpUseVWAP)
   {
      double vw = BufVWAP[i];
      if(vw!=EMPTY_VALUE){ up = up && (close[i]>vw); down = down && (close[i]<vw); }
   }
   // подтверждение со старшего ТФ (цена выше/ниже HTF EMA)
   if(InpUseHTF)
   {
      double he = (i<ArraySize(gHtfEma)) ? gHtfEma[i] : 0.0;
      if(he>0.0){ up = up && (close[i]>he); down = down && (close[i]<he); }
   }

   // откат к быстрой EMA + провал/всплеск RSI в окне
   double tol = InpPullbackATR * atr;
   bool taggedBuy=false, taggedSell=false;
   double rsiMin=101.0, rsiMax=-1.0;
   int from = i - InpPullbackLookback; if(from < startBar) from = startBar;
   for(int k=from;k<=i;++k)
   {
      if(low[k]  <= BufEmaF[k] + tol) taggedBuy  = true;
      if(high[k] >= BufEmaF[k] - tol) taggedSell = true;
      if(gRsi[k] < rsiMin) rsiMin = gRsi[k];
      if(gRsi[k] > rsiMax) rsiMax = gRsi[k];
   }

   bool buy = up && taggedBuy &&
              rsiMin <= InpRsiBuyDip &&
              gRsi[i] >= InpRsiMid && gRsi[i] < InpRsiOverbought &&
              (gRsi[i] > gRsi[i-1]) && (close[i] > open[i]) && close[i] > BufEmaF[i];

   bool sell = down && taggedSell &&
               rsiMax >= InpRsiSellPop &&
               gRsi[i] <= InpRsiMid && gRsi[i] > InpRsiOversold &&
               (gRsi[i] < gRsi[i-1]) && (close[i] < open[i]) && close[i] < BufEmaF[i];

   if(!buy && !sell) return 0;

   entry = close[i];
   double risk = InpSLATR * atr;
   double rr1 = InpUsePartialTP ? InpRR1 : InpRR;
   double rr2 = InpUsePartialTP ? InpRR2 : InpRR;
   if(buy)
   {
      sl = entry - risk;
      if(InpSLUseSwing){ double lo=SwingLow(i,InpSwingLookback,low); if(lo>0.0) sl=MathMin(sl, lo-0.10*atr); }
      risk = entry - sl;
      if(risk<=0.0) return 0;
      tp1 = entry + risk*rr1;
      tp2 = entry + risk*rr2;
      return 1;
   }
   else
   {
      sl = entry + risk;
      if(InpSLUseSwing){ double hi=SwingHigh(i,InpSwingLookback,high); if(hi>0.0) sl=MathMax(sl, hi+0.10*atr); }
      risk = sl - entry;
      if(risk<=0.0) return 0;
      tp1 = entry - risk*rr1;
      tp2 = entry - risk*rr2;
      return -1;
   }
}

// Forward-test. Возврат: 1 win (TP1/TP достигнут), -1 loss (SL), 0 не определено.
// rMult — результат в R (с учётом частичной фиксации); tp2hit — дошли до TP2.
int ForwardOutcome(int i, int rt, int dir, double entry, double sl,
                   double tp1, double tp2, const double &high[], const double &low[],
                   double &rMult, bool &tp2hit)
{
   rMult = 0.0; tp2hit = false;
   int jmax = MathMin(rt-1, i + InpStatMaxFwd);

   // одиночный TP
   if(!InpUsePartialTP)
   {
      for(int j=i+1;j<=jmax;++j)
      {
         if(dir>0)
         {
            bool hitSL=(low[j]<=sl), hitTP=(high[j]>=tp1);
            if(hitSL && hitTP){ rMult=-1.0; return -1; }
            if(hitTP){ rMult=InpRR; return 1; }
            if(hitSL){ rMult=-1.0; return -1; }
         }
         else
         {
            bool hitSL=(high[j]>=sl), hitTP=(low[j]<=tp1);
            if(hitSL && hitTP){ rMult=-1.0; return -1; }
            if(hitTP){ rMult=InpRR; return 1; }
            if(hitSL){ rMult=-1.0; return -1; }
         }
      }
      return 0;
   }

   // частичные: 1/2 на TP1 + перевод стопа в БУ, остаток на TP2
   bool tp1done=false;
   for(int j=i+1;j<=jmax;++j)
   {
      if(dir>0)
      {
         bool hitSL=(low[j]<=sl), hitTP1=(high[j]>=tp1), hitTP2=(high[j]>=tp2), hitBE=(low[j]<=entry);
         if(!tp1done)
         {
            if(hitSL && hitTP1){ rMult=-1.0; return -1; }   // ambiguous до TP1 -> убыток
            if(hitTP1)
            {
               tp1done=true;
               if(hitTP2){ tp2hit=true; rMult=0.5*InpRR1 + 0.5*InpRR2; return 1; }
               continue;
            }
            if(hitSL){ rMult=-1.0; return -1; }
         }
         else
         {
            if(hitTP2 && hitBE){ rMult=0.5*InpRR1; return 1; }       // ambiguous -> в БУ
            if(hitTP2){ tp2hit=true; rMult=0.5*InpRR1 + 0.5*InpRR2; return 1; }
            if(hitBE){ rMult=0.5*InpRR1; return 1; }
         }
      }
      else
      {
         bool hitSL=(high[j]>=sl), hitTP1=(low[j]<=tp1), hitTP2=(low[j]<=tp2), hitBE=(high[j]>=entry);
         if(!tp1done)
         {
            if(hitSL && hitTP1){ rMult=-1.0; return -1; }
            if(hitTP1)
            {
               tp1done=true;
               if(hitTP2){ tp2hit=true; rMult=0.5*InpRR1 + 0.5*InpRR2; return 1; }
               continue;
            }
            if(hitSL){ rMult=-1.0; return -1; }
         }
         else
         {
            if(hitTP2 && hitBE){ rMult=0.5*InpRR1; return 1; }
            if(hitTP2){ tp2hit=true; rMult=0.5*InpRR1 + 0.5*InpRR2; return 1; }
            if(hitBE){ rMult=0.5*InpRR1; return 1; }
         }
      }
   }
   if(tp1done){ rMult=0.5*InpRR1; return 1; }   // половина зафиксирована, остаток открыт -> win
   return 0;
}

// Выравнивание EMA старшего ТФ по барам текущего ТФ (через iBarShift)
void BuildHtfEma(int rt, int startBar, const datetime &time[])
{
   if(ArraySize(gHtfEma)!=rt) ArrayResize(gHtfEma, rt);
   for(int i=0;i<rt;++i) gHtfEma[i]=0.0;
   if(!InpUseHTF || hHtfEma==INVALID_HANDLE) return;

   ENUM_TIMEFRAMES htf = (InpHTF > _Period) ? InpHTF : _Period;
   int needShift = iBarShift(_Symbol, htf, time[startBar], false);
   if(needShift < 0) return;
   int cnt = needShift + 4;

   double tmp[];
   ArraySetAsSeries(tmp, true);
   if(CopyBuffer(hHtfEma, 0, 0, cnt, tmp) < cnt) return;  // ещё не готово

   for(int i=startBar;i<rt;++i)
   {
      // +1 = предыдущий ЗАКРЫТЫЙ бар старшего ТФ (без перерисовки/заглядывания вперёд)
      int sh = iBarShift(_Symbol, htf, time[i], false) + 1;
      if(sh < 0) sh = 0;
      if(sh >= cnt) sh = cnt-1;
      gHtfEma[i] = tmp[sh];
   }
}

// Винрейт по часам — по «сырым» сигналам (без фильтра сессии/cooldown),
// чтобы подсказать лучшие часы для торговли.
void AccumulateHourStats(int rt, int startBar,
                         const datetime &time[], const double &open[],
                         const double &high[], const double &low[],
                         const double &close[], const int &spread[])
{
   ArrayInitialize(gHourWins, 0);
   ArrayInitialize(gHourLosses, 0);
   if(!InpShowBestHours) return;

   int lastClosed = rt - 2;
   for(int i=startBar;i<=lastClosed;++i)
   {
      double e, sl, tp1, tp2;
      int dir = EvalSignal(i, startBar, time, open, high, low, close, spread, e, sl, tp1, tp2);
      if(dir==0) continue;
      double rMult; bool t2;
      int ret = ForwardOutcome(i, rt, dir, e, sl, tp1, tp2, high, low, rMult, t2);
      if(ret==0) continue;
      MqlDateTime mt; TimeToStruct(time[i], mt);
      if(ret==1) gHourWins[mt.hour]++; else gHourLosses[mt.hour]++;
   }
}

// Строка лучших часов по винрейту (топ-N с порогом по числу сделок)
string BestHoursStr()
{
   int    hh[24]; double wr[24]; int tr[24]; int m=0;
   for(int h=0;h<24;++h)
   {
      int t = gHourWins[h] + gHourLosses[h];
      if(t >= InpBestHoursMinTr)
      {
         hh[m]=h; tr[m]=t; wr[m]=100.0*gHourWins[h]/t; m++;
      }
   }
   if(m==0) return "n/a (мало данных)";
   for(int a=0;a<m;++a)
      for(int b=a+1;b<m;++b)
         if(wr[b] > wr[a])
         {
            double tw=wr[a]; wr[a]=wr[b]; wr[b]=tw;
            int th=hh[a]; hh[a]=hh[b]; hh[b]=th;
            int tt=tr[a]; tr[a]=tr[b]; tr[b]=tt;
         }
   int show = MathMin(InpBestHoursTopN, m);
   string s="";
   for(int k=0;k<show;++k)
      s += StringFormat("%02d:%.0f%% ", hh[k], wr[k]);
   return s;
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

void PushSignal(datetime t, double entry, double sl, double tp1, double tp2, int dir)
{
   int n = ArraySize(gSigTime);
   ArrayResize(gSigTime, n+1);  gSigTime[n]=t;
   ArrayResize(gSigEntry,n+1);  gSigEntry[n]=entry;
   ArrayResize(gSigSL,   n+1);  gSigSL[n]=sl;
   ArrayResize(gSigTP,   n+1);  gSigTP[n]=tp1;
   ArrayResize(gSigTP2,  n+1);  gSigTP2[n]=tp2;
   ArrayResize(gSigDir,  n+1);  gSigDir[n]=dir;
}

bool InSession(datetime t)
{
   MqlDateTime mt; TimeToStruct(t, mt);
   int h = mt.hour;
   int s = gSessStart, e = gSessEnd;
   if(s == e) return(true);                 // окно 24ч
   if(s < e)  return(h >= s && h < e);       // обычное окно
   return(h >= s || h < e);                  // окно через полночь
}

// Допуск по времени: авто-режим лучших часов ИЛИ окно сессии профиля
bool SessionAllowed(datetime t)
{
   if(InpAutoHoursApply)
   {
      MqlDateTime mt; TimeToStruct(t, mt);
      return gHourAllowed[mt.hour];
   }
   if(!gUseSession) return true;
   return InSession(t);
}

// Сформировать список разрешённых часов из почасовой статистики
void ComputeAllowedHours()
{
   for(int h=0;h<24;++h) gHourAllowed[h]=false;
   if(!InpAutoHoursApply) return;
   for(int h=0;h<24;++h)
   {
      int t = gHourWins[h] + gHourLosses[h];
      if(t >= InpBestHoursMinTr && (100.0*gHourWins[h]/t) >= InpAutoHoursMinWR)
         gHourAllowed[h] = true;
   }
}

// Средняя ATR (бегущее среднее) — базовый уровень для режимного фильтра
void BuildAtrAvg(int rt, int startBar)
{
   if(ArraySize(gAtrAvg)!=rt) ArrayResize(gAtrAvg, rt);
   int p = MathMax(2, InpAtrAvgPeriod);
   double run=0.0;
   for(int i=0;i<rt;++i)
   {
      run += gAtr[i];
      if(i>=p) run -= gAtr[i-p];
      int denom = (i+1<p) ? (i+1) : p;
      gAtrAvg[i] = (denom>0) ? run/denom : gAtr[i];
   }
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
      if(InpUsePartialTP)
         DrawSeg(base+"_tp2", t1, gSigTP2[idx], t2, gSigTP2[idx], InpTPColor, STYLE_DASHDOT);
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
//| Удаление объектов по тегу                                         |
//+==================================================================+
void ClearTag(string tag)
{
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;--i)
   {
      string nm = ObjectName(0,i,-1,-1);
      if(StringFind(nm, InpPrefix+tag)==0) ObjectDelete(0,nm);
   }
}

//+==================================================================+
//| Фибоначчи: авто-разметка от последнего свинг-импульса             |
//+==================================================================+
bool IsPivotHigh(int k, int piv, const double &high[])
{
   for(int j=1;j<=piv;++j)
      if(high[k] < high[k-j] || high[k] < high[k+j]) return false;
   return true;
}
bool IsPivotLow(int k, int piv, const double &low[])
{
   for(int j=1;j<=piv;++j)
      if(low[k] > low[k-j] || low[k] > low[k+j]) return false;
   return true;
}

void FibLabel(string name, datetime t, double price, string txt, color clr)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,t,price);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t);
   ObjectSetDouble (0,name,OBJPROP_PRICE,0,price);
   ObjectSetString (0,name,OBJPROP_TEXT," "+txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DrawFib(int rt, int startBar, const datetime &time[],
             const double &high[], const double &low[])
{
   ClearTag("fib_");
   if(!InpShowFib) return;

   int piv  = MathMax(1, InpFibPivot);
   int last = rt - 1 - piv;             // последний бар, который может быть подтверждённым пивотом
   int lo   = startBar + piv;
   if(last <= lo) return;

   int phIdx=-1, plIdx=-1;
   for(int k=last;k>=lo;--k)
   {
      if(phIdx<0 && IsPivotHigh(k,piv,high)) phIdx=k;
      if(plIdx<0 && IsPivotLow (k,piv,low )) plIdx=k;
      if(phIdx>=0 && plIdx>=0) break;
   }
   if(phIdx<0 || plIdx<0) return;

   bool upLeg = (phIdx > plIdx);                 // более новый пивот — хай => восходящий импульс
   double p0  = upLeg ? low[plIdx]  : high[phIdx]; // 0%
   double p1  = upLeg ? high[phIdx] : low[plIdx];  // 100%
   int    aIdx= MathMin(phIdx, plIdx);             // начало импульса (старший пивот)

   datetime t1 = time[aIdx];
   datetime t2 = time[rt-1] + (datetime)((long)PeriodSeconds(_Period) * InpFibExtendBars);

   double fl[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
   for(int n=0;n<ArraySize(fl);++n)
   {
      double pr = p0 + (p1-p0)*fl[n];
      string nm = InpPrefix+"fib_"+DoubleToString(fl[n],3);
      ENUM_LINE_STYLE st = (fl[n]==0.5 || fl[n]==0.618) ? STYLE_SOLID : STYLE_DOT;
      DrawSeg(nm, t1, pr, t2, pr, InpFibColor, st);
      FibLabel(nm+"_l", t2, pr, DoubleToString(fl[n],3), InpFibColor);
   }
   if(InpFibShowExt)
   {
      double ex[] = {1.272, 1.618};
      for(int n=0;n<ArraySize(ex);++n)
      {
         double pr = p0 + (p1-p0)*ex[n];
         string nm = InpPrefix+"fib_ext_"+DoubleToString(ex[n],3);
         DrawSeg(nm, t1, pr, t2, pr, InpFibExtColor, STYLE_DASH);
         FibLabel(nm+"_l", t2, pr, "ext "+DoubleToString(ex[n],3), InpFibExtColor);
      }
   }
}

//+==================================================================+
//| Астро-оверлей: фазы Луны (детерминированная астрономия).          |
//| ВНИМАНИЕ: доказанного торгового перевеса у фаз Луны НЕТ.          |
//| Метки даны только для самостоятельной визуальной проверки.       |
//| Время событий — UTC; на графике серверное время (возможен сдвиг).|
//+==================================================================+
void DrawVLine(string name, datetime t, color clr)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_VLINE,0,t,0);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DrawAstro(int rt, int startBar, const datetime &time[])
{
   ClearTag("moon_");
   if(!InpShowAstro) return;

   double ref = 947182440.0;   // 2000-01-06 18:14 UTC — эталонное новолуние
   double syn = 2551442.9;     // синодический месяц, сек (~29.53 сут)

   for(int i=startBar+1;i<rt;++i)
   {
      double gPrev = ((double)time[i-1] - ref) / syn;
      double gCur  = ((double)time[i]   - ref) / syn;
      // новолуние — пересечение целого значения фазы
      if(MathFloor(gCur) != MathFloor(gPrev))
         DrawVLine(InpPrefix+"moon_n_"+IntegerToString((long)time[i]), time[i], InpAstroNewColor);
      // полнолуние — пересечение значения (целое+0.5)
      if(MathFloor(gCur-0.5) != MathFloor(gPrev-0.5))
         DrawVLine(InpPrefix+"moon_f_"+IntegerToString((long)time[i]), time[i], InpAstroFullColor);
   }
}

//+==================================================================+
//| Алерты                                                            |
//+==================================================================+
void MaybeAlert(bool buy, double entry, double sl, double tp1, double tp2, datetime t)
{
   if(!InpAlert && !InpAlertPush) return;
   if(TimeCurrent() - t > PeriodSeconds()*2) return;   // не алертим историю
   if(gLastAlertBar == t) return;                       // один раз на бар
   gLastAlertBar = t;

   string dir = buy ? "BUY" : "SELL";
   string tps = InpUsePartialTP
                ? StringFormat("TP1 %s | TP2 %s", DoubleToString(tp1,_Digits), DoubleToString(tp2,_Digits))
                : StringFormat("TP %s", DoubleToString(tp1,_Digits));
   string msg = StringFormat("%s %s: %s @ %s | SL %s | %s",
                  _Symbol, TFToStr(_Period), dir,
                  DoubleToString(entry,_Digits), DoubleToString(sl,_Digits), tps);
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
   double pf = (gGrossLoss>0.0) ? (gGrossWin/gGrossLoss) : (gGrossWin>0.0?999.0:0.0);
   double expR = (gWins+gLosses>0) ? (gSumR/(gWins+gLosses)) : 0.0;

   // bias текущего ТФ
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

   // HTF bias
   string htfStr = "off";
   if(InpUseHTF)
   {
      double he = (i<ArraySize(gHtfEma)) ? gHtfEma[i] : 0.0;
      if(he<=0.0) htfStr = "...";
      else        htfStr = (close[i]>he) ? "BULL" : "BEAR";
   }

   bool   sess = SessionAllowed(time[i]);
   string sessStr;
   if(InpAutoHoursApply)        sessStr = "Time: auto-hours"+(sess?" OK":" -");
   else if(gUseSession)         sessStr = "Sess "+IntegerToString(gSessStart)+"-"+IntegerToString(gSessEnd)+
                                          (sess?" OPEN":" closed");
   else                         sessStr = "Sess: off (24h)";

   double avg = (i<ArraySize(gAtrAvg)) ? gAtrAvg[i] : 0.0;
   double regime = (avg>0.0) ? atr/avg : 0.0;

   long spr  = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   string tpStr = InpUsePartialTP
                  ? ("TP "+DoubleToString(InpRR1,1)+"/"+DoubleToString(InpRR2,1))
                  : ("RR "+DoubleToString(InpRR,2));

   int x=InpDashX, y=InpDashY, lh=InpDashFont+7, w=255;
   int lines=15;
   DashBg(x-6, y-6, w, lines*lh+10);

   int yy=y;
   DashLabel("t0", x, yy, "GoldScalperPro  v1.30", InpDashAccent, InpDashFont+1); yy+=lh+2;
   DashLabel("t1", x, yy, _Symbol+"  "+TFToStr(_Period)+"  ["+gSymClass+"]", InpDashText, InpDashFont); yy+=lh;
   DashLabel("t2", x, yy, "Bias:   "+bias, biasClr, InpDashFont); yy+=lh;
   DashLabel("t3", x, yy, "HTF "+TFToStr((InpHTF>_Period)?InpHTF:_Period)+": "+htfStr,
             InpDashText, InpDashFont); yy+=lh;
   DashLabel("t4", x, yy, sessStr, sess?clrLime:clrGray, InpDashFont); yy+=lh;
   DashLabel("t5", x, yy, "ATR: "+DoubleToString(atr/_Point,0)+" pts  (x"+DoubleToString(regime,2)+")",
             InpDashText, InpDashFont); yy+=lh;
   DashLabel("t6", x, yy, "Spread: "+IntegerToString(spr)+" pts   "+tpStr, InpDashText, InpDashFont); yy+=lh;
   DashLabel("t7", x, yy, "------- stats (hist) -------", InpDashAccent, InpDashFont); yy+=lh;
   DashLabel("t8", x, yy, "Signals:"+IntegerToString(gSigTotal)+
             "  (B"+IntegerToString((int)gBuyCnt)+"/S"+IntegerToString((int)gSellCnt)+")",
             InpDashText, InpDashFont); yy+=lh;
   DashLabel("t9", x, yy, "Win/Loss:"+IntegerToString(gWins)+"/"+IntegerToString(gLosses)+
             "  open "+IntegerToString(gOpen), InpDashText, InpDashFont); yy+=lh;
   color wrClr = (winrate>=60.0)?clrLime:((winrate>=50.0)?InpDashAccent:clrTomato);
   DashLabel("t10",x, yy, "Win-rate:"+DoubleToString(winrate,1)+"%", wrClr, InpDashFont+1); yy+=lh;
   DashLabel("t11",x, yy, "Profit f:"+DoubleToString(pf,2)+
             (InpUsePartialTP?("   TP2:"+IntegerToString(gTp2Hits)):""), InpDashText, InpDashFont); yy+=lh;
   DashLabel("t12",x, yy, "Expectancy:"+DoubleToString(expR,3)+" R", InpDashText, InpDashFont); yy+=lh;
   DashLabel("t13",x, yy, "----- best hours (raw) -----", InpDashAccent, InpDashFont); yy+=lh;
   DashLabel("t14",x, yy, InpShowBestHours?BestHoursStr():"off", clrAqua, InpDashFont);
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
