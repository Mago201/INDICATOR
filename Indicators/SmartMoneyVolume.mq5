//+------------------------------------------------------------------+
//|                                          SmartMoneyVolume.mq5    |
//|                Smart Money Concepts + Volume + MTF + Profile     |
//|                                            Copyright 2026 Mago201|
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.50"
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plots: стрелки над/под высоко-объёмными барами
#property indicator_label1  "HighVolUp"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrYellow
#property indicator_width1  2

#property indicator_label2  "HighVolDn"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrange
#property indicator_width2  2

//--- Plots: ENTRY SIGNAL стрелки (совпадение всех условий)
#property indicator_label3  "EntryUp"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  4

#property indicator_label4  "EntryDn"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  4

//+==================================================================+
//| ВХОДНЫЕ ПАРАМЕТРЫ                                                 |
//+==================================================================+
input group "=== Структура (Swing / BOS / CHoCH) ==="
input int      InpSwingLength      = 5;             // Длина свинга (баров слева/справа)
input bool     InpShowSwings       = true;          // Метки HH/HL/LH/LL
input bool     InpShowBOS          = true;          // Линии BOS
input bool     InpShowCHOCH        = true;          // Линии CHoCH
input color    InpBullColor        = clrLime;       // Цвет бычьих структур
input color    InpBearColor        = clrRed;        // Цвет медвежьих структур

input group "=== Order Blocks + Mitigation ==="
input bool     InpShowOB           = true;          // Показывать ордер-блоки
input int      InpOBMaxCount       = 5;             // Максимум активных OB на сторону
input color    InpBullOBColor      = clrSeaGreen;   // Цвет бычьего OB
input color    InpBearOBColor      = clrCrimson;    // Цвет медвежьего OB
input int      InpOBExtendBars     = 30;            // Длина OB вправо (в барах)
input bool     InpOBHideMitigated  = false;         // Скрывать сработавшие OB
input color    InpOBMitigatedClr   = clrDimGray;    // Цвет сработавшего OB
input bool     InpOBExtendOnTouch  = true;          // Обрезать OB по моменту касания
input bool     InpOBShowVolume     = true;          // Показывать макс. объём внутри OB
input color    InpOBVolTextColor   = clrWhite;      // Цвет текста объёма OB
input int      InpOBVolFontSize    = 8;             // Размер шрифта объёма OB

input group "=== Fair Value Gaps ==="
input bool     InpShowFVG          = true;          // Показывать FVG / имбалансы
input int      InpFVGMaxCount      = 10;            // Максимум активных FVG на сторону
input color    InpBullFVGColor     = clrDarkGreen;
input color    InpBearFVGColor     = clrDarkRed;
input int      InpFVGExtendBars    = 20;

input group "=== Liquidity Sweeps ==="
input bool     InpShowLiquidity    = true;
input color    InpLiquidityColor   = clrGold;

input group "=== Liquidity Levels (зоны ликвидности) ==="
input bool            InpLiqLevelsEnable  = true;            // Включить зоны ликвидности
input bool            InpLiqShowLines     = true;            // Линии ликвидности от свингов (BSL/SSL)
input color           InpLiqBuyColor      = clrDeepSkyBlue;  // Цвет BSL (над максимумами)
input color           InpLiqSellColor     = clrTomato;       // Цвет SSL (под минимумами)
input ENUM_LINE_STYLE InpLiqLineStyle     = STYLE_DOT;       // Стиль линий ликвидности
input int             InpLiqLineWidth     = 1;               // Толщина линий ликвидности
input int             InpLiqMaxPerSide    = 8;               // Макс. активных линий на сторону
input bool            InpLiqRemoveOnSweep = false;           // Удалять линию при снятии (иначе затемнять)
input color           InpLiqSweptColor    = clrDimGray;      // Цвет снятой ликвидности
input bool            InpLiqShowLabels    = true;            // Подписи у линий (BSL/SSL/EQH/EQL)
input bool            InpLiqExtendActive  = true;            // Тянуть активные линии вправо (ray)
input bool            InpLiqAlert         = false;           // Alert при снятии ликвидности (BSL/SSL)
input bool            InpLiqAlertPush     = false;           // + push-уведомление (SendNotification)

input bool            InpLiqShowEqual     = true;            // Equal Highs/Lows (EQH/EQL)
input color           InpLiqEqualColor    = clrGold;         // Цвет EQH/EQL
input double          InpLiqEqualTolATR   = 0.10;            // Допуск «равенства» (доли ATR)

input bool            InpLiqShowDaily     = true;            // Дневные уровни PDH/PDL и CDH/CDL
input color           InpLiqDailyColor    = clrMediumPurple; // Цвет дневных уровней

input bool            InpLiqShowSessions  = true;            // Сессионные H/L (ликвидность сессий)
input color           InpLiqAsiaColor     = C'90,90,170';    // Азия
input color           InpLiqLondonColor   = C'70,150,90';    // Лондон
input color           InpLiqNYColor       = C'170,120,60';   // Нью-Йорк
input int             InpLiqAsiaStart     = 0;               // Азия: старт (час сервера)
input int             InpLiqAsiaEnd       = 8;               // Азия: конец (час сервера)
input int             InpLiqLondonStart   = 8;               // Лондон: старт (час сервера)
input int             InpLiqLondonEnd     = 16;              // Лондон: конец (час сервера)
input int             InpLiqNYStart       = 13;              // Нью-Йорк: старт (час сервера)
input int             InpLiqNYEnd         = 21;              // Нью-Йорк: конец (час сервера)

input group "=== Подсветка непротестированных уровней ==="
input bool            InpHighlightUntested = false;          // Выделять свежие (непротестированные) зоны/уровни отдельным цветом
input color           InpUntestedColor     = clrAqua;        // Цвет непротестированных зон/уровней
input bool            InpUntestedApplyOB   = true;           // Применять к Order Blocks (свежий = ещё не сработал)
input bool            InpUntestedApplyLiq  = true;           // Применять к линиям ликвидности (свежий = ещё не снят)

input group "=== Анализ объёмов ==="
input bool     InpShowVolume       = true;          // Подсветка объёмных свечей
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK;
input int      InpVolumePeriod     = 20;
input double   InpVolumeMultiplier = 1.8;
input bool     InpShowVolText      = false;
input color    InpVolTextColor     = clrSilver;

input group "=== Delta / Cumulative Delta (footprint по тикам) ==="
input bool     InpDeltaEnable     = true;       // Включить расчёт дельты по тикам
input int      InpDeltaLookback   = 120;        // Сколько последних баров считать
input bool     InpDeltaShowBars   = false;      // Подписывать дельту под каждым баром
input bool     InpDeltaShowDiv    = true;       // Показывать дивергенции цена/CVD
input int      InpDeltaDivSwing   = 2;          // Длина фрактала для свингов дельты
input int      InpDeltaDivRecent  = 30;         // Окно «свежести» дивергенции (баров)
input color    InpDeltaBullColor  = clrLime;    // Цвет бычьей дельты/дивергенции
input color    InpDeltaBearColor  = clrRed;     // Цвет медвежьей дельты/дивергенции
input int      InpDeltaFontSize   = 7;          // Размер шрифта подписей дельты
input bool     InpDeltaAlertDiv   = false;      // Алерт при дивергенции CVD

input group "=== MTF (старший таймфрейм) ==="
input bool             InpMTFEnable     = true;          // Включить MTF
input ENUM_TIMEFRAMES  InpMTFPeriod     = PERIOD_H1;     // Старший ТФ для структуры
input int              InpMTFLookback   = 300;           // Сколько баров MTF анализировать
input bool             InpMTFShowSwings = true;          // Метки HH/HL на MTF
input bool             InpMTFShowBOS    = true;          // Линии BOS на MTF
input bool             InpMTFShowCHOCH  = true;          // Линии CHoCH на MTF
input bool             InpMTFShowOB     = true;          // Order Blocks на MTF
input color            InpMTFBullColor  = clrAqua;       // Цвет бычьих MTF структур
input color            InpMTFBearColor  = clrMagenta;    // Цвет медвежьих MTF структур
input color            InpMTFBullOBClr  = C'30,80,120';  // Бычий MTF OB
input color            InpMTFBearOBClr  = C'120,30,80';  // Медвежий MTF OB
input int              InpMTFLineWidth  = 2;             // Толщина линий MTF

input group "=== Dashboard ==="
input bool             InpDashEnable    = true;
input ENUM_BASE_CORNER InpDashCorner    = CORNER_RIGHT_UPPER;
input int              InpDashX         = 10;
input int              InpDashY         = 20;
input color            InpDashTextColor = clrWhite;
input color            InpDashBgColor   = C'30,30,40';
input color            InpDashAccent    = clrGold;
input int              InpDashFontSize  = 9;
input string           InpDashFont      = "Consolas";
input int              InpDashWidth     = 240;

input group "=== Volume Profile ==="
input bool             InpVPEnable      = true;
input ENUM_TIMEFRAMES  InpVPTimeframe   = PERIOD_CURRENT; // ТФ для расчёта VP
input int              InpVPLookback    = 200;            // Сколько баров для VP
input int              InpVPRows        = 50;             // Количество ценовых зон
input int              InpVPWidthPct    = 25;             // Ширина VP в % от видимой области
input color            InpVPColor       = C'70,70,120';
input color            InpVPPocColor    = clrGold;
input color            InpVPVaColor     = C'120,120,200';
input bool             InpVPShowPoc     = true;
input bool             InpVPShowVa      = true;
input double           InpVPValueArea   = 0.70;           // Доля объёма для Value Area (0.7 = 70%)
input bool             InpVPRightSide   = true;           // Гистограмма справа

input group "=== Entry signals (стрелки точки входа) ==="
input bool     InpEntryEnable        = true;        // Показывать стрелки точки входа
input bool     InpEntryNeedTrend     = true;        // Требовать совпадения с трендом текущ. ТФ
input bool     InpEntryNeedMTF       = false;       // Требовать совпадения с трендом MTF
input bool     InpEntryNeedOB        = true;        // Цена должна быть внутри активного OB
input bool     InpEntryNeedVolume    = true;        // Бар должен быть громким (того же цвета)
input bool     InpEntryNeedSweep     = false;       // Недавний sweep в обратную сторону
input bool     InpEntryNeedStruct    = false;       // Недавний BOS/CHoCH в нужную сторону
input int      InpEntryRecencyBars   = 5;           // Окно «недавности» (баров) для sweep/struct
input color    InpEntryUpColor       = clrLime;     // Цвет стрелки покупки
input color    InpEntryDnColor       = clrRed;      // Цвет стрелки продажи
input int      InpEntryUpArrow       = 233;         // Wingdings код стрелки вверх (233=▲)
input int      InpEntryDnArrow       = 234;         // Wingdings код стрелки вниз (234=▼)
input int      InpEntryArrowWidth    = 4;           // Толщина стрелки
input int      InpEntryArrowShift    = 30;          // Смещение в пикселях от свечи
input bool     InpEntryAlert         = false;       // Алерт при появлении entry-сигнала

input group "=== Entry filters (расширенные) ==="
input bool     InpEntryNeedPremDisc      = false;   // Требовать Premium/Discount (BUY в нижней половине, SELL в верхней)
input bool     InpEntryPremDiscMTF       = false;   // Брать диапазон с MTF, иначе с текущего ТФ
input double   InpEntryPremDiscMid       = 0.50;    // Граница (0.5 = середина диапазона)
input double   InpEntryPremDiscDelta     = 0.05;    // Буфер от середины (0..0.5)

input bool     InpEntryNeedStrongOB      = false;   // Требовать "сильный" OB (с FVG-импульсом сразу после)
input int      InpEntryOBImpulseMaxBars  = 6;       // Макс. баров после OB для поиска FVG-импульса

input bool     InpEntryNeedReject        = false;   // Требовать rejection-фитиль на баре сигнала
input bool     InpEntryNeedRR            = false;   // Жёсткий фильтр по RR (не давать сигнал, если ниже мин.)
input double   InpEntryMinRR             = 1.5;     // Минимальное R:R для сигнала
input double   InpEntrySLATRMult         = 0.30;    // Буфер SL за границу OB (доли ATR)
input int      InpEntryATRPeriod         = 14;      // Период ATR
input bool     InpEntryUseVPForTP        = true;    // Учитывать POC/VAH/VAL как кандидатов TP

input bool     InpEntryShowLevels        = true;    // Рисовать SL/TP1/TP2 у стрелки
input color    InpEntrySLColor           = clrCrimson;
input color    InpEntryTPColor           = clrSeaGreen;
input int      InpEntryLevelsBars        = 12;      // Длина пунктиров SL/TP вправо (баров)
input bool     InpEntryShowLabel         = true;    // Подпись у стрелки (score / RR)

input int      InpEntryCooldownBars      = 0;       // Cooldown между сигналами одного направления (0=выкл)
input double   InpEntryMinDistATR        = 0.0;     // Мин. дистанция от прошлого сигнала, в ATR (0=выкл)

input group "=== Entry: Liquidity grab → CHoCH ==="
input bool     InpEntryNeedGrabChoCH = false;      // Требовать паттерн: снятие ликвидности → CHoCH в обратную сторону
input int      InpEntryGrabMaxBars   = 8;          // Макс. баров между снятием ликвидности и CHoCH

input group "=== Entry: Delta (подтверждение объёмом) ==="
input bool     InpEntryNeedDelta     = false;      // Требовать подтверждение дельтой (BUY: Δ>0, SELL: Δ<0)

input group "=== Entry score (анти всё-или-ничего) ==="
input bool     InpEntryUseScore          = false;   // Score-режим вместо AND-фильтра
input int      InpEntryMinScore          = 6;       // Мин. сумма очков для сигнала
input int      InpEntryWeightTrend       = 2;       // Вес: совпадение с трендом ТФ
input int      InpEntryWeightMTF         = 2;       // Вес: совпадение с MTF
input int      InpEntryWeightOB          = 2;       // Вес: цена в активном OB
input int      InpEntryWeightStrongOB    = 2;       // Вес: OB сильный (displacement)
input int      InpEntryWeightVolume      = 1;       // Вес: бар громкий
input int      InpEntryWeightSweep       = 2;       // Вес: недавний sweep
input int      InpEntryWeightStruct      = 2;       // Вес: недавний BOS/CHoCH
input int      InpEntryWeightPremDisc    = 2;       // Вес: Premium/Discount ОК
input int      InpEntryWeightRR          = 1;       // Вес: RR >= MinRR
input int      InpEntryWeightVPCnflu     = 1;       // Вес: близость к POC/VAH/VAL
input int      InpEntryWeightReject      = 1;       // Вес: rejection-фитиль
input int      InpEntryWeightGrabChoCH   = 3;       // Вес: liquidity grab → CHoCH
input int      InpEntryWeightDelta       = 2;       // Вес: дельта подтверждает направление

input group "=== Производительность ==="
input int      InpHistoryBars      = 1500;        // Глубина истории для анализа (0 = вся; 0 НЕ рекомендую)
input bool     InpHeavyOnNewBarOnly= true;        // Тяжёлые задачи (mitigation/dashboard/VP) только на новом баре
input bool     InpProcessUnclosed  = false;       // Обрабатывать объёмы на текущем (незакрытом) баре

input group "=== Прочее ==="
input string   InpObjPrefix        = "SMV_";
input bool     InpAlertOnBOS       = false;
input bool     InpAlertOnSweep     = false;

//+==================================================================+
//| ТИПЫ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ                                      |
//+==================================================================+
double BufHighVolUp[];
double BufHighVolDn[];
double BufEntryUp[];
double BufEntryDn[];

struct SwingPoint
{
   datetime time;
   double   price;
   bool     valid;
};

struct SwingState
{
   SwingPoint lastH;
   SwingPoint lastL;
   SwingPoint prevH;
   SwingPoint prevL;
   int        trend;     // 1 bull, -1 bear, 0 flat
};

struct DrawCtx
{
   string          prefix;       // SMV_  или  SMV_mtf_
   color           bullClr;
   color           bearClr;
   color           obBullClr;
   color           obBearClr;
   int             lineWidth;
   bool            isMTF;
   bool            showSwings;
   bool            showBOS;
   bool            showCHOCH;
   bool            showOB;
   bool            showSweep;
   ENUM_TIMEFRAMES tf;
};

struct OBData
{
   string   name;
   datetime time;       // время бара-источника
   double   topPrice;
   double   botPrice;
   datetime extendTo;
   bool     bull;
   bool     mitigated;
   bool     mtf;
   bool     strong;     // OB после которого был FVG-импульс (displacement)
   long     maxVol;     // максимальный объём внутри зоны OB (OB-бар + импульс до слома)
   datetime checkedUpTo;  // время последнего проверенного бара (для инкремент. mitigation)
};

// Уровень ликвидности (резерв стопов): BSL над свинг-хаем, SSL под свинг-лоем
struct LiqLevel
{
   string   name;        // имя графического объекта линии
   datetime time;        // время свинга-источника
   double   price;       // цена уровня
   bool     buySide;     // true = BSL (над хаем), false = SSL (под лоем)
   bool     swept;       // ликвидность снята
   datetime sweptTime;   // время снятия
   bool     equal;       // входит в кластер EQH/EQL
   datetime checkedUpTo; // время последнего проверенного бара (инкремент. проверка снятия)
};

struct Counters
{
   int bosBull, bosBear;
   int chochBull, chochBear;
   int sweepBull, sweepBear;
   int obBullActive, obBullMit;
   int obBearActive, obBearMit;
   int fvgBull, fvgBear;
   int hivolUp, hivolDn;
   int swingsHH, swingsHL, swingsLH, swingsLL;
   int mtfBosBull, mtfBosBear;
   int mtfChochBull, mtfChochBear;
   int entryUp, entryDn;
   int obStrongBull, obStrongBear;
   int eqh, eql;           // обнаружено кластеров Equal Highs / Equal Lows
   int liqSwept;           // снято линий ликвидности (BSL/SSL)
   int dltDivBull, dltDivBear; // обнаружено бычьих/медвежьих дивергенций CVD
};

SwingState g_state;
SwingState g_mtfState;
datetime   g_mtfLastTime  = 0;
datetime   g_lastVPTime   = 0;
ENUM_TIMEFRAMES g_lastVPPeriod = PERIOD_CURRENT;
OBData     g_obs[];
LiqLevel   g_liq[];        // активные/снятые уровни ликвидности (текущий ТФ)
Counters   g_cnt;
DrawCtx    g_ctx;
DrawCtx    g_ctxMTF;
datetime   g_lastBarSeen  = 0;
bool       g_dashCreated  = false;
bool       g_liqCleared   = false;  // объекты ликвидности очищены (когда модуль выключен)
// Время последних структурных событий (для проверки «недавности» в Entry)
datetime   g_lastSweepHighTime = 0;  // была снята ликвидность с верха
datetime   g_lastSweepLowTime  = 0;  // была снята ликвидность с низа
datetime   g_lastBullStructTime = 0; // последний BOS/CHoCH вверх
datetime   g_lastBearStructTime = 0; // последний BOS/CHoCH вниз
datetime   g_lastBullChochTime  = 0; // последний CHoCH вверх (для паттерна grab→CHoCH)
datetime   g_lastBearChochTime  = 0; // последний CHoCH вниз (для паттерна grab→CHoCH)

// ATR + VP-уровни для расширенного Entry-сценария
int        g_atrHandle    = INVALID_HANDLE;
double     g_pocPrice     = 0.0;
double     g_vahPrice     = 0.0;
double     g_valPrice     = 0.0;
bool       g_vpReady      = false;

// Антиклустеринг / cooldown
datetime   g_lastEntryUpTime  = 0;
datetime   g_lastEntryDnTime  = 0;
double     g_lastEntryUpPrice = 0.0;
double     g_lastEntryDnPrice = 0.0;

// Delta / Cumulative Delta (footprint по тикам)
datetime   g_dltTime[];        // время бара (окно последних N закрытых баров, старые->новые)
double     g_dltHigh[];        // High бара (для поиска свингов дивергенции)
double     g_dltLow[];         // Low бара
double     g_dltDelta[];       // дельта бара (buyVol - sellVol)
double     g_dltCVD[];         // кумулятивная дельта внутри окна
double     g_dltCurDelta = 0.0;// дельта текущего (формирующегося) бара
double     g_dltCVDLast  = 0.0;// последнее значение CVD
int        g_dltDivState = 0;  // 0 нет, 1 бычья дивергенция, -1 медвежья
datetime   g_dltDivTime  = 0;  // время последней нарисованной дивергенции
bool       g_dltCleared  = false;

//+==================================================================+
//| OnInit / OnDeinit                                                 |
//+==================================================================+
int OnInit()
{
   SetIndexBuffer(0, BufHighVolUp, INDICATOR_DATA);
   SetIndexBuffer(1, BufHighVolDn, INDICATOR_DATA);
   SetIndexBuffer(2, BufEntryUp,   INDICATOR_DATA);
   SetIndexBuffer(3, BufEntryDn,   INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetDouble (0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -10);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT,  10);

   //--- Entry signal arrows
   PlotIndexSetInteger(2, PLOT_ARROW, InpEntryUpArrow);
   PlotIndexSetInteger(3, PLOT_ARROW, InpEntryDnArrow);
   PlotIndexSetDouble (2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT,  InpEntryArrowShift);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, -InpEntryArrowShift);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, InpEntryUpColor);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 0, InpEntryDnColor);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpEntryArrowWidth);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpEntryArrowWidth);

   ArraySetAsSeries(BufHighVolUp, false);
   ArraySetAsSeries(BufHighVolDn, false);
   ArraySetAsSeries(BufEntryUp,   false);
   ArraySetAsSeries(BufEntryDn,   false);

   IndicatorSetString(INDICATOR_SHORTNAME, "SmartMoney+Volume MTF");

   InitContexts();
   ResetState(g_state);
   ResetState(g_mtfState);
   ResetCounters();
   ArrayResize(g_obs, 0);
   ArrayResize(g_liq, 0);
   g_mtfLastTime = 0;
   g_lastVPTime  = 0;
   g_lastVPPeriod = PERIOD_CURRENT;
   g_lastSweepHighTime = 0;
   g_lastSweepLowTime  = 0;
   g_lastBullStructTime = 0;
   g_lastBearStructTime = 0;
   g_lastBullChochTime  = 0;
   g_lastBearChochTime  = 0;
   g_lastEntryUpTime  = 0;
   g_lastEntryDnTime  = 0;
   g_lastEntryUpPrice = 0.0;
   g_lastEntryDnPrice = 0.0;
   g_pocPrice = g_vahPrice = g_valPrice = 0.0;
   g_vpReady  = false;
   ResetDelta();

   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   g_atrHandle = iATR(_Symbol, _Period, MathMax(2, InpEntryATRPeriod));

   ClearAllObjects();
   if(InpDashEnable) DashboardCreate();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   ClearAllObjects();
}

void InitContexts()
{
   // Контекст для текущего ТФ
   g_ctx.prefix     = InpObjPrefix;
   g_ctx.bullClr    = InpBullColor;
   g_ctx.bearClr    = InpBearColor;
   g_ctx.obBullClr  = InpBullOBColor;
   g_ctx.obBearClr  = InpBearOBColor;
   g_ctx.lineWidth  = 1;
   g_ctx.isMTF      = false;
   g_ctx.showSwings = InpShowSwings;
   g_ctx.showBOS    = InpShowBOS;
   g_ctx.showCHOCH  = InpShowCHOCH;
   g_ctx.showOB     = InpShowOB;
   g_ctx.showSweep  = InpShowLiquidity;
   g_ctx.tf         = _Period;

   // Контекст для MTF
   g_ctxMTF.prefix     = InpObjPrefix + "mtf_";
   g_ctxMTF.bullClr    = InpMTFBullColor;
   g_ctxMTF.bearClr    = InpMTFBearColor;
   g_ctxMTF.obBullClr  = InpMTFBullOBClr;
   g_ctxMTF.obBearClr  = InpMTFBearOBClr;
   g_ctxMTF.lineWidth  = InpMTFLineWidth;
   g_ctxMTF.isMTF      = true;
   g_ctxMTF.showSwings = InpMTFShowSwings;
   g_ctxMTF.showBOS    = InpMTFShowBOS;
   g_ctxMTF.showCHOCH  = InpMTFShowCHOCH;
   g_ctxMTF.showOB     = InpMTFShowOB;
   g_ctxMTF.showSweep  = false;
   g_ctxMTF.tf         = InpMTFPeriod;
}

void ResetState(SwingState &s)
{
   s.lastH.valid = false;
   s.lastL.valid = false;
   s.prevH.valid = false;
   s.prevL.valid = false;
   s.trend = 0;
}

void ResetCounters()
{
   ZeroMemory(g_cnt);
}

void ResetDelta()
{
   ArrayResize(g_dltTime,  0);
   ArrayResize(g_dltHigh,  0);
   ArrayResize(g_dltLow,   0);
   ArrayResize(g_dltDelta, 0);
   ArrayResize(g_dltCVD,   0);
   g_dltCurDelta = 0.0;
   g_dltCVDLast  = 0.0;
   g_dltDivState = 0;
   g_dltDivTime  = 0;
   g_dltCleared  = false;
}

void ClearAllObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, InpObjPrefix) == 0)
         ObjectDelete(0, name);
   }
}

//+==================================================================+
//| Главный расчёт                                                    |
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
   if(rates_total < InpSwingLength * 2 + 5) return(0);

   // Признак нового бара по текущему ТФ
   bool isNewBar = (time[rates_total - 1] != g_lastBarSeen);
   g_lastBarSeen = time[rates_total - 1];

   bool firstScan = false;
   int start;
   if(prev_calculated <= 0)
   {
      ArrayInitialize(BufHighVolUp, EMPTY_VALUE);
      ArrayInitialize(BufHighVolDn, EMPTY_VALUE);
      ArrayInitialize(BufEntryUp,   EMPTY_VALUE);
      ArrayInitialize(BufEntryDn,   EMPTY_VALUE);
      ResetState(g_state);
      ResetCounters();
      ArrayResize(g_obs, 0);
      ArrayResize(g_liq, 0);
      g_lastSweepHighTime = 0;
      g_lastSweepLowTime  = 0;
      g_lastBullStructTime = 0;
      g_lastBearStructTime = 0;
      g_lastBullChochTime  = 0;
      g_lastBearChochTime  = 0;
      g_lastEntryUpTime  = 0;
      g_lastEntryDnTime  = 0;
      g_lastEntryUpPrice = 0.0;
      g_lastEntryDnPrice = 0.0;
      g_pocPrice = g_vahPrice = g_valPrice = 0.0;
      g_vpReady  = false;
      ResetDelta();
      ClearAllObjects();
      g_dashCreated = false;
      if(InpDashEnable) { DashboardCreate(); DashboardLayout(); g_dashCreated = true; }
      start = InpSwingLength;
      firstScan = true;
      isNewBar = true;
   }
   else
   {
      start = prev_calculated - 1;
      if(start < InpSwingLength) start = InpSwingLength;
   }

   // Лимит глубины истории — не сканируем всё за всё время
   if(firstScan && InpHistoryBars > 0)
   {
      int desiredStart = rates_total - InpHistoryBars;
      if(desiredStart > start) start = desiredStart;
      if(start < InpSwingLength) start = InpSwingLength;
   }

   int last_confirmable = rates_total - InpSwingLength - 1;

   // VP заранее на firstScan: DetectEntry в исторической прокрутке
   // должен иметь доступ к POC/VAH/VAL для confluence-расчёта
   if(firstScan && InpVPEnable)
   {
      BuildVolumeProfile();
      g_lastVPTime   = time[rates_total - 1];
      g_lastVPPeriod = InpVPTimeframe;
   }

   //--- Основной проход по текущему ТФ
   for(int i = start; i <= last_confirmable; ++i)
   {
      ProcessVolume(i, rates_total, time, open, close, high, low, tick_volume, volume);
      if(InpShowFVG && i >= 2)
         DetectFVG(i, time, high, low);
      DetectSwingGeneric(i, InpSwingLength,
                         time, open, high, low, close, tick_volume, volume,
                         g_state, g_ctx, _Period, InpOBExtendBars, InpOBMaxCount);
      if(InpEntryEnable)
         DetectEntry(i, rates_total, time, open, high, low, close);
   }

   //--- Незакрытые/неподтверждённые бары: только громкие свечи (по желанию)
   for(int i = last_confirmable + 1; i < rates_total; ++i)
   {
      BufHighVolUp[i] = EMPTY_VALUE;
      BufHighVolDn[i] = EMPTY_VALUE;
      BufEntryUp[i]   = EMPTY_VALUE;
      BufEntryDn[i]   = EMPTY_VALUE;
      if(InpProcessUnclosed)
         ProcessVolume(i, rates_total, time, open, close, high, low, tick_volume, volume);
   }

   //--- Тяжёлые задачи только при необходимости
   bool runHeavy = (!InpHeavyOnNewBarOnly) || isNewBar || firstScan;

   if(runHeavy && InpShowOB)
      UpdateOBMitigation(time, high, low, rates_total);

   //--- Liquidity Levels: снятие линий + дневные/сессионные уровни
   if(InpLiqLevelsEnable)
   {
      g_liqCleared = false;
      if(InpLiqShowLines)
      {
         UpdateLiquidityTaken(time, high, low, rates_total);
         PruneLiquidity();
      }
      if(runHeavy)
         UpdateSessionLevels();
   }
   else if(!g_liqCleared)
   {
      ClearLiquidityObjects();
      ClearSessionObjects();
      g_liqCleared = true;
   }

   //--- MTF: пересчитываем только при появлении нового бара старшего ТФ
   if(InpMTFEnable)
   {
      datetime curMTF = iTime(_Symbol, InpMTFPeriod, 0);
      if(curMTF != 0 && curMTF != g_mtfLastTime)
      {
         ProcessMTF();
         g_mtfLastTime = curMTF;
      }
   }

   //--- Volume Profile: на новом баре или при смене параметров
   datetime nowBar = time[rates_total - 1];
   if(InpVPEnable && runHeavy && (nowBar != g_lastVPTime || InpVPTimeframe != g_lastVPPeriod))
   {
      BuildVolumeProfile();
      g_lastVPTime   = nowBar;
      g_lastVPPeriod = InpVPTimeframe;
   }
   else if(!InpVPEnable && g_lastVPTime != 0)
   {
      ClearVPObjects();
      g_lastVPTime = 0;
   }

   //--- Delta / CVD: пересчёт по тикам (на новом баре)
   if(runHeavy)
      UpdateDelta(time, high, low, rates_total);

   //--- Dashboard: пересоздаём только при включении/первом запуске,
   //--- иначе обновляем текст метк (быстро)
   if(InpDashEnable)
   {
      if(!g_dashCreated)
      {
         DashboardCreate();
         DashboardLayout();
         g_dashCreated = true;
      }
      if(runHeavy) DashboardUpdate();
   }
   else if(g_dashCreated)
   {
      ClearDashboard();
      g_dashCreated = false;
   }

   return(rates_total);
}

//+==================================================================+
//| Анализ объёмов                                                    |
//+==================================================================+
long GetVolume(int idx, const long &tick_vol[], const long &real_vol[])
{
   if(InpVolumeType == VOLUME_REAL) return real_vol[idx];
   return tick_vol[idx];
}

void ProcessVolume(int i, int rates_total,
                   const datetime &time[],
                   const double &open[], const double &close[],
                   const double &high[], const double &low[],
                   const long &tick_vol[], const long &real_vol[])
{
   BufHighVolUp[i] = EMPTY_VALUE;
   BufHighVolDn[i] = EMPTY_VALUE;
   if(!InpShowVolume) return;
   if(i < InpVolumePeriod) return;

   double sum = 0.0;
   for(int k = 1; k <= InpVolumePeriod; ++k)
      sum += (double)GetVolume(i - k, tick_vol, real_vol);
   double avg = sum / InpVolumePeriod;
   if(avg <= 0.0) return;

   long curVol = GetVolume(i, tick_vol, real_vol);
   if((double)curVol < avg * InpVolumeMultiplier) return;

   bool bullish = close[i] >= open[i];
   if(bullish)
   {
      BufHighVolUp[i] = high[i];
      g_cnt.hivolUp++;
   }
   else
   {
      BufHighVolDn[i] = low[i];
      g_cnt.hivolDn++;
   }

   if(InpShowVolText)
   {
      string name = InpObjPrefix + "vol_" + IntegerToString((long)time[i]);
      double y = bullish ? high[i] : low[i];
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TEXT, 0, time[i], y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpVolTextColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, bullish ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetString (0, name, OBJPROP_TEXT, FormatVolume(curVol));
      ObjectSetInteger(0, name, OBJPROP_TIME, time[i]);
      ObjectSetDouble (0, name, OBJPROP_PRICE, y);
   }
}

string FormatVolume(long v)
{
   if(v >= 1000000) return DoubleToString(v / 1000000.0, 2) + "M";
   if(v >= 1000)    return DoubleToString(v / 1000.0, 1)    + "K";
   return IntegerToString(v);
}

//+==================================================================+
//| FVG                                                               |
//+==================================================================+
void DetectFVG(int i, const datetime &time[], const double &high[], const double &low[])
{
   if(low[i] > high[i-2])
   {
      DrawFVG(time[i-2], high[i-2], time[i], low[i], true);
      LimitObjectsByTag("fvgB_", InpFVGMaxCount, "");
      g_cnt.fvgBull++;
   }
   else if(high[i] < low[i-2])
   {
      DrawFVG(time[i-2], low[i-2], time[i], high[i], false);
      LimitObjectsByTag("fvgS_", InpFVGMaxCount, "");
      g_cnt.fvgBear++;
   }
}

void DrawFVG(datetime t1, double p1, datetime t2, double p2, bool bull)
{
   string tag  = bull ? "fvgB_" : "fvgS_";
   string name = InpObjPrefix + tag + IntegerToString((long)t2);
   datetime tEnd = t2 + (datetime)(PeriodSeconds() * InpFVGExtendBars);
   color clr = bull ? InpBullFVGColor : InpBearFVGColor;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, tEnd, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, tEnd);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL,  true);
   ObjectSetInteger(0, name, OBJPROP_BACK,  true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

//+==================================================================+
//| LimitObjectsByTag - оставить только N последних                   |
//+==================================================================+
void LimitObjectsByTag(string tag, int maxCount, string ctxPrefixOverride)
{
   if(maxCount <= 0) return;
   string prefix = (StringLen(ctxPrefixOverride) > 0 ? ctxPrefixOverride : InpObjPrefix) + tag;

   string  names[];
   datetime times[];
   int total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; ++i)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, prefix) != 0) continue;
      datetime t = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
      int sz = ArraySize(names);
      ArrayResize(names, sz + 1);
      ArrayResize(times, sz + 1);
      names[sz] = nm;
      times[sz] = t;
   }

   int cnt = ArraySize(names);
   if(cnt <= maxCount) return;

   for(int a = 0; a < cnt - 1; ++a)
      for(int b = a + 1; b < cnt; ++b)
         if(times[a] > times[b])
         {
            datetime tt = times[a]; times[a] = times[b]; times[b] = tt;
            string   ss = names[a]; names[a] = names[b]; names[b] = ss;
         }

   int toDelete = cnt - maxCount;
   for(int x = 0; x < toDelete; ++x)
   {
      RemoveOBFromArray(names[x]);
      ObjectDelete(0, names[x]);
      ObjectDelete(0, names[x] + "_v");   // подпись объёма OB
   }
}

//+==================================================================+
//| Универсальный детектор свингов и BOS/CHoCH                        |
//+==================================================================+
void DetectSwingGeneric(int i, int swingLen,
                        const datetime &time[],
                        const double   &open[],
                        const double   &high[],
                        const double   &low[],
                        const double   &close[],
                        const long     &tickv[],
                        const long     &realv[],
                        SwingState     &state,
                        DrawCtx        &ctx,
                        ENUM_TIMEFRAMES tf,
                        int            obExtendBars,
                        int            obMaxCount)
{
   int L = swingLen;
   int total = ArraySize(time);
   if(i < L || i + L >= total) return;

   bool isHigh = true, isLow = true;
   for(int k = 1; k <= L; ++k)
   {
      if(high[i] <= high[i-k] || high[i] <= high[i+k]) isHigh = false;
      if(low[i]  >= low[i-k]  || low[i]  >= low[i+k])  isLow  = false;
      if(!isHigh && !isLow) break;
   }

   if(isHigh) HandleSwingHigh(i, time, open, high, low, close, tickv, realv,
                              state, ctx, tf, obExtendBars, obMaxCount);
   if(isLow ) HandleSwingLow (i, time, open, high, low, close, tickv, realv,
                              state, ctx, tf, obExtendBars, obMaxCount);
}

void HandleSwingHigh(int i, const datetime &time[],
                     const double &open[], const double &high[],
                     const double &low[],  const double &close[],
                     const long &tickv[], const long &realv[],
                     SwingState &state, DrawCtx &ctx,
                     ENUM_TIMEFRAMES tf, int obExtendBars, int obMaxCount)
{
   bool isHH = state.lastH.valid && high[i] > state.lastH.price;
   string label = isHH ? "HH" : "LH";
   if(ctx.showSwings)
      DrawSwingLabel(time[i], high[i], label, true, ctx);
   if(!ctx.isMTF) { if(isHH) g_cnt.swingsHH++; else g_cnt.swingsLH++; }

   // Регистрируем buy-side ликвидность (резерв стопов над свинг-хаем)
   if(!ctx.isMTF && InpLiqLevelsEnable && InpLiqShowLines)
      RegisterLiquidity(i, time, high[i], true);

   // BOS bull
   if(state.lastH.valid && ctx.showBOS && state.trend != -1 && high[i] > state.lastH.price)
   {
      DrawStructureLine(state.lastH.time, state.lastH.price,
                        time[i], state.lastH.price, "BOS", true, ctx);
      state.trend = 1;
      AlertStructure("BOS bull", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfBosBull++; else { g_cnt.bosBull++; g_lastBullStructTime = time[i]; }

      if(ctx.showOB)
         TryDrawOB(i, true, time, open, high, low, close, tickv, realv, ctx, tf, obExtendBars, obMaxCount);
   }
   // CHoCH bull (разворот из медвежьего тренда)
   else if(state.lastH.valid && ctx.showCHOCH && state.trend == -1 && high[i] > state.lastH.price)
   {
      DrawStructureLine(state.lastH.time, state.lastH.price,
                        time[i], state.lastH.price, "CHoCH", true, ctx);
      state.trend = 1;
      AlertStructure("CHoCH bull", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfChochBull++; else { g_cnt.chochBull++; g_lastBullStructTime = time[i]; g_lastBullChochTime = time[i]; }

      if(ctx.showOB)
         TryDrawOB(i, true, time, open, high, low, close, tickv, realv, ctx, tf, obExtendBars, obMaxCount);
   }

   // Liquidity sweep — только для текущего ТФ
   if(!ctx.isMTF && ctx.showSweep && state.lastH.valid &&
      high[i] > state.lastH.price && close[i] < state.lastH.price)
   {
      DrawSweep(time[i], high[i], true);
      AlertSweep("Sweep high", time[i]);
      g_cnt.sweepBull++;
      g_lastSweepHighTime = time[i];
   }

   state.prevH = state.lastH;
   state.lastH.time  = time[i];
   state.lastH.price = high[i];
   state.lastH.valid = true;
}

void HandleSwingLow(int i, const datetime &time[],
                    const double &open[], const double &high[],
                    const double &low[],  const double &close[],
                    const long &tickv[], const long &realv[],
                    SwingState &state, DrawCtx &ctx,
                    ENUM_TIMEFRAMES tf, int obExtendBars, int obMaxCount)
{
   bool isLL = state.lastL.valid && low[i] < state.lastL.price;
   string label = isLL ? "LL" : "HL";
   if(ctx.showSwings)
      DrawSwingLabel(time[i], low[i], label, false, ctx);
   if(!ctx.isMTF) { if(isLL) g_cnt.swingsLL++; else g_cnt.swingsHL++; }

   // Регистрируем sell-side ликвидность (резерв стопов под свинг-лоем)
   if(!ctx.isMTF && InpLiqLevelsEnable && InpLiqShowLines)
      RegisterLiquidity(i, time, low[i], false);

   // BOS bear
   if(state.lastL.valid && ctx.showBOS && state.trend != 1 && low[i] < state.lastL.price)
   {
      DrawStructureLine(state.lastL.time, state.lastL.price,
                        time[i], state.lastL.price, "BOS", false, ctx);
      state.trend = -1;
      AlertStructure("BOS bear", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfBosBear++; else { g_cnt.bosBear++; g_lastBearStructTime = time[i]; }

      if(ctx.showOB)
         TryDrawOB(i, false, time, open, high, low, close, tickv, realv, ctx, tf, obExtendBars, obMaxCount);
   }
   // CHoCH bear
   else if(state.lastL.valid && ctx.showCHOCH && state.trend == 1 && low[i] < state.lastL.price)
   {
      DrawStructureLine(state.lastL.time, state.lastL.price,
                        time[i], state.lastL.price, "CHoCH", false, ctx);
      state.trend = -1;
      AlertStructure("CHoCH bear", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfChochBear++; else { g_cnt.chochBear++; g_lastBearStructTime = time[i]; g_lastBearChochTime = time[i]; }

      if(ctx.showOB)
         TryDrawOB(i, false, time, open, high, low, close, tickv, realv, ctx, tf, obExtendBars, obMaxCount);
   }

   if(!ctx.isMTF && ctx.showSweep && state.lastL.valid &&
      low[i] < state.lastL.price && close[i] > state.lastL.price)
   {
      DrawSweep(time[i], low[i], false);
      AlertSweep("Sweep low", time[i]);
      g_cnt.sweepBear++;
      g_lastSweepLowTime = time[i];
   }

   state.prevL = state.lastL;
   state.lastL.time  = time[i];
   state.lastL.price = low[i];
   state.lastL.valid = true;
}

//+==================================================================+
//| Drawing helpers                                                   |
//+==================================================================+
void DrawSwingLabel(datetime t, double price, string text, bool isHigh, DrawCtx &ctx)
{
   string name = ctx.prefix + "sw_" + IntegerToString((long)t);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,  t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, price);
   ObjectSetString (0, name, OBJPROP_TEXT, ctx.isMTF ? (text + "·" + EnumToString(ctx.tf)) : text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, isHigh ? ctx.bearClr : ctx.bullClr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, ctx.isMTF ? 10 : 9);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
}

void DrawStructureLine(datetime t1, double p1, datetime t2, double p2,
                       string text, bool bull, DrawCtx &ctx)
{
   string tag  = (text == "BOS") ? "bos_" : "choch_";
   string name = ctx.prefix + tag + IntegerToString((long)t2);
   color  clr  = bull ? ctx.bullClr : ctx.bearClr;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, (text == "CHoCH") ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, ctx.lineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);

   string lbl = name + "_lbl";
   double   mid = (p1 + p2) / 2.0;
   datetime tm  = t1 + (t2 - t1) / 2;
   if(ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_TEXT, 0, tm, mid);
   ObjectSetInteger(0, lbl, OBJPROP_TIME,  tm);
   ObjectSetDouble (0, lbl, OBJPROP_PRICE, mid);
   ObjectSetString (0, lbl, OBJPROP_TEXT, ctx.isMTF ? (text + "·" + EnumToString(ctx.tf)) : text);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, ctx.isMTF ? 9 : 8);
}

void DrawSweep(datetime t, double price, bool isHigh)
{
   string name = InpObjPrefix + "sweep_" + IntegerToString((long)t);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isHigh ? 218 : 217);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpLiquidityColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_TIME,  t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isHigh ? ANCHOR_BOTTOM : ANCHOR_TOP);
}

//+==================================================================+
//| LIQUIDITY LEVELS                                                   |
//|  • Линии ликвидности от свингов (BSL над хаями / SSL под лоями)    |
//|  • Авто-снятие (удаление или затемнение) при пробое уровня         |
//|  • Equal Highs / Equal Lows (EQH / EQL)                            |
//|  • Дневные (PDH/PDL/CDH/CDL) и сессионные (Asia/London/NY) уровни  |
//+==================================================================+

// Регистрация уровня ликвидности на подтверждённом свинге
void RegisterLiquidity(int i, const datetime &time[], double price, bool buySide)
{
   int rt = ArraySize(time);
   datetime t = time[i];

   // Не дублируем уровень с тем же временем/стороной
   for(int k = 0; k < ArraySize(g_liq); ++k)
      if(g_liq[k].time == t && g_liq[k].buySide == buySide)
         return;

   string side = buySide ? "B" : "S";
   string name = InpObjPrefix + "liql_" + side + "_" + IntegerToString((long)t);

   int sz = ArraySize(g_liq);
   ArrayResize(g_liq, sz + 1);
   g_liq[sz].name        = name;
   g_liq[sz].time        = t;
   g_liq[sz].price       = price;
   g_liq[sz].buySide     = buySide;
   g_liq[sz].swept       = false;
   g_liq[sz].sweptTime   = 0;
   g_liq[sz].equal       = false;
   g_liq[sz].checkedUpTo = t;

   DrawLiqLine(sz);

   // EQH/EQL: близкий по цене активный уровень той же стороны
   if(InpLiqShowEqual)
      DetectEqualLevels(sz, rt, i);

   // Ограничение количества активных линий на сторону
   LimitLiquidity(buySide);
}

// Отрисовка/обновление линии ликвидности
void DrawLiqLine(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_liq)) return;
   datetime t1   = g_liq[idx].time;
   double   p    = g_liq[idx].price;
   bool     buy  = g_liq[idx].buySide;
   string   name = g_liq[idx].name;

   datetime t2 = t1 + (datetime)(PeriodSeconds() * 500); // запас; ray дотянет вправо
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p, t2, p);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p);
   color liqClr = buy ? InpLiqBuyColor : InpLiqSellColor;
   if(InpHighlightUntested && InpUntestedApplyLiq && !g_liq[idx].swept)
      liqClr = InpUntestedColor;   // свежая (непротестированная) ликвидность
   ObjectSetInteger(0, name, OBJPROP_COLOR, liqClr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, InpLiqLineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLiqLineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, InpLiqExtendActive);
   ObjectSetInteger(0, name, OBJPROP_BACK,  true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   if(InpLiqShowLabels)
      DrawLiqLabel(name + "_lbl", t1, p, buy ? "BSL" : "SSL",
                   buy ? InpLiqBuyColor : InpLiqSellColor, buy);
}

void DrawLiqLabel(string name, datetime t, double price, string text, color clr, bool above)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,  t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, price);
   ObjectSetString (0, name, OBJPROP_TEXT,  " " + text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, above ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

// EQH/EQL: соединяем близкие по цене экстремумы одной стороны
void DetectEqualLevels(int newIdx, int rates_total, int barIdx)
{
   double atr = GetATR(rates_total, barIdx);
   double tol = (atr > 0.0) ? atr * InpLiqEqualTolATR : 0.0;
   if(tol <= 0.0) tol = _Point * 20.0; // запасной допуск

   bool   buy = g_liq[newIdx].buySide;
   double p   = g_liq[newIdx].price;

   int    bestJ    = -1;
   double bestDiff = tol;
   for(int j = 0; j < ArraySize(g_liq); ++j)
   {
      if(j == newIdx)              continue;
      if(g_liq[j].buySide != buy)  continue;
      if(g_liq[j].swept)           continue;
      double diff = MathAbs(g_liq[j].price - p);
      if(diff <= bestDiff) { bestDiff = diff; bestJ = j; }
   }
   if(bestJ < 0) return;

   g_liq[newIdx].equal = true;
   g_liq[bestJ].equal  = true;

   double pe   = (g_liq[newIdx].price + g_liq[bestJ].price) * 0.5;
   string tag  = buy ? "EQH" : "EQL";
   string name = InpObjPrefix + "liqe_" + (buy ? "H_" : "L_") + IntegerToString((long)g_liq[newIdx].time);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, g_liq[bestJ].time, pe, g_liq[newIdx].time, pe);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, g_liq[bestJ].time);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, pe);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, g_liq[newIdx].time);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, pe);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpLiqEqualColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_BACK,  true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   if(buy) g_cnt.eqh++; else g_cnt.eql++;

   if(InpLiqShowLabels)
      DrawLiqLabel(name + "_lbl", g_liq[newIdx].time, pe, tag, InpLiqEqualColor, buy);
}

// Оставляем не более InpLiqMaxPerSide активных линий на сторону (старые удаляем)
void LimitLiquidity(bool buySide)
{
   if(InpLiqMaxPerSide <= 0) return;

   int      idxs[];
   datetime tms[];
   for(int i = 0; i < ArraySize(g_liq); ++i)
   {
      if(g_liq[i].buySide != buySide) continue;
      if(g_liq[i].swept)              continue;
      int s = ArraySize(idxs);
      ArrayResize(idxs, s + 1);
      ArrayResize(tms,  s + 1);
      idxs[s] = i;
      tms[s]  = g_liq[i].time;
   }
   int cnt = ArraySize(idxs);
   if(cnt <= InpLiqMaxPerSide) return;

   for(int a = 0; a < cnt - 1; ++a)
      for(int b = a + 1; b < cnt; ++b)
         if(tms[a] > tms[b])
         {
            datetime tt = tms[a]; tms[a] = tms[b]; tms[b] = tt;
            int      ii = idxs[a]; idxs[a] = idxs[b]; idxs[b] = ii;
         }

   int toDelete = cnt - InpLiqMaxPerSide;
   string delNames[];
   for(int x = 0; x < toDelete; ++x)
   {
      int s = ArraySize(delNames);
      ArrayResize(delNames, s + 1);
      delNames[s] = g_liq[idxs[x]].name;
   }
   for(int x = 0; x < ArraySize(delNames); ++x)
      RemoveLiqByName(delNames[x]);
}

void RemoveLiqByName(string name)
{
   int sz = ArraySize(g_liq);
   for(int i = 0; i < sz; ++i)
   {
      if(g_liq[i].name == name)
      {
         ObjectDelete(0, g_liq[i].name);
         ObjectDelete(0, g_liq[i].name + "_lbl");
         for(int j = i; j < sz - 1; ++j) g_liq[j] = g_liq[j + 1];
         ArrayResize(g_liq, sz - 1);
         return;
      }
   }
}

// Снятие ликвидности: цена прошла сквозь уровень (инкрементально, как OB mitigation)
void UpdateLiquidityTaken(const datetime &time[], const double &high[],
                          const double &low[], int rates_total)
{
   datetime latestBar = time[rates_total - 1];
   for(int idx = 0; idx < ArraySize(g_liq); ++idx)
   {
      if(g_liq[idx].swept) continue;
      if(g_liq[idx].checkedUpTo >= latestBar) continue;

      datetime sinceTime = (g_liq[idx].checkedUpTo > g_liq[idx].time)
                              ? g_liq[idx].checkedUpTo
                              : g_liq[idx].time;
      int startBar = FindBarByTime(time, rates_total, sinceTime);
      if(startBar < 0) startBar = 0;
      startBar++;
      if(startBar < 1) startBar = 1;

      datetime takenTime = 0;
      for(int b = startBar; b < rates_total; ++b)
      {
         if(g_liq[idx].buySide)
         {
            if(high[b] > g_liq[idx].price) { takenTime = time[b]; break; }
         }
         else
         {
            if(low[b] < g_liq[idx].price)  { takenTime = time[b]; break; }
         }
      }
      if(takenTime != 0)
         MarkLiqSwept(idx, takenTime);
      else
         g_liq[idx].checkedUpTo = latestBar;
   }
}

void MarkLiqSwept(int idx, datetime sweptTime)
{
   g_liq[idx].swept     = true;
   g_liq[idx].sweptTime = sweptTime;
   g_cnt.liqSwept++;

   AlertLiqSwept(g_liq[idx].buySide, g_liq[idx].price, sweptTime);

   string name = g_liq[idx].name;
   if(InpLiqRemoveOnSweep)
   {
      ObjectDelete(0, name);
      ObjectDelete(0, name + "_lbl");
      return;
   }
   // затемняем и фиксируем конец линии на моменте снятия
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpLiqSweptColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, sweptTime);
   ObjectDelete(0, name + "_lbl");
}

// Чистка массива: удаляем снятые (при режиме удаления) либо ограничиваем их число
void PruneLiquidity()
{
   if(InpLiqRemoveOnSweep)
   {
      string names[];
      for(int i = 0; i < ArraySize(g_liq); ++i)
         if(g_liq[i].swept)
         {
            int s = ArraySize(names); ArrayResize(names, s + 1); names[s] = g_liq[i].name;
         }
      for(int i = 0; i < ArraySize(names); ++i) RemoveLiqByName(names[i]);
      return;
   }

   int      maxSwept = 60;
   int      idxs[];
   datetime tms[];
   for(int i = 0; i < ArraySize(g_liq); ++i)
   {
      if(!g_liq[i].swept) continue;
      int s = ArraySize(idxs); ArrayResize(idxs, s + 1); ArrayResize(tms, s + 1);
      idxs[s] = i; tms[s] = g_liq[i].sweptTime;
   }
   int cnt = ArraySize(idxs);
   if(cnt <= maxSwept) return;

   for(int a = 0; a < cnt - 1; ++a)
      for(int b = a + 1; b < cnt; ++b)
         if(tms[a] > tms[b])
         {
            datetime tt = tms[a]; tms[a] = tms[b]; tms[b] = tt;
            int      ii = idxs[a]; idxs[a] = idxs[b]; idxs[b] = ii;
         }

   int toDelete = cnt - maxSwept;
   string delNames[];
   for(int x = 0; x < toDelete; ++x)
   {
      int s = ArraySize(delNames); ArrayResize(delNames, s + 1); delNames[s] = g_liq[idxs[x]].name;
   }
   for(int x = 0; x < ArraySize(delNames); ++x) RemoveLiqByName(delNames[x]);
}

void ClearLiquidityObjects()
{
   string tags[2] = {"liql_", "liqe_"};
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string nm = ObjectName(0, i, -1, -1);
      for(int t = 0; t < 2; ++t)
         if(StringFind(nm, InpObjPrefix + tags[t]) == 0) { ObjectDelete(0, nm); break; }
   }
   ArrayResize(g_liq, 0);
}

//+==================================================================+
//| Дневные и сессионные уровни ликвидности                           |
//+==================================================================+

// High/Low в заданном диапазоне времени на текущем ТФ
bool ComputeRangeHL(datetime fromT, datetime toT, double &outHi, double &outLo)
{
   if(toT <= fromT) return false;
   double hi[], lo[];
   int nh = CopyHigh(_Symbol, _Period, fromT, toT, hi);
   int nl = CopyLow (_Symbol, _Period, fromT, toT, lo);
   if(nh <= 0 || nl <= 0) return false;
   int mxi = ArrayMaximum(hi);
   int mni = ArrayMinimum(lo);
   if(mxi < 0 || mni < 0) return false;
   outHi = hi[mxi];
   outLo = lo[mni];
   return true;
}

void UpdateSessionLevels()
{
   ClearSessionObjects();
   if(!InpLiqLevelsEnable) return;
   if(!InpLiqShowDaily && !InpLiqShowSessions) return;

   datetime now       = TimeCurrent();
   datetime rightEdge = now + (datetime)(PeriodSeconds() * 30);

   // --- Дневные уровни: PDH/PDL (вчера) и CDH/CDL (сегодня) ---
   if(InpLiqShowDaily)
   {
      double   pdh = iHigh(_Symbol, PERIOD_D1, 1);
      double   pdl = iLow (_Symbol, PERIOD_D1, 1);
      double   cdh = iHigh(_Symbol, PERIOD_D1, 0);
      double   cdl = iLow (_Symbol, PERIOD_D1, 0);
      datetime pdT = iTime(_Symbol, PERIOD_D1, 1);
      datetime cdT = iTime(_Symbol, PERIOD_D1, 0);
      if(pdh > 0) DrawSessionLine("PDH", pdT, rightEdge, pdh, InpLiqDailyColor, true);
      if(pdl > 0) DrawSessionLine("PDL", pdT, rightEdge, pdl, InpLiqDailyColor, false);
      if(cdh > 0) DrawSessionLine("CDH", cdT, rightEdge, cdh, InpLiqDailyColor, true);
      if(cdl > 0) DrawSessionLine("CDL", cdT, rightEdge, cdl, InpLiqDailyColor, false);
   }

   // --- Сессионные H/L текущего дня ---
   if(InpLiqShowSessions)
   {
      datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
      if(dayStart > 0)
      {
         DrawSessionRange("Asia",   dayStart, InpLiqAsiaStart,   InpLiqAsiaEnd,   InpLiqAsiaColor,   rightEdge);
         DrawSessionRange("London", dayStart, InpLiqLondonStart, InpLiqLondonEnd, InpLiqLondonColor, rightEdge);
         DrawSessionRange("NY",     dayStart, InpLiqNYStart,     InpLiqNYEnd,     InpLiqNYColor,     rightEdge);
      }
   }
}

void DrawSessionRange(string label, datetime dayStart, int hStart, int hEnd, color clr, datetime rightEdge)
{
   if(hEnd <= hStart) return;
   datetime sStart  = dayStart + (datetime)(hStart * 3600);
   datetime sEnd    = dayStart + (datetime)(hEnd   * 3600);
   datetime now     = TimeCurrent();
   datetime sEndEff = (sEnd > now) ? now : sEnd; // сессия ещё может быть открыта
   if(sEndEff <= sStart) return;                 // сессия ещё не началась
   double hi, lo;
   if(!ComputeRangeHL(sStart, sEndEff, hi, lo)) return;
   DrawSessionLine(label + " H", sStart, rightEdge, hi, clr, true);
   DrawSessionLine(label + " L", sStart, rightEdge, lo, clr, false);
}

void DrawSessionLine(string label, datetime t1, datetime t2, double price, color clr, bool above)
{
   string name = InpObjPrefix + "liqs_" + label + "_" + IntegerToString((long)t1);
   StringReplace(name, " ", "_");
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,  true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   if(InpLiqShowLabels)
   {
      string lbl = name + "_lbl";
      if(ObjectFind(0, lbl) < 0)
         ObjectCreate(0, lbl, OBJ_TEXT, 0, t2, price);
      ObjectSetInteger(0, lbl, OBJPROP_TIME,  t2);
      ObjectSetDouble (0, lbl, OBJPROP_PRICE, price);
      ObjectSetString (0, lbl, OBJPROP_TEXT,  " " + label);
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, above ? ANCHOR_RIGHT_LOWER : ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lbl, OBJPROP_HIDDEN, true);
   }
}

void ClearSessionObjects()
{
   string p = InpObjPrefix + "liqs_";
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, p) == 0) ObjectDelete(0, nm);
   }
}

//+==================================================================+
//| Order Block                                                        |
//+==================================================================+
void TryDrawOB(int i, bool bull,
               const datetime &time[],
               const double &open[], const double &high[],
               const double &low[],  const double &close[],
               const long &tickv[], const long &realv[],
               DrawCtx &ctx, ENUM_TIMEFRAMES tf,
               int obExtendBars, int obMaxCount)
{
   int L = InpSwingLength;
   int ob = -1;
   for(int k = 1; k <= L; ++k)
   {
      int idx = i - k;
      if(idx < 0) break;
      bool bearishBar = close[idx] < open[idx];
      bool bullishBar = close[idx] > open[idx];
      if(bull && bearishBar) { ob = idx; break; }
      if(!bull && bullishBar){ ob = idx; break; }
   }
   if(ob < 0) return;

   datetime t1 = time[ob];
   double   hi = high[ob];
   double   lo = low[ob];
   datetime t2 = t1 + (datetime)(PeriodSeconds(tf) * obExtendBars);

   // Displacement-проверка: появился ли FVG в импульсе после OB до свинга
   bool strong = DetectImpulseFVG(ob, i, bull, high, low);

   // Максимальный объём внутри зоны OB: от OB-бара до бара слома структуры
   long maxVol = MaxVolumeInRange(ob, i, tickv, realv);

   string tag  = bull ? "obB_" : "obS_";
   string name = ctx.prefix + tag + IntegerToString((long)t1);
   color  clr  = bull ? ctx.obBullClr : ctx.obBearClr;
   if(InpHighlightUntested && InpUntestedApplyOB && !ctx.isMTF)
      clr = InpUntestedColor;   // свежий (непротестированный) OB — пока цена не вернулась в зону

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, hi);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL,  true);
   ObjectSetInteger(0, name, OBJPROP_BACK,  true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, strong ? STYLE_SOLID : STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, strong ? 2 : 1);

   // Подпись с максимальным объёмом внутри OB
   if(InpOBShowVolume && maxVol > 0)
      DrawOBVolumeLabel(name + "_v", t1, hi, lo, maxVol);

   // Регистрируем в массиве для трекинга mitigation
   AddOrUpdateOB(name, t1, hi, lo, t2, bull, ctx.isMTF, strong, maxVol);

   if(bull) g_cnt.obBullActive++;
   else     g_cnt.obBearActive++;

   // Лимит активных OB
   string limitTag = ctx.isMTF ? ("mtf_" + tag) : tag;
   LimitObjectsByTag(limitTag, obMaxCount, "");
}

// Максимальный объём (tick/real по InpVolumeType) на барах [from..to]
long MaxVolumeInRange(int from, int to, const long &tickv[], const long &realv[])
{
   if(from > to) { int tmp = from; from = to; to = tmp; }
   if(from < 0) from = 0;
   long mx = 0;
   for(int k = from; k <= to; ++k)
   {
      long v = GetVolume(k, tickv, realv);
      if(v > mx) mx = v;
   }
   return mx;
}

// Текстовая подпись с объёмом внутри прямоугольника OB
void DrawOBVolumeLabel(string name, datetime t, double hi, double lo, long vol)
{
   double y = (hi + lo) / 2.0;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, y);
   ObjectSetInteger(0, name, OBJPROP_TIME,  t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, y);
   ObjectSetString (0, name, OBJPROP_TEXT,  " V:" + FormatVolume(vol));
   ObjectSetString (0, name, OBJPROP_FONT,  "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpOBVolFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpOBVolTextColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, name, OBJPROP_BACK,  false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

// Проверка наличия FVG в (obBar..swingBar] нужного направления — признак displacement
bool DetectImpulseFVG(int obBar, int swingBar, bool bull,
                      const double &high[], const double &low[])
{
   int maxK = MathMin(swingBar, obBar + InpEntryOBImpulseMaxBars);
   for(int k = obBar + 2; k <= maxK; ++k)
   {
      if(k - 2 < 0) continue;
      if(bull  && low[k]  > high[k-2]) return true;
      if(!bull && high[k] < low[k-2])  return true;
   }
   return false;
}

void AddOrUpdateOB(string name, datetime t, double topP, double botP,
                   datetime extendTo, bool bull, bool mtf, bool strong, long maxVol)
{
   for(int i = 0; i < ArraySize(g_obs); ++i)
   {
      if(g_obs[i].name == name)
      {
         g_obs[i].topPrice = topP;
         g_obs[i].botPrice = botP;
         g_obs[i].extendTo = extendTo;
         g_obs[i].bull     = bull;
         g_obs[i].mtf      = mtf;
         if(maxVol > g_obs[i].maxVol) g_obs[i].maxVol = maxVol;
         if(strong && !g_obs[i].strong)
         {
            g_obs[i].strong = true;
            if(!mtf)
            {
               if(bull) g_cnt.obStrongBull++;
               else     g_cnt.obStrongBear++;
            }
         }
         return;
      }
   }
   int sz = ArraySize(g_obs);
   ArrayResize(g_obs, sz + 1);
   g_obs[sz].name        = name;
   g_obs[sz].time        = t;
   g_obs[sz].topPrice    = topP;
   g_obs[sz].botPrice    = botP;
   g_obs[sz].extendTo    = extendTo;
   g_obs[sz].bull        = bull;
   g_obs[sz].mtf         = mtf;
   g_obs[sz].mitigated   = false;
   g_obs[sz].strong      = strong;
   g_obs[sz].maxVol      = maxVol;
   g_obs[sz].checkedUpTo = t;
   if(strong && !mtf)
   {
      if(bull) g_cnt.obStrongBull++;
      else     g_cnt.obStrongBear++;
   }
}

void RemoveOBFromArray(string name)
{
   int sz = ArraySize(g_obs);
   for(int i = 0; i < sz; ++i)
   {
      if(g_obs[i].name == name)
      {
         // Уменьшаем счётчик активных, если ещё не mitigated
         if(!g_obs[i].mitigated)
         {
            if(g_obs[i].bull) g_cnt.obBullActive--;
            else              g_cnt.obBearActive--;
         }
         for(int j = i; j < sz - 1; ++j) g_obs[j] = g_obs[j + 1];
         ArrayResize(g_obs, sz - 1);
         return;
      }
   }
}

//+==================================================================+
//| OB Mitigation tracking                                            |
//| Bull OB сработал, когда цена опустилась внутрь зоны (low <= top). |
//| Bear OB сработал, когда цена поднялась внутрь зоны (high >= bot). |
//+==================================================================+
void UpdateOBMitigation(const datetime &time[], const double &high[],
                        const double &low[], int rates_total)
{
   datetime latestBar = time[rates_total - 1];
   for(int idx = 0; idx < ArraySize(g_obs); ++idx)
   {
      if(g_obs[idx].mitigated) continue;
      if(g_obs[idx].mtf) continue; // MTF OB не трекаем по текущему ТФ
      if(g_obs[idx].checkedUpTo >= latestBar) continue; // уже проверяли

      // Стартуем с бара после последнего проверенного
      datetime sinceTime = (g_obs[idx].checkedUpTo > g_obs[idx].time)
                              ? g_obs[idx].checkedUpTo
                              : g_obs[idx].time;
      int startBar = FindBarByTime(time, rates_total, sinceTime);
      if(startBar < 0) startBar = 0;
      startBar++;
      if(startBar < 1) startBar = 1;

      datetime mitTime = 0;
      for(int b = startBar; b < rates_total; ++b)
      {
         if(g_obs[idx].bull)
         {
            if(low[b] <= g_obs[idx].topPrice) { mitTime = time[b]; break; }
         }
         else
         {
            if(high[b] >= g_obs[idx].botPrice) { mitTime = time[b]; break; }
         }
      }
      if(mitTime != 0)
         MarkOBMitigatedByIndex(idx, mitTime);
      else
         g_obs[idx].checkedUpTo = latestBar;
   }
}

int FindBarByTime(const datetime &time[], int rates_total, datetime t)
{
   // линейный поиск с конца — типичные OB новые
   for(int i = rates_total - 1; i >= 0; --i)
      if(time[i] == t) return i;
   return -1;
}

void MarkOBMitigatedByIndex(int idx, datetime mitTime)
{
   g_obs[idx].mitigated = true;
   if(InpOBHideMitigated)
   {
      ObjectDelete(0, g_obs[idx].name);
      ObjectDelete(0, g_obs[idx].name + "_v");   // подпись объёма OB
   }
   else
   {
      ObjectSetInteger(0, g_obs[idx].name, OBJPROP_COLOR, InpOBMitigatedClr);
      ObjectSetInteger(0, g_obs[idx].name, OBJPROP_FILL,  false);
      ObjectSetInteger(0, g_obs[idx].name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, g_obs[idx].name, OBJPROP_BACK,  false);
      if(InpOBExtendOnTouch)
         ObjectSetInteger(0, g_obs[idx].name, OBJPROP_TIME, 1, mitTime);
   }
   if(g_obs[idx].bull) { g_cnt.obBullActive--; g_cnt.obBullMit++; }
   else                { g_cnt.obBearActive--; g_cnt.obBearMit++; }
}

//+==================================================================+
//| Алерты                                                             |
//+==================================================================+
void AlertStructure(string what, datetime t, bool isMTF)
{
   if(!InpAlertOnBOS) return;
   if(TimeCurrent() - t > PeriodSeconds() * 2) return;
   string tfName = isMTF ? EnumToString(InpMTFPeriod) : EnumToString(_Period);
   Alert(_Symbol, " ", tfName, " ", what, " @ ", TimeToString(t, TIME_DATE|TIME_MINUTES));
}

void AlertSweep(string what, datetime t)
{
   if(!InpAlertOnSweep) return;
   if(TimeCurrent() - t > PeriodSeconds() * 2) return;
   Alert(_Symbol, " ", EnumToString(_Period), " ", what, " @ ", TimeToString(t, TIME_DATE|TIME_MINUTES));
}

// Алерт при снятии линии ликвидности (BSL/SSL). Recency-guard защищает от спама на истории.
void AlertLiqSwept(bool buySide, double price, datetime t)
{
   if(!InpLiqAlert) return;
   if(TimeCurrent() - t > PeriodSeconds() * 2) return;
   string side = buySide ? "BSL (buy-side)" : "SSL (sell-side)";
   string msg  = StringFormat("%s %s: %s ликвидность снята @ %s",
                              _Symbol, EnumToString(_Period), side,
                              DoubleToString(price, _Digits));
   Alert(msg);
   if(InpLiqAlertPush) SendNotification(msg);
}

//+==================================================================+
//| MTF: копируем данные старшего ТФ и прогоняем тот же детектор      |
//+==================================================================+
void ProcessMTF()
{
   // Защита: MTF имеет смысл только для старшего ТФ (или равного)
   if(PeriodSeconds(InpMTFPeriod) < PeriodSeconds(_Period))
   {
      ClearMTFObjects();
      ClearMTFOBsArray();
      return;
   }

   int n = InpMTFLookback;
   if(n < InpSwingLength * 4) n = InpSwingLength * 4;

   datetime t[];
   double   o[], h[], l[], c[];
   long     tv[], rv[];

   if(CopyTime (_Symbol, InpMTFPeriod, 0, n, t) <= 0) return;
   if(CopyOpen (_Symbol, InpMTFPeriod, 0, n, o) <= 0) return;
   if(CopyHigh (_Symbol, InpMTFPeriod, 0, n, h) <= 0) return;
   if(CopyLow  (_Symbol, InpMTFPeriod, 0, n, l) <= 0) return;
   if(CopyClose(_Symbol, InpMTFPeriod, 0, n, c) <= 0) return;

   // Объём старшего ТФ для расчёта макс. объёма в OB
   if(CopyTickVolume(_Symbol, InpMTFPeriod, 0, n, tv) <= 0)
      ArrayResize(tv, ArraySize(t));
   if(InpVolumeType == VOLUME_REAL)
   {
      if(CopyRealVolume(_Symbol, InpMTFPeriod, 0, n, rv) <= 0)
         ArrayResize(rv, ArraySize(t));
   }
   else
      ArrayResize(rv, ArraySize(t));

   ArraySetAsSeries(t, false);
   ArraySetAsSeries(o, false);
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);
   ArraySetAsSeries(tv, false);
   ArraySetAsSeries(rv, false);

   // Чистим прошлые MTF-объекты и MTF OB-записи
   ResetState(g_mtfState);
   ClearMTFObjects();
   ClearMTFOBsArray();
   g_cnt.mtfBosBull = g_cnt.mtfBosBear = 0;
   g_cnt.mtfChochBull = g_cnt.mtfChochBear = 0;

   int total = ArraySize(t);
   int last_confirmable = total - InpSwingLength - 1;
   for(int i = InpSwingLength; i <= last_confirmable; ++i)
   {
      DetectSwingGeneric(i, InpSwingLength, t, o, h, l, c, tv, rv,
                         g_mtfState, g_ctxMTF, InpMTFPeriod,
                         InpOBExtendBars, InpOBMaxCount);
   }
}

void ClearMTFObjects()
{
   string mtfPrefix = InpObjPrefix + "mtf_";
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, mtfPrefix) == 0)
         ObjectDelete(0, nm);
   }
}

void ClearMTFOBsArray()
{
   int sz = ArraySize(g_obs);
   for(int i = sz - 1; i >= 0; --i)
   {
      if(g_obs[i].mtf)
      {
         for(int j = i; j < sz - 1; ++j) g_obs[j] = g_obs[j + 1];
         sz--;
      }
   }
   ArrayResize(g_obs, sz);
}

//+==================================================================+
//| ENTRY SIGNALS                                                      |
//+==================================================================+

// Проверка: цена бара ([low, high]) лежит внутри активного OB нужного типа?
bool PriceInActiveOB(double barLow, double barHigh, bool wantBull)
{
   return FindActiveOBIndex(barLow, barHigh, wantBull) >= 0;
}

// Возвращает индекс лучшего активного OB (приоритет: strong, затем самый свежий)
int FindActiveOBIndex(double barLow, double barHigh, bool wantBull)
{
   int best = -1;
   double bestScore = -1.0;
   for(int idx = 0; idx < ArraySize(g_obs); ++idx)
   {
      if(g_obs[idx].mitigated) continue;
      if(g_obs[idx].mtf) continue;
      if(g_obs[idx].bull != wantBull) continue;
      if(barHigh >= g_obs[idx].botPrice && barLow <= g_obs[idx].topPrice)
      {
         double sc = (g_obs[idx].strong ? 1e12 : 0) + (double)g_obs[idx].time;
         if(sc > bestScore) { bestScore = sc; best = idx; }
      }
   }
   return best;
}

// Premium/Discount: для BUY ждём "discount" (нижняя половина), для SELL — "premium"
bool IsInPremDiscount(bool wantBull, double price)
{
   double H = 0, L = 0;
   bool ok = false;
   if(InpEntryPremDiscMTF && InpMTFEnable && g_mtfState.lastH.valid && g_mtfState.lastL.valid)
   {
      H = g_mtfState.lastH.price; L = g_mtfState.lastL.price; ok = true;
   }
   else if(g_state.lastH.valid && g_state.lastL.valid)
   {
      H = g_state.lastH.price; L = g_state.lastL.price; ok = true;
   }
   if(!ok) return true; // fail-open: нет данных о диапазоне → не блокируем
   if(H <= L) return true;
   double pos = (price - L) / (H - L);
   double mid = InpEntryPremDiscMid;
   double d   = MathMax(0.0, InpEntryPremDiscDelta);
   if(wantBull) return pos < (mid - d);
   else         return pos > (mid + d);
}

// Rejection-фитиль на закрытом баре: нижний фитиль > body для BUY, верхний — для SELL
bool BarRejectionOK(bool wantBull, double op, double hi, double lo, double cl)
{
   double range = hi - lo;
   if(range <= 0) return false;
   double body = MathAbs(cl - op);
   if(body <= 0) body = range * 0.05;
   if(wantBull)
   {
      double lowerWick = MathMin(op, cl) - lo;
      return lowerWick > body * 0.5 && cl >= op;
   }
   else
   {
      double upperWick = hi - MathMax(op, cl);
      return upperWick > body * 0.5 && cl <= op;
   }
}

// ATR на нужном баре
double GetATR(int rates_total, int barIdx)
{
   if(g_atrHandle == INVALID_HANDLE) return 0.0;
   int shift = rates_total - 1 - barIdx;
   if(shift < 0) shift = 0;
   double buf[];
   if(CopyBuffer(g_atrHandle, 0, shift, 1, buf) <= 0) return 0.0;
   return buf[0];
}

// Расчёт SL/TP для entry с учётом OB-границы и кандидатов TP
void ComputeEntrySLTP(bool bull, int obIdx, double price, double atr,
                      double &sl, double &tp1, double &tp2)
{
   sl = 0; tp1 = 0; tp2 = 0;
   if(obIdx < 0) return;
   double buf = MathMax(atr * InpEntrySLATRMult, _Point * 5);
   if(bull) sl = g_obs[obIdx].botPrice - buf;
   else     sl = g_obs[obIdx].topPrice + buf;

   double cands[]; ArrayResize(cands, 0);

   // Противоположные OB
   for(int j = 0; j < ArraySize(g_obs); ++j)
   {
      if(g_obs[j].mitigated) continue;
      if(g_obs[j].mtf) continue;
      if(g_obs[j].bull == bull) continue;
      double key = bull ? g_obs[j].botPrice : g_obs[j].topPrice;
      if((bull && key > price) || (!bull && key < price))
      {
         int sz = ArraySize(cands); ArrayResize(cands, sz + 1); cands[sz] = key;
      }
   }
   // VP уровни
   if(InpEntryUseVPForTP && g_vpReady)
   {
      double levs[3]; levs[0] = g_pocPrice; levs[1] = g_vahPrice; levs[2] = g_valPrice;
      for(int k = 0; k < 3; ++k)
      {
         if(levs[k] <= 0) continue;
         if((bull && levs[k] > price) || (!bull && levs[k] < price))
         {
            int sz = ArraySize(cands); ArrayResize(cands, sz + 1); cands[sz] = levs[k];
         }
      }
   }
   // Последний свинг как глобальная цель
   if(bull && g_state.lastH.valid && g_state.lastH.price > price)
   { int sz = ArraySize(cands); ArrayResize(cands, sz + 1); cands[sz] = g_state.lastH.price; }
   if(!bull && g_state.lastL.valid && g_state.lastL.price < price)
   { int sz = ArraySize(cands); ArrayResize(cands, sz + 1); cands[sz] = g_state.lastL.price; }

   int n = ArraySize(cands);
   if(n == 0) return;
   // Сортировка: ближайшие к цене первыми
   for(int a = 0; a < n - 1; ++a)
      for(int b = a + 1; b < n; ++b)
      {
         bool swap = bull ? (cands[a] > cands[b]) : (cands[a] < cands[b]);
         if(swap) { double tt = cands[a]; cands[a] = cands[b]; cands[b] = tt; }
      }
   tp1 = cands[0];
   for(int x = 1; x < n; ++x)
   {
      if(MathAbs(cands[x] - tp1) > _Point * 5) { tp2 = cands[x]; break; }
   }
}

double ComputeRR(bool bull, double entry, double sl, double tp)
{
   if(sl <= 0 || tp <= 0) return 0;
   double risk = bull ? (entry - sl) : (sl - entry);
   double rew  = bull ? (tp - entry) : (entry - tp);
   if(risk <= 0 || rew <= 0) return 0;
   return rew / risk;
}

// Рисуем SL/TP пунктирами и подпись score/RR у стрелки
void DrawEntryLevels(bool bull, datetime t, double price,
                     double sl, double tp1, double tp2,
                     int score, double rr)
{
   string dir = bull ? "u" : "d";
   string base = InpObjPrefix + "ent_" + dir + "_" + IntegerToString((long)t);
   datetime tEnd = t + (datetime)(PeriodSeconds() * MathMax(2, InpEntryLevelsBars));

   if(InpEntryShowLevels)
   {
      DrawEntryLine(base + "_sl",  t, sl,  tEnd, InpEntrySLColor, STYLE_DASH);
      DrawEntryLine(base + "_tp1", t, tp1, tEnd, InpEntryTPColor, STYLE_DOT);
      DrawEntryLine(base + "_tp2", t, tp2, tEnd, InpEntryTPColor, STYLE_DOT);
   }

   if(InpEntryShowLabel)
   {
      string nm = base + "_lbl";
      double y = bull ? price : price;
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, t, y);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  t);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, y);
      string txt = "";
      if(score > 0) txt = StringFormat("s%d", score);
      if(rr > 0)
         txt = (StringLen(txt) > 0 ? txt + " " : "") + StringFormat("RR%.2f", rr);
      ObjectSetString (0, nm, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, bull ? InpEntryUpColor : InpEntryDnColor);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, bull ? ANCHOR_UPPER : ANCHOR_LOWER);
   }
}

void DrawEntryLine(string nm, datetime t1, double price, datetime t2, color clr, int style)
{
   if(price <= 0) { if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm); return; }
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, nm, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, nm, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, style);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
}

// Паттерн "liquidity grab → CHoCH": сначала снятие ликвидности (sweep свинга в обратную
// сторону), затем в пределах InpEntryGrabMaxBars — CHoCH в направлении сделки.
//  • BUY : снятие sell-side ликвидности (sweep low) → бычий CHoCH
//  • SELL: снятие buy-side ликвидности (sweep high) → медвежий CHoCH
bool GrabChochOK(bool bull, datetime t)
{
   long winGrab = (long)PeriodSeconds(_Period) * (long)MathMax(1, InpEntryGrabMaxBars);
   long winRec  = (long)PeriodSeconds(_Period) * (long)MathMax(1, InpEntryRecencyBars);

   datetime grabT  = bull ? g_lastSweepLowTime  : g_lastSweepHighTime;
   datetime chochT = bull ? g_lastBullChochTime : g_lastBearChochTime;

   if(grabT == 0 || chochT == 0)            return false;  // обоих событий ещё не было
   if(chochT < grabT)                       return false;  // CHoCH должен быть ПОСЛЕ снятия
   if((long)(chochT - grabT) > winGrab)     return false;  // слишком большой разрыв grab→CHoCH
   if(t < chochT)                           return false;  // сигнал не раньше CHoCH
   if((long)(t - chochT) > winRec)          return false;  // паттерн уже «остыл»
   return true;
}

// Главный детектор entry-сигнала на закрытом баре i
void DetectEntry(int i, int rates_total,
                 const datetime &time[],
                 const double &open[], const double &high[],
                 const double &low[],  const double &close[])
{
   BufEntryUp[i] = EMPTY_VALUE;
   BufEntryDn[i] = EMPTY_VALUE;
   if(!InpEntryEnable) return;

   long recencyTs = (long)PeriodSeconds(_Period) * (long)InpEntryRecencyBars;
   datetime t = time[i];
   double price = close[i];
   double atr   = GetATR(rates_total, i);

   // ===== BUY =====
   {
      bool trendOk    = (g_state.trend == 1);
      bool mtfOk      = (!InpMTFEnable) || (g_mtfState.trend == 1);
      bool volOk      = (BufHighVolUp[i] != EMPTY_VALUE);
      int  obIdx      = FindActiveOBIndex(low[i], high[i], true);
      bool obOk       = (obIdx >= 0);
      bool strongObOk = (obIdx >= 0 && g_obs[obIdx].strong);
      bool sweepOk    = (g_lastSweepLowTime != 0 && (long)(t - g_lastSweepLowTime) <= recencyTs);
      bool structOk   = (g_lastBullStructTime != 0 && (long)(t - g_lastBullStructTime) <= recencyTs);
      bool pdOk       = IsInPremDiscount(true, price);
      bool rejectOk   = BarRejectionOK(true, open[i], high[i], low[i], close[i]);
      bool grabChOk   = GrabChochOK(true, t);
      double dltVal   = 0.0;
      bool   dltKnown = (InpDeltaEnable && LookupDelta(t, dltVal));
      bool   deltaOk  = (!dltKnown) || (dltVal > 0.0);   // мягко: вне окна тиков не блокируем
      bool vpCnf      = false;
      if(g_vpReady && atr > 0)
      {
         double dPoc = (g_pocPrice > 0) ? MathAbs(price - g_pocPrice) : 1e18;
         double dVa  = MathMin((g_vahPrice > 0) ? MathAbs(price - g_vahPrice) : 1e18,
                               (g_valPrice > 0) ? MathAbs(price - g_valPrice) : 1e18);
         vpCnf = MathMin(dPoc, dVa) <= atr * 0.30;
      }

      double sl = 0, tp1 = 0, tp2 = 0, rr = 0;
      if(obOk) ComputeEntrySLTP(true, obIdx, price, atr, sl, tp1, tp2);
      if(sl > 0 && tp1 > 0) rr = ComputeRR(true, price, sl, tp1);
      bool rrOk = (InpEntryMinRR <= 0) || (rr >= InpEntryMinRR);

      bool coolOk = true;
      if(InpEntryCooldownBars > 0 && g_lastEntryUpTime != 0 &&
         (long)(t - g_lastEntryUpTime) < (long)PeriodSeconds(_Period) * InpEntryCooldownBars)
         coolOk = false;
      if(coolOk && InpEntryMinDistATR > 0 && atr > 0 && g_lastEntryUpPrice > 0 &&
         MathAbs(price - g_lastEntryUpPrice) < atr * InpEntryMinDistATR)
         coolOk = false;

      int  score = 0;
      bool fire  = false;

      if(InpEntryUseScore)
      {
         if(trendOk)               score += InpEntryWeightTrend;
         if(mtfOk && InpMTFEnable) score += InpEntryWeightMTF;
         if(obOk)                  score += InpEntryWeightOB;
         if(strongObOk)            score += InpEntryWeightStrongOB;
         if(volOk)                 score += InpEntryWeightVolume;
         if(sweepOk)               score += InpEntryWeightSweep;
         if(structOk)              score += InpEntryWeightStruct;
         if(pdOk)                  score += InpEntryWeightPremDisc;
         if(rrOk && rr > 0)        score += InpEntryWeightRR;
         if(vpCnf)                 score += InpEntryWeightVPCnflu;
         if(rejectOk)              score += InpEntryWeightReject;
         if(grabChOk)              score += InpEntryWeightGrabChoCH;
         if(dltKnown && dltVal > 0.0) score += InpEntryWeightDelta;
         fire = (score >= InpEntryMinScore) && coolOk;
      }
      else
      {
         bool ok = true;
         if(InpEntryNeedTrend && !trendOk) ok = false;
         if(ok && InpEntryNeedMTF && InpMTFEnable && !mtfOk) ok = false;
         if(ok && InpEntryNeedVolume && !volOk) ok = false;
         if(ok && InpEntryNeedOB && !obOk)      ok = false;
         if(ok && InpEntryNeedSweep && !sweepOk) ok = false;
         if(ok && InpEntryNeedStruct && !structOk) ok = false;
         fire = ok && coolOk;
         score = (trendOk?1:0) + (mtfOk?1:0) + (obOk?1:0) + (strongObOk?1:0) +
                 (volOk?1:0) + (sweepOk?1:0) + (structOk?1:0) + (pdOk?1:0) +
                 (rejectOk?1:0) + (vpCnf?1:0) + (grabChOk?1:0);
      }

      // Жёсткие гейты применяются ВСЕГДА (и в score, и в AND-режиме)
      if(fire && InpEntryNeedPremDisc && !pdOk) fire = false;
      if(fire && InpEntryNeedStrongOB && !strongObOk) fire = false;
      if(fire && InpEntryNeedReject  && !rejectOk) fire = false;
      if(fire && InpEntryNeedRR      && !rrOk)     fire = false;
      if(fire && InpEntryNeedGrabChoCH && !grabChOk) fire = false;
      if(fire && InpEntryNeedDelta   && !deltaOk)  fire = false;
      // В score-режиме чекбоксы тренд/OB/etc можно использовать как hard-gate
      if(fire && InpEntryUseScore)
      {
         if(InpEntryNeedTrend  && !trendOk)               fire = false;
         if(InpEntryNeedMTF    && InpMTFEnable && !mtfOk) fire = false;
         if(InpEntryNeedOB     && !obOk)                  fire = false;
         if(InpEntryNeedVolume && !volOk)                 fire = false;
         if(InpEntryNeedSweep  && !sweepOk)               fire = false;
         if(InpEntryNeedStruct && !structOk)              fire = false;
      }

      if(fire)
      {
         BufEntryUp[i] = low[i];
         g_cnt.entryUp++;
         DrawEntryLevels(true, t, price, sl, tp1, tp2, score, rr);
         g_lastEntryUpTime  = t;
         g_lastEntryUpPrice = price;
         EntryAlert("BUY entry", t);
         return;
      }
   }

   // ===== SELL =====
   {
      bool trendOk    = (g_state.trend == -1);
      bool mtfOk      = (!InpMTFEnable) || (g_mtfState.trend == -1);
      bool volOk      = (BufHighVolDn[i] != EMPTY_VALUE);
      int  obIdx      = FindActiveOBIndex(low[i], high[i], false);
      bool obOk       = (obIdx >= 0);
      bool strongObOk = (obIdx >= 0 && g_obs[obIdx].strong);
      bool sweepOk    = (g_lastSweepHighTime != 0 && (long)(t - g_lastSweepHighTime) <= recencyTs);
      bool structOk   = (g_lastBearStructTime != 0 && (long)(t - g_lastBearStructTime) <= recencyTs);
      bool pdOk       = IsInPremDiscount(false, price);
      bool rejectOk   = BarRejectionOK(false, open[i], high[i], low[i], close[i]);
      bool grabChOk   = GrabChochOK(false, t);
      double dltVal   = 0.0;
      bool   dltKnown = (InpDeltaEnable && LookupDelta(t, dltVal));
      bool   deltaOk  = (!dltKnown) || (dltVal < 0.0);   // мягко: вне окна тиков не блокируем
      bool vpCnf      = false;
      if(g_vpReady && atr > 0)
      {
         double dPoc = (g_pocPrice > 0) ? MathAbs(price - g_pocPrice) : 1e18;
         double dVa  = MathMin((g_vahPrice > 0) ? MathAbs(price - g_vahPrice) : 1e18,
                               (g_valPrice > 0) ? MathAbs(price - g_valPrice) : 1e18);
         vpCnf = MathMin(dPoc, dVa) <= atr * 0.30;
      }

      double sl = 0, tp1 = 0, tp2 = 0, rr = 0;
      if(obOk) ComputeEntrySLTP(false, obIdx, price, atr, sl, tp1, tp2);
      if(sl > 0 && tp1 > 0) rr = ComputeRR(false, price, sl, tp1);
      bool rrOk = (InpEntryMinRR <= 0) || (rr >= InpEntryMinRR);

      bool coolOk = true;
      if(InpEntryCooldownBars > 0 && g_lastEntryDnTime != 0 &&
         (long)(t - g_lastEntryDnTime) < (long)PeriodSeconds(_Period) * InpEntryCooldownBars)
         coolOk = false;
      if(coolOk && InpEntryMinDistATR > 0 && atr > 0 && g_lastEntryDnPrice > 0 &&
         MathAbs(price - g_lastEntryDnPrice) < atr * InpEntryMinDistATR)
         coolOk = false;

      int  score = 0;
      bool fire  = false;

      if(InpEntryUseScore)
      {
         if(trendOk)               score += InpEntryWeightTrend;
         if(mtfOk && InpMTFEnable) score += InpEntryWeightMTF;
         if(obOk)                  score += InpEntryWeightOB;
         if(strongObOk)            score += InpEntryWeightStrongOB;
         if(volOk)                 score += InpEntryWeightVolume;
         if(sweepOk)               score += InpEntryWeightSweep;
         if(structOk)              score += InpEntryWeightStruct;
         if(pdOk)                  score += InpEntryWeightPremDisc;
         if(rrOk && rr > 0)        score += InpEntryWeightRR;
         if(vpCnf)                 score += InpEntryWeightVPCnflu;
         if(rejectOk)              score += InpEntryWeightReject;
         if(grabChOk)              score += InpEntryWeightGrabChoCH;
         if(dltKnown && dltVal < 0.0) score += InpEntryWeightDelta;
         fire = (score >= InpEntryMinScore) && coolOk;
      }
      else
      {
         bool ok = true;
         if(InpEntryNeedTrend && !trendOk) ok = false;
         if(ok && InpEntryNeedMTF && InpMTFEnable && !mtfOk) ok = false;
         if(ok && InpEntryNeedVolume && !volOk) ok = false;
         if(ok && InpEntryNeedOB && !obOk)      ok = false;
         if(ok && InpEntryNeedSweep && !sweepOk) ok = false;
         if(ok && InpEntryNeedStruct && !structOk) ok = false;
         fire = ok && coolOk;
         score = (trendOk?1:0) + (mtfOk?1:0) + (obOk?1:0) + (strongObOk?1:0) +
                 (volOk?1:0) + (sweepOk?1:0) + (structOk?1:0) + (pdOk?1:0) +
                 (rejectOk?1:0) + (vpCnf?1:0) + (grabChOk?1:0);
      }

      if(fire && InpEntryNeedPremDisc && !pdOk) fire = false;
      if(fire && InpEntryNeedStrongOB && !strongObOk) fire = false;
      if(fire && InpEntryNeedReject  && !rejectOk) fire = false;
      if(fire && InpEntryNeedRR      && !rrOk)     fire = false;
      if(fire && InpEntryNeedGrabChoCH && !grabChOk) fire = false;
      if(fire && InpEntryNeedDelta   && !deltaOk)  fire = false;
      if(fire && InpEntryUseScore)
      {
         if(InpEntryNeedTrend  && !trendOk)               fire = false;
         if(InpEntryNeedMTF    && InpMTFEnable && !mtfOk) fire = false;
         if(InpEntryNeedOB     && !obOk)                  fire = false;
         if(InpEntryNeedVolume && !volOk)                 fire = false;
         if(InpEntryNeedSweep  && !sweepOk)               fire = false;
         if(InpEntryNeedStruct && !structOk)              fire = false;
      }

      if(fire)
      {
         BufEntryDn[i] = high[i];
         g_cnt.entryDn++;
         DrawEntryLevels(false, t, price, sl, tp1, tp2, score, rr);
         g_lastEntryDnTime  = t;
         g_lastEntryDnPrice = price;
         EntryAlert("SELL entry", t);
      }
   }
}

void EntryAlert(string what, datetime t)
{
   if(!InpEntryAlert) return;
   if(TimeCurrent() - t > PeriodSeconds() * 2) return;
   Alert(_Symbol, " ", EnumToString(_Period), " ", what, " @ ", TimeToString(t, TIME_DATE|TIME_MINUTES));
}

//+==================================================================+
//| DELTA / CUMULATIVE DELTA (footprint по тикам)                      |
//+==================================================================+
// Объём одного тика: реальный, иначе тиковый, иначе 1
long TickVol(const MqlTick &tk)
{
   if(tk.volume_real > 0.0) return (long)tk.volume_real;
   if(tk.volume > 0)        return (long)tk.volume;
   return 1;
}

// Удаление всех объектов с заданным префиксом
void ClearTagObjects(string tag)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, tag) == 0) ObjectDelete(0, nm);
   }
}

void ClearDeltaObjects()
{
   ClearTagObjects(InpObjPrefix + "dlt_");
}

// Дельта (buyVol - sellVol) на интервале [tFrom, tTo) по тикам
double ComputeBarDelta(datetime tFrom, datetime tTo, bool &ok)
{
   ok = false;
   MqlTick ticks[];
   ulong from_msc = (ulong)tFrom * 1000;
   ulong to_msc   = (ulong)tTo   * 1000;
   if(to_msc <= from_msc) to_msc = from_msc + 1000;
   to_msc -= 1;  // правую границу делаем эксклюзивной

   int got = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, from_msc, to_msc);
   if(got <= 0) return 0.0;

   ok = true;
   long   buy = 0, sell = 0;
   double prevPrice = 0.0;
   for(int k = 0; k < got; ++k)
   {
      long v = TickVol(ticks[k]);
      uint f = ticks[k].flags;

      if((f & TICK_FLAG_BUY) != 0)        buy  += v;
      else if((f & TICK_FLAG_SELL) != 0)  sell += v;
      else
      {
         // Фолбэк (форекс без потока сделок): направление по изменению цены
         double p = (ticks[k].last > 0.0) ? ticks[k].last
                                          : ((ticks[k].bid + ticks[k].ask) / 2.0);
         if(prevPrice > 0.0)
         {
            if(p > prevPrice)      buy  += v;
            else if(p < prevPrice) sell += v;
         }
         if(p > 0.0) prevPrice = p;
      }
   }
   return (double)(buy - sell);
}

// Добавить в окно один закрытый бар с индексом b
void DeltaAppendBar(int b, const datetime &time[], const double &high[], const double &low[])
{
   bool ok = false;
   double d = ComputeBarDelta(time[b], time[b + 1], ok);

   int sz = ArraySize(g_dltTime);
   ArrayResize(g_dltTime,  sz + 1);
   ArrayResize(g_dltHigh,  sz + 1);
   ArrayResize(g_dltLow,   sz + 1);
   ArrayResize(g_dltDelta, sz + 1);
   ArrayResize(g_dltCVD,   sz + 1);

   g_dltTime[sz]  = time[b];
   g_dltHigh[sz]  = high[b];
   g_dltLow[sz]   = low[b];
   g_dltDelta[sz] = d;
   g_dltCVD[sz]   = 0.0;
}

// Оставить в окне только последние n баров
void DeltaTrim(int n)
{
   int sz = ArraySize(g_dltTime);
   if(sz <= n) return;
   int drop = sz - n;
   for(int k = 0; k < n; ++k)
   {
      g_dltTime[k]  = g_dltTime[k + drop];
      g_dltHigh[k]  = g_dltHigh[k + drop];
      g_dltLow[k]   = g_dltLow[k + drop];
      g_dltDelta[k] = g_dltDelta[k + drop];
   }
   ArrayResize(g_dltTime,  n);
   ArrayResize(g_dltHigh,  n);
   ArrayResize(g_dltLow,   n);
   ArrayResize(g_dltDelta, n);
   ArrayResize(g_dltCVD,   n);
}

// Поиск дельты бара по времени (для подтверждения входа). Возвращает false,
// если бар вне окна — тогда фильтр трактуется мягко (не блокирует сигнал).
bool LookupDelta(datetime t, double &val)
{
   int sz = ArraySize(g_dltTime);
   if(sz == 0) return false;
   if(t < g_dltTime[0] || t > g_dltTime[sz - 1]) return false;
   for(int k = sz - 1; k >= 0; --k)
      if(g_dltTime[k] == t) { val = g_dltDelta[k]; return true; }
   return false;
}

string FormatSigned(double v)
{
   string s = (v >= 0 ? "+" : "-");
   double a = MathAbs(v);
   if(a >= 1000000.0) return s + DoubleToString(a / 1000000.0, 2) + "M";
   if(a >= 1000.0)    return s + DoubleToString(a / 1000.0, 1)    + "K";
   return s + DoubleToString(a, 0);
}

void UpdateDelta(const datetime &time[], const double &high[], const double &low[], int rates_total)
{
   if(!InpDeltaEnable)
   {
      if(!g_dltCleared)
      {
         ClearDeltaObjects();
         ResetDelta();
         g_dltCleared = true;
      }
      return;
   }
   g_dltCleared = false;

   int lastClosed = rates_total - 2;        // последний полностью закрытый бар
   if(lastClosed < 5) return;
   int n = (int)MathMin(InpDeltaLookback, lastClosed);
   if(n < 5) return;

   int sz = ArraySize(g_dltTime);
   if(sz == 0)
   {
      // Полная сборка окна
      int winStart = lastClosed - n + 1;
      for(int b = winStart; b <= lastClosed; ++b)
         DeltaAppendBar(b, time, high, low);
   }
   else if(g_dltTime[sz - 1] != time[lastClosed])
   {
      // Инкрементально добавляем только новые закрытые бары
      datetime lastStored = g_dltTime[sz - 1];
      int b0 = lastClosed;
      while(b0 > 1 && time[b0 - 1] > lastStored) b0--;
      for(int b = b0; b <= lastClosed; ++b)
         DeltaAppendBar(b, time, high, low);
      DeltaTrim(n);
   }

   // Пересчёт кумулятивной дельты внутри окна
   double run = 0.0;
   int wsz = ArraySize(g_dltDelta);
   for(int k = 0; k < wsz; ++k)
   {
      run += g_dltDelta[k];
      g_dltCVD[k] = run;
   }
   g_dltCVDLast = run;

   // Дельта текущего (формирующегося) бара — для дашборда
   bool okc = false;
   g_dltCurDelta = ComputeBarDelta(time[rates_total - 1], TimeCurrent() + 1, okc);

   // Подписи дельты под барами (опционально)
   ClearTagObjects(InpObjPrefix + "dlt_b_");
   if(InpDeltaShowBars)
      DrawDeltaBars();

   // Дивергенции цена/CVD
   DetectCVDDivergence();
}

void DrawDeltaBars()
{
   int wsz = ArraySize(g_dltTime);
   for(int k = 0; k < wsz; ++k)
   {
      string nm = InpObjPrefix + "dlt_b_" + IntegerToString((long)g_dltTime[k]);
      double y  = g_dltLow[k];
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_TEXT, 0, g_dltTime[k], y);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  g_dltTime[k]);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, y);
      ObjectSetString (0, nm, OBJPROP_TEXT,  FormatSigned(g_dltDelta[k]));
      ObjectSetString (0, nm, OBJPROP_FONT,  "Consolas");
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, InpDeltaFontSize);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, g_dltDelta[k] >= 0 ? InpDeltaBullColor : InpDeltaBearColor);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   }
}

// Регулярная дивергенция между ценой и кумулятивной дельтой (CVD)
void DetectCVDDivergence()
{
   g_dltDivState = 0;
   ClearTagObjects(InpObjPrefix + "dlt_div");
   if(!InpDeltaShowDiv) return;

   int wsz = ArraySize(g_dltLow);
   int L = MathMax(1, InpDeltaDivSwing);
   if(wsz < 2 * L + 3) return;

   // Сбор индексов свинговых лоёв и хаёв (хронологически: старые -> новые)
   int lowIdx[];  ArrayResize(lowIdx, 0);
   int highIdx[]; ArrayResize(highIdx, 0);
   for(int i = L; i <= wsz - L - 1; ++i)
   {
      bool isLow = true, isHigh = true;
      for(int k = 1; k <= L; ++k)
      {
         if(g_dltLow[i]  >= g_dltLow[i - k]  || g_dltLow[i]  >= g_dltLow[i + k])  isLow  = false;
         if(g_dltHigh[i] <= g_dltHigh[i - k] || g_dltHigh[i] <= g_dltHigh[i + k]) isHigh = false;
      }
      if(isLow)  { int s = ArraySize(lowIdx);  ArrayResize(lowIdx,  s + 1); lowIdx[s]  = i; }
      if(isHigh) { int s = ArraySize(highIdx); ArrayResize(highIdx, s + 1); highIdx[s] = i; }
   }

   int recentBull = -1, recentBear = -1;

   // Бычья: цена LL, CVD HL
   int nl = ArraySize(lowIdx);
   if(nl >= 2)
   {
      int p = lowIdx[nl - 2];  // предыдущий
      int r = lowIdx[nl - 1];  // самый свежий
      if(g_dltLow[r] < g_dltLow[p] && g_dltCVD[r] > g_dltCVD[p])
         recentBull = r;
   }
   // Медвежья: цена HH, CVD LH
   int nh = ArraySize(highIdx);
   if(nh >= 2)
   {
      int p = highIdx[nh - 2];
      int r = highIdx[nh - 1];
      if(g_dltHigh[r] > g_dltHigh[p] && g_dltCVD[r] < g_dltCVD[p])
         recentBear = r;
   }

   // Берём только свежие дивергенции
   int recencyFrom = wsz - 1 - MathMax(1, InpDeltaDivRecent);
   if(recentBull >= 0 && recentBull < recencyFrom) recentBull = -1;
   if(recentBear >= 0 && recentBear < recencyFrom) recentBear = -1;

   // Если обе — берём более свежую
   bool drawBull = (recentBull >= 0) && (recentBear < 0 || recentBull >= recentBear);
   bool drawBear = (recentBear >= 0) && (recentBull < 0 || recentBear >  recentBull);

   if(drawBull)
   {
      int p = lowIdx[ArraySize(lowIdx) - 2];
      int r = lowIdx[ArraySize(lowIdx) - 1];
      DrawDivergence(true, g_dltTime[p], g_dltLow[p], g_dltTime[r], g_dltLow[r]);
      g_dltDivState = 1;
      if(g_dltTime[r] != g_dltDivTime) { g_cnt.dltDivBull++; g_dltDivTime = g_dltTime[r]; if(InpDeltaAlertDiv) DeltaDivAlert(true, g_dltTime[r]); }
   }
   else if(drawBear)
   {
      int p = highIdx[ArraySize(highIdx) - 2];
      int r = highIdx[ArraySize(highIdx) - 1];
      DrawDivergence(false, g_dltTime[p], g_dltHigh[p], g_dltTime[r], g_dltHigh[r]);
      g_dltDivState = -1;
      if(g_dltTime[r] != g_dltDivTime) { g_cnt.dltDivBear++; g_dltDivTime = g_dltTime[r]; if(InpDeltaAlertDiv) DeltaDivAlert(false, g_dltTime[r]); }
   }
}

void DrawDivergence(bool bull, datetime t1, double p1, datetime t2, double p2)
{
   string nm = InpObjPrefix + "dlt_divLine";
   color  clr = bull ? InpDeltaBullColor : InpDeltaBearColor;
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, nm, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, nm, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nm, OBJPROP_BACK, false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);

   string lbl = InpObjPrefix + "dlt_divLbl";
   if(ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_TEXT, 0, t2, p2);
   ObjectSetInteger(0, lbl, OBJPROP_TIME,  t2);
   ObjectSetDouble (0, lbl, OBJPROP_PRICE, p2);
   ObjectSetString (0, lbl, OBJPROP_TEXT,  bull ? "  CVD div ▲" : "  CVD div ▼");
   ObjectSetString (0, lbl, OBJPROP_FONT,  "Consolas");
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, MathMax(7, InpDeltaFontSize + 1));
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, bull ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lbl, OBJPROP_HIDDEN, true);
}

void DeltaDivAlert(bool bull, datetime t)
{
   if(TimeCurrent() - t > PeriodSeconds() * 3) return;
   Alert(_Symbol, " ", EnumToString(_Period), " CVD divergence ", (bull ? "BULL" : "BEAR"),
         " @ ", TimeToString(t, TIME_DATE | TIME_MINUTES));
}

//+==================================================================+
//| DASHBOARD                                                          |
//+==================================================================+
void DashboardCreate()
{
   string nm = InpObjPrefix + "dash_bg";
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nm, OBJPROP_CORNER,    InpDashCorner);
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, InpDashX);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, InpDashY);
   ObjectSetInteger(0, nm, OBJPROP_XSIZE,     InpDashWidth);
   ObjectSetInteger(0, nm, OBJPROP_YSIZE,     280);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR,   InpDashBgColor);
   ObjectSetInteger(0, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, nm, OBJPROP_COLOR,     clrDarkSlateGray);
   ObjectSetInteger(0, nm, OBJPROP_BACK,      false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN,    true);
}

void ClearDashboard()
{
   string p = InpObjPrefix + "dash_";
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, p) == 0) ObjectDelete(0, nm);
   }
}

void DashLineSet(int row, string text, color clr)
{
   string nm = InpObjPrefix + "dash_l" + IntegerToString(row);
   if(ObjectFind(0, nm) < 0)
   {
      ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_CORNER, InpDashCorner);
      int xPad = 12, yPad = 8;
      int rowHeight = InpDashFontSize + 5;
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, InpDashX + xPad);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, InpDashY + yPad + row * rowHeight);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, InpDashFontSize);
      ObjectSetString (0, nm, OBJPROP_FONT,     InpDashFont);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN,   true);
      bool rightCorner = (InpDashCorner == CORNER_RIGHT_UPPER || InpDashCorner == CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, rightCorner ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER);
   }
   ObjectSetString (0, nm, OBJPROP_TEXT,  text);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
}

// Создаёт каркас дашборда (один раз)
void DashboardLayout()
{
   // На случай, если параметры панели изменились — задаём фон заново
   string bg = InpObjPrefix + "dash_bg";
   if(ObjectFind(0, bg) >= 0)
   {
      ObjectSetInteger(0, bg, OBJPROP_CORNER,    InpDashCorner);
      ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, InpDashX);
      ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, InpDashY);
      ObjectSetInteger(0, bg, OBJPROP_XSIZE,     InpDashWidth);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR,   InpDashBgColor);
   }
}

void DashboardUpdate()
{
   string trendStr = TrendStr(g_state.trend);
   color  trendClr = TrendColor(g_state.trend);

   int row = 0;
   DashLineSet(row++, _Symbol + "  " + EnumToString(_Period),                                InpDashAccent);
   DashLineSet(row++, "─────────────────────",                                                InpDashTextColor);
   DashLineSet(row++, "Тренд " + EnumToString(_Period) + ":  " + trendStr,                   trendClr);

   if(InpMTFEnable)
   {
      string mtfStr = TrendStr(g_mtfState.trend);
      color  mtfClr = TrendColor(g_mtfState.trend);
      DashLineSet(row++, "Тренд " + EnumToString(InpMTFPeriod) + ":  " + mtfStr,             mtfClr);
   }

   DashLineSet(row++, "─ Структура ─",                                                         InpDashAccent);
   DashLineSet(row++, StringFormat("BOS    +%d  / -%d",   g_cnt.bosBull,   g_cnt.bosBear),    InpDashTextColor);
   DashLineSet(row++, StringFormat("CHoCH  +%d  / -%d",   g_cnt.chochBull, g_cnt.chochBear),  InpDashTextColor);
   DashLineSet(row++, StringFormat("Sweeps +%d  / -%d",   g_cnt.sweepBull, g_cnt.sweepBear),  InpDashTextColor);
   DashLineSet(row++, StringFormat("HH/HL  %d / %d",      g_cnt.swingsHH,  g_cnt.swingsHL),   InpDashTextColor);
   DashLineSet(row++, StringFormat("LH/LL  %d / %d",      g_cnt.swingsLH,  g_cnt.swingsLL),   InpDashTextColor);

   if(InpMTFEnable)
   {
      DashLineSet(row++, "─ MTF структура ─",                                                  InpDashAccent);
      DashLineSet(row++, StringFormat("BOS    +%d  / -%d", g_cnt.mtfBosBull,   g_cnt.mtfBosBear),   InpDashTextColor);
      DashLineSet(row++, StringFormat("CHoCH  +%d  / -%d", g_cnt.mtfChochBull, g_cnt.mtfChochBear), InpDashTextColor);
   }

   DashLineSet(row++, "─ Зоны ─",                                                              InpDashAccent);
   DashLineSet(row++, StringFormat("OB+   active %d  mit %d  strong %d", g_cnt.obBullActive, g_cnt.obBullMit, g_cnt.obStrongBull), InpDashTextColor);
   DashLineSet(row++, StringFormat("OB-   active %d  mit %d  strong %d", g_cnt.obBearActive, g_cnt.obBearMit, g_cnt.obStrongBear), InpDashTextColor);
   DashLineSet(row++, StringFormat("FVG   +%d  / -%d",        g_cnt.fvgBull,      g_cnt.fvgBear),   InpDashTextColor);

   if(InpLiqLevelsEnable)
   {
      int liqB = 0, liqS = 0;
      for(int q = 0; q < ArraySize(g_liq); ++q)
      {
         if(g_liq[q].swept) continue;
         if(g_liq[q].buySide) liqB++; else liqS++;
      }
      DashLineSet(row++, "─ Ликвидность ─",                                                         InpDashAccent);
      DashLineSet(row++, StringFormat("BSL %d  / SSL %d  активны", liqB, liqS),                      InpDashTextColor);
      DashLineSet(row++, StringFormat("Снято %d   EQH %d / EQL %d", g_cnt.liqSwept, g_cnt.eqh, g_cnt.eql), InpDashTextColor);
   }

   DashLineSet(row++, "─ Объём ─",                                                             InpDashAccent);
   DashLineSet(row++, StringFormat("Громких +%d / -%d  (×%.2f)", g_cnt.hivolUp, g_cnt.hivolDn, InpVolumeMultiplier), InpDashTextColor);

   if(InpDeltaEnable)
   {
      color dClr = (g_dltCurDelta >= 0) ? InpDeltaBullColor : InpDeltaBearColor;
      color cClr = (g_dltCVDLast  >= 0) ? InpDeltaBullColor : InpDeltaBearColor;
      string dvs = (g_dltDivState == 1)  ? "BULL ▲"
                 : (g_dltDivState == -1) ? "BEAR ▼" : "—";
      color  dvc = (g_dltDivState == 1)  ? InpDeltaBullColor
                 : (g_dltDivState == -1) ? InpDeltaBearColor : InpDashTextColor;
      DashLineSet(row++, "─ Delta / CVD ─",                                                      InpDashAccent);
      DashLineSet(row++, "Δ бар:  " + FormatSigned(g_dltCurDelta),                               dClr);
      DashLineSet(row++, StringFormat("CVD(%d):  %s", ArraySize(g_dltCVD), FormatSigned(g_dltCVDLast)), cClr);
      DashLineSet(row++, "Дивергенция:  " + dvs,                                                  dvc);
   }

   if(InpEntryEnable)
   {
      DashLineSet(row++, "─ Entry signals ─",                                                   InpDashAccent);
      DashLineSet(row++, StringFormat("BUY  %d   /   SELL  %d", g_cnt.entryUp, g_cnt.entryDn),  InpDashTextColor);
      string mode = InpEntryUseScore
                    ? StringFormat("score >= %d", InpEntryMinScore)
                    : "AND-gates";
      string flt = "";
      if(InpEntryNeedPremDisc) flt += "PD ";
      if(InpEntryNeedStrongOB) flt += "strOB ";
      if(InpEntryNeedReject)   flt += "rej ";
      if(InpEntryNeedGrabChoCH) flt += "G→C ";
      if(InpEntryNeedRR || InpEntryMinRR > 0)
         flt += StringFormat("RR>=%.1f ", InpEntryMinRR);
      if(InpEntryCooldownBars > 0) flt += StringFormat("cd%d ", InpEntryCooldownBars);
      DashLineSet(row++, "Mode: " + mode,                                                       InpDashTextColor);
      if(StringLen(flt) > 0)
         DashLineSet(row++, "Filt: " + flt,                                                     InpDashTextColor);
   }

   if(InpVPEnable)
   {
      ENUM_TIMEFRAMES vpTF = (InpVPTimeframe == PERIOD_CURRENT) ? _Period : InpVPTimeframe;
      DashLineSet(row++, "─ Volume Profile ─",                                                  InpDashAccent);
      DashLineSet(row++, StringFormat("TF: %s  rows: %d  N: %d", EnumToString(vpTF), InpVPRows, InpVPLookback), InpDashTextColor);
   }

   // Скрываем «лишние» строки от прошлых конфигураций (если стало меньше rows)
   for(int extra = row; extra < 48; ++extra)
   {
      string nm = InpObjPrefix + "dash_l" + IntegerToString(extra);
      if(ObjectFind(0, nm) >= 0)
         ObjectSetString(0, nm, OBJPROP_TEXT, "");
   }

   // Подгоняем размер фона
   int rowHeight = InpDashFontSize + 5;
   int yPad = 16;
   ObjectSetInteger(0, InpObjPrefix + "dash_bg", OBJPROP_YSIZE, yPad + row * rowHeight);
   ObjectSetInteger(0, InpObjPrefix + "dash_bg", OBJPROP_XSIZE, InpDashWidth);
}

string TrendStr(int t)
{
   if(t == 1)  return "BULL ▲";
   if(t == -1) return "BEAR ▼";
   return "FLAT ─";
}

color TrendColor(int t)
{
   if(t == 1)  return InpBullColor;
   if(t == -1) return InpBearColor;
   return clrSilver;
}

//+==================================================================+
//| VOLUME PROFILE                                                     |
//+==================================================================+
void BuildVolumeProfile()
{
   ClearVPObjects();
   if(!InpVPEnable) return;
   if(InpVPRows < 2 || InpVPLookback < 5) return;

   ENUM_TIMEFRAMES tf = (InpVPTimeframe == PERIOD_CURRENT) ? _Period : InpVPTimeframe;

   double   h[], l[], c[];
   long     v[];
   datetime t[];

   int n = CopyHigh(_Symbol, tf, 0, InpVPLookback, h);
   if(n <= 0) return;
   if(CopyLow  (_Symbol, tf, 0, InpVPLookback, l) <= 0) return;
   if(CopyClose(_Symbol, tf, 0, InpVPLookback, c) <= 0) return;
   if(CopyTime (_Symbol, tf, 0, InpVPLookback, t) <= 0) return;
   if(InpVolumeType == VOLUME_REAL)
   {
      if(CopyRealVolume(_Symbol, tf, 0, InpVPLookback, v) <= 0) return;
   }
   else
   {
      if(CopyTickVolume(_Symbol, tf, 0, InpVPLookback, v) <= 0) return;
   }

   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);
   ArraySetAsSeries(t, false);
   ArraySetAsSeries(v, false);

   // Диапазон цен
   double pmin = l[0], pmax = h[0];
   for(int i = 0; i < n; ++i)
   {
      if(h[i] > pmax) pmax = h[i];
      if(l[i] < pmin) pmin = l[i];
   }
   if(pmax <= pmin) return;

   int rows = InpVPRows;
   double rowH = (pmax - pmin) / rows;
   if(rowH <= 0) return;

   double bins[];
   ArrayResize(bins, rows);
   ArrayInitialize(bins, 0.0);

   double totalVol = 0;
   for(int i = 0; i < n; ++i)
   {
      double bh = h[i], bl = l[i];
      double barVol = (double)v[i];
      int rowFrom = (int)MathFloor((bl - pmin) / rowH);
      int rowTo   = (int)MathFloor((bh - pmin) / rowH);
      if(rowFrom < 0)        rowFrom = 0;
      if(rowTo   >= rows)    rowTo   = rows - 1;
      int span = rowTo - rowFrom + 1;
      if(span <= 0) continue;
      double share = barVol / span;
      for(int r = rowFrom; r <= rowTo; ++r)
      {
         bins[r] += share;
         totalVol += share;
      }
   }
   if(totalVol <= 0) return;

   // POC
   int    pocIdx = 0;
   double pocVol = bins[0];
   for(int i = 1; i < rows; ++i)
      if(bins[i] > pocVol) { pocVol = bins[i]; pocIdx = i; }

   // Value Area: расширяем от POC, выбирая большую соседнюю зону
   int    vaLow  = pocIdx;
   int    vaHigh = pocIdx;
   double vaSum  = bins[pocIdx];
   double target = totalVol * InpVPValueArea;
   while(vaSum < target && (vaLow > 0 || vaHigh < rows - 1))
   {
      double up = (vaHigh < rows - 1) ? bins[vaHigh + 1] : -1;
      double dn = (vaLow  > 0)        ? bins[vaLow  - 1] : -1;
      if(up >= dn && up >= 0) { vaHigh++; vaSum += bins[vaHigh]; }
      else if(dn >= 0)        { vaLow--;  vaSum += bins[vaLow];  }
      else break;
   }

   // Координаты по времени
   datetime anchor;
   long widthSecs;
   ComputeVPAnchor(tf, anchor, widthSecs);
   if(widthSecs <= 0) return;

   for(int i = 0; i < rows; ++i)
   {
      if(bins[i] <= 0) continue;
      double rowLow = pmin + i * rowH;
      double rowHi  = pmin + (i + 1) * rowH;
      double frac   = bins[i] / pocVol;
      if(frac > 1.0) frac = 1.0;
      long   extent = (long)((double)widthSecs * frac);
      if(extent < PeriodSeconds(_Period)) extent = PeriodSeconds(_Period);

      datetime t1, t2;
      if(InpVPRightSide)
      {
         t2 = anchor;
         t1 = anchor - (datetime)extent;
      }
      else
      {
         t1 = anchor;
         t2 = anchor + (datetime)extent;
      }

      color clr = InpVPColor;
      if(i == pocIdx && InpVPShowPoc)        clr = InpVPPocColor;
      else if(i >= vaLow && i <= vaHigh && InpVPShowVa) clr = InpVPVaColor;

      string nm = InpObjPrefix + "vp_row_" + IntegerToString(i);
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, rowLow, t2, rowHi);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  0, t1);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, rowLow);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  1, t2);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, rowHi);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, nm, OBJPROP_FILL,  true);
      ObjectSetInteger(0, nm, OBJPROP_BACK,  true);
      ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   }

   // POC / VAH / VAL линии
   double pocPrice = pmin + (pocIdx + 0.5) * rowH;
   double vahPrice = pmin + (vaHigh + 1) * rowH;
   double valPrice = pmin + vaLow * rowH;
   g_pocPrice = pocPrice;
   g_vahPrice = vahPrice;
   g_valPrice = valPrice;
   g_vpReady  = true;

   if(InpVPShowPoc)
   {
      DrawVPLine("vp_poc", pocPrice, InpVPPocColor, STYLE_DOT,  "POC " + DoubleToString(pocPrice, _Digits));
   }
   if(InpVPShowVa)
   {
      DrawVPLine("vp_vah", vahPrice, InpVPVaColor, STYLE_DASH, "VAH " + DoubleToString(vahPrice, _Digits));
      DrawVPLine("vp_val", valPrice, InpVPVaColor, STYLE_DASH, "VAL " + DoubleToString(valPrice, _Digits));
   }
}

void ComputeVPAnchor(ENUM_TIMEFRAMES tf, datetime &anchor, long &widthSecs)
{
   anchor = iTime(_Symbol, _Period, 0);
   if(anchor == 0) anchor = TimeCurrent();

   long visible = ChartGetInteger(0, CHART_VISIBLE_BARS);
   if(visible <= 0) visible = 100;
   widthSecs = (long)((double)visible * (double)PeriodSeconds(_Period) * (InpVPWidthPct / 100.0));
   if(widthSecs <= 0) widthSecs = PeriodSeconds(_Period) * 10;
}

void DrawVPLine(string tag, double price, color clr, int style, string text)
{
   string nm = InpObjPrefix + tag;
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble (0, nm, OBJPROP_PRICE,   price);
   ObjectSetInteger(0, nm, OBJPROP_COLOR,   clr);
   ObjectSetInteger(0, nm, OBJPROP_STYLE,   style);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH,   1);
   ObjectSetString (0, nm, OBJPROP_TEXT,    text);
   ObjectSetString (0, nm, OBJPROP_TOOLTIP, text);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
}

void ClearVPObjects()
{
   string vpPrefix = InpObjPrefix + "vp_";
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, vpPrefix) == 0)
         ObjectDelete(0, nm);
   }
}
//+------------------------------------------------------------------+
