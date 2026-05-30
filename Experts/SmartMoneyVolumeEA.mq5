//+------------------------------------------------------------------+
//|                                          SmartMoneyVolumeEA.mq5   |
//|   Автоматический советник на базе индикатора SmartMoneyVolume     |
//|   Архитектура "мост": EA загружает индикатор через iCustom,       |
//|   читает его Entry-буферы (стрелки точки входа) и исполняет        |
//|   сделки с расчётом объёма по риску, безубытком и трейлингом.      |
//|                                            Copyright 2026 Mago201 |
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.00"
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
//| ПАРАМЕТРЫ ИНДИКАТОРА SmartMoneyVolume                             |
//| (передаются в iCustom в ТОЧНО ТОМ ЖЕ порядке, что объявлены в     |
//|  индикаторе — менять порядок нельзя!)                            |
//+==================================================================+
input group "=== Структура (Swing / BOS / CHoCH) ==="
input int      InpSwingLength      = 5;             // Длина свинга (баров слева/справа)
input bool     InpShowSwings       = true;          // Метки HH/HL/LH/LL
input bool     InpShowBOS          = true;          // Линии BOS
input bool     InpShowCHOCH        = true;          // Линии CHoCH
input color    InpBullColor        = clrLime;       // Цвет бычьих структур
input color    InpBearColor        = clrRed;        // Цвет медвежьих структур

input group "=== Order Blocks + Mitigation ==="
input bool     InpShowOB           = true;          // Показывать ордер-блоки (нужно для entry!)
input int      InpOBMaxCount       = 5;             // Максимум активных OB на сторону
input color    InpBullOBColor      = clrSeaGreen;   // Цвет бычьего OB
input color    InpBearOBColor      = clrCrimson;    // Цвет медвежьего OB
input int      InpOBExtendBars     = 30;            // Длина OB вправо (в барах)
input bool     InpOBHideMitigated  = false;         // Скрывать сработавшие OB
input color    InpOBMitigatedClr   = clrDimGray;    // Цвет сработавшего OB
input bool     InpOBExtendOnTouch  = true;          // Обрезать OB по моменту касания

input group "=== Fair Value Gaps ==="
input bool     InpShowFVG          = true;          // Показывать FVG / имбалансы
input int      InpFVGMaxCount      = 10;            // Максимум активных FVG на сторону
input color    InpBullFVGColor     = clrDarkGreen;
input color    InpBearFVGColor     = clrDarkRed;
input int      InpFVGExtendBars    = 20;

input group "=== Liquidity Sweeps ==="
input bool     InpShowLiquidity    = true;          // Нужно для sweep/grab-условий entry!
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
input bool     InpShowVolume       = true;          // Нужно для volume-условия entry!
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK;
input int      InpVolumePeriod     = 20;
input double   InpVolumeMultiplier = 1.8;
input bool     InpShowVolText      = false;
input color    InpVolTextColor     = clrSilver;

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
input bool     InpEntryEnable        = true;        // ДОЛЖНО быть true — иначе сигналов нет
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
input int      InpEntryATRPeriod         = 14;      // Период ATR (индикатора)
input bool     InpEntryUseVPForTP        = true;    // Учитывать POC/VAH/VAL как кандидатов TP

input bool     InpEntryShowLevels        = true;    // Рисовать SL/TP1/TP2 у стрелки
input color    InpEntrySLColor           = clrCrimson;
input color    InpEntryTPColor           = clrSeaGreen;
input int      InpEntryLevelsBars        = 12;      // Длина пунктиров SL/TP вправо (баров)
input bool     InpEntryShowLabel         = true;    // Подпись у стрелки (score / RR)

input int      InpEntryCooldownBars      = 0;       // Cooldown между сигналами одного направления (0=выкл)
input double   InpEntryMinDistATR        = 0.0;     // Мин. дистанция от прошлого сигнала, в ATR (0=выкл)

input group "=== Entry: Liquidity grab -> CHoCH ==="
input bool     InpEntryNeedGrabChoCH = false;      // Требовать паттерн: снятие ликвидности -> CHoCH в обратную сторону
input int      InpEntryGrabMaxBars   = 8;          // Макс. баров между снятием ликвидности и CHoCH

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
input int      InpEntryWeightGrabChoCH   = 3;       // Вес: liquidity grab -> CHoCH

input group "=== Производительность (индикатора) ==="
input int      InpHistoryBars      = 1500;        // Глубина истории для анализа (0 = вся; 0 НЕ рекомендую)
input bool     InpHeavyOnNewBarOnly= true;        // Тяжёлые задачи только на новом баре
input bool     InpProcessUnclosed  = false;       // Обрабатывать объёмы на текущем (незакрытом) баре

input group "=== Прочее (индикатора) ==="
input string   InpObjPrefix        = "SMV_";
input bool     InpAlertOnBOS       = false;
input bool     InpAlertOnSweep     = false;

//+==================================================================+
//| ПАРАМЕТРЫ СОВЕТНИКА (исполнение и риск-менеджмент)                |
//+==================================================================+
input group "=== СОВЕТНИК: SL/TP (ATR) ==="
input int    InpAtrPeriod    = 14;           // Период ATR советника (для SL/TP)
input double InpSLATR        = 1.50;         // SL = ATR * множитель
input double InpRR           = 1.50;         // R:R (TP = риск * RR)

input group "=== СОВЕТНИК: управление капиталом ==="
input ENUM_RISK_MODE InpRiskMode = RISK_PERCENT;  // Режим расчёта объёма
input double InpFixedLots     = 0.10;        // Фиксированный лот (для RISK_FIXED_LOT)
input double InpRiskPercent   = 1.0;         // Риск на сделку, % от баланса (для RISK_PERCENT)
input double InpMaxLots       = 0.0;         // Ограничение макс. лота (0=только биржевой максимум)

input group "=== СОВЕТНИК: управление позицией ==="
input int    InpMaxPositions  = 1;           // Макс. одновременно открытых позиций (по этому EA)
input bool   InpCloseOnReverse= true;        // Закрывать противоположную позицию при встречном сигнале
input bool   InpUseBreakeven  = true;        // Перевод в безубыток
input double InpBeTriggerR    = 0.70;        // Безубыток при прибыли >= R
input double InpBeLockR       = 0.05;        // Зафиксировать прибыль (в R) при безубытке
input bool   InpUseTrailing   = false;       // Трейлинг-стоп
input double InpTrailStartR   = 1.00;        // Старт трейлинга при прибыли >= R
input double InpTrailDistR    = 1.00;        // Дистанция трейлинга (в R от текущей цены)

input group "=== СОВЕТНИК: фильтры и лимиты ==="
input int    InpMaxTradesPerDay = 0;         // Макс. входов в день (0=без лимита)
input bool   InpUseSession      = false;     // Доп. фильтр сессии на уровне EA
input int    InpSessStartHour   = 8;         // Старт окна (час сервера)
input int    InpSessEndHour     = 21;        // Конец окна (час сервера)
input int    InpMaxSpreadPts    = 0;         // Макс. спред в пунктах сейчас (0=выкл)
input int    InpCooldownBars    = 0;         // Пауза между входами EA, баров (0=выкл)

input group "=== СОВЕТНИК: исполнение ==="
input long   InpMagic        = 26012027;     // Magic number
input int    InpSlippagePts  = 20;           // Допустимое проскальзывание (пункты)
input string InpComment      = "SmartMoneyVolume";  // Комментарий к ордерам
input bool   InpSymbolGuard  = false;        // Предупреждать, если символ не похож на золото
input string InpIndicatorName = "SmartMoneyVolume"; // Имя индикатора для iCustom (в MQL5/Indicators)

//+==================================================================+
//| ГЛОБАЛЬНЫЕ ОБЪЕКТЫ И ПЕРЕМЕННЫЕ                                    |
//+==================================================================+
CTrade   trade;

int      gIndHandle = INVALID_HANDLE;        // хендл индикатора (iCustom)
int      gAtrHandle = INVALID_HANDLE;        // ATR советника

#define  BUF_ENTRY_UP  2                      // индекс буфера EntryUp в индикаторе
#define  BUF_ENTRY_DN  3                      // индекс буфера EntryDn в индикаторе

datetime gLastBarTime    = 0;                 // детект нового бара
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
   // --- ATR советника
   gAtrHandle = iATR(_Symbol, _Period, MathMax(2, InpAtrPeriod));
   if(gAtrHandle == INVALID_HANDLE)
   {
      Print("SmartMoneyVolumeEA: не удалось создать ATR-хендл");
      return(INIT_FAILED);
   }

   // --- индикатор через iCustom (порядок параметров строго как в индикаторе!)
   gIndHandle = iCustom(_Symbol, _Period, InpIndicatorName,
      InpSwingLength,InpShowSwings,InpShowBOS,InpShowCHOCH,InpBullColor,InpBearColor,
      InpShowOB,InpOBMaxCount,InpBullOBColor,InpBearOBColor,InpOBExtendBars,InpOBHideMitigated,
      InpOBMitigatedClr,InpOBExtendOnTouch,InpShowFVG,InpFVGMaxCount,InpBullFVGColor,InpBearFVGColor,
      InpFVGExtendBars,InpShowLiquidity,InpLiquidityColor,InpLiqLevelsEnable,InpLiqShowLines,InpLiqBuyColor,
      InpLiqSellColor,InpLiqLineStyle,InpLiqLineWidth,InpLiqMaxPerSide,InpLiqRemoveOnSweep,InpLiqSweptColor,
      InpLiqShowLabels,InpLiqExtendActive,InpLiqAlert,InpLiqAlertPush,InpLiqShowEqual,InpLiqEqualColor,
      InpLiqEqualTolATR,InpLiqShowDaily,InpLiqDailyColor,InpLiqShowSessions,InpLiqAsiaColor,InpLiqLondonColor,
      InpLiqNYColor,InpLiqAsiaStart,InpLiqAsiaEnd,InpLiqLondonStart,InpLiqLondonEnd,InpLiqNYStart,
      InpLiqNYEnd,InpHighlightUntested,InpUntestedColor,InpUntestedApplyOB,InpUntestedApplyLiq,InpShowVolume,
      InpVolumeType,InpVolumePeriod,InpVolumeMultiplier,InpShowVolText,InpVolTextColor,InpMTFEnable,
      InpMTFPeriod,InpMTFLookback,InpMTFShowSwings,InpMTFShowBOS,InpMTFShowCHOCH,InpMTFShowOB,
      InpMTFBullColor,InpMTFBearColor,InpMTFBullOBClr,InpMTFBearOBClr,InpMTFLineWidth,InpDashEnable,
      InpDashCorner,InpDashX,InpDashY,InpDashTextColor,InpDashBgColor,InpDashAccent,
      InpDashFontSize,InpDashFont,InpDashWidth,InpVPEnable,InpVPTimeframe,InpVPLookback,
      InpVPRows,InpVPWidthPct,InpVPColor,InpVPPocColor,InpVPVaColor,InpVPShowPoc,
      InpVPShowVa,InpVPValueArea,InpVPRightSide,InpEntryEnable,InpEntryNeedTrend,InpEntryNeedMTF,
      InpEntryNeedOB,InpEntryNeedVolume,InpEntryNeedSweep,InpEntryNeedStruct,InpEntryRecencyBars,InpEntryUpColor,
      InpEntryDnColor,InpEntryUpArrow,InpEntryDnArrow,InpEntryArrowWidth,InpEntryArrowShift,InpEntryAlert,
      InpEntryNeedPremDisc,InpEntryPremDiscMTF,InpEntryPremDiscMid,InpEntryPremDiscDelta,InpEntryNeedStrongOB,InpEntryOBImpulseMaxBars,
      InpEntryNeedReject,InpEntryNeedRR,InpEntryMinRR,InpEntrySLATRMult,InpEntryATRPeriod,InpEntryUseVPForTP,
      InpEntryShowLevels,InpEntrySLColor,InpEntryTPColor,InpEntryLevelsBars,InpEntryShowLabel,InpEntryCooldownBars,
      InpEntryMinDistATR,InpEntryNeedGrabChoCH,InpEntryGrabMaxBars,InpEntryUseScore,InpEntryMinScore,InpEntryWeightTrend,
      InpEntryWeightMTF,InpEntryWeightOB,InpEntryWeightStrongOB,InpEntryWeightVolume,InpEntryWeightSweep,InpEntryWeightStruct,
      InpEntryWeightPremDisc,InpEntryWeightRR,InpEntryWeightVPCnflu,InpEntryWeightReject,InpEntryWeightGrabChoCH,InpHistoryBars,
      InpHeavyOnNewBarOnly,InpProcessUnclosed,InpObjPrefix,InpAlertOnBOS,InpAlertOnSweep);

   if(gIndHandle == INVALID_HANDLE)
   {
      Print("SmartMoneyVolumeEA: не удалось создать хендл индикатора '", InpIndicatorName,
            "'. Убедитесь, что ", InpIndicatorName, ".ex5 скомпилирован в MQL5/Indicators.");
      return(INIT_FAILED);
   }

   if(!InpEntryEnable)
      Print("SmartMoneyVolumeEA: ВНИМАНИЕ — InpEntryEnable=false, индикатор не будет давать сигналов.");

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

   // Сигнал читаем КАЖДЫЙ тик (iCustom может пересчитаться позже OnTick),
   // защита от дублей — по времени бара сигнала (gLastSignalTime).
   CheckForSignal();
}

//+==================================================================+
//| Чтение entry-сигнала индикатора и вход                            |
//+==================================================================+
void CheckForSignal()
{
   // Индикатор подтверждает сигнал на баре спустя InpSwingLength баров:
   // last_confirmable = rates_total - InpSwingLength - 1  =>  shift = InpSwingLength.
   int sh = MathMax(1, InpSwingLength);

   // Готовность индикатора
   int calc = BarsCalculated(gIndHandle);
   if(calc <= sh + 2) return;

   double up[], dn[];
   if(CopyBuffer(gIndHandle, BUF_ENTRY_UP, sh, 1, up) != 1) return;
   if(CopyBuffer(gIndHandle, BUF_ENTRY_DN, sh, 1, dn) != 1) return;

   bool buy  = IsSignal(up[0]);
   bool sell = IsSignal(dn[0]);

   datetime sigBar = iTime(_Symbol, _Period, sh);

   // Прайминг: при первом запуске запоминаем уже существующий сигнал, но НЕ торгуем его
   if(!gPrimed)
   {
      gLastSignalTime = sigBar;
      gPrimed = true;
      return;
   }

   if(!buy && !sell) return;
   if(sigBar == gLastSignalTime) return;   // этот бар уже обработан
   gLastSignalTime = sigBar;

   // Доп. фильтры уровня EA
   if(InpUseSession && !InSession(iTime(_Symbol,_Period,0))) return;
   if(InpMaxSpreadPts > 0)
   {
      long spr = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spr > InpMaxSpreadPts) return;
   }
   if(InpCooldownBars > 0 && gLastEntryTime != 0)
   {
      int passed = BarsBetween(gLastEntryTime, curTimeSafe());
      if(passed < InpCooldownBars) return;
   }
   if(InpMaxTradesPerDay > 0 && gTradesToday >= InpMaxTradesPerDay) return;

   // Закрытие встречной позиции
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

datetime curTimeSafe()
{
   return(iTime(_Symbol,_Period,0));
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
