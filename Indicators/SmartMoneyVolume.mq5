//+------------------------------------------------------------------+
//|                                          SmartMoneyVolume.mq5    |
//|                Smart Money Concepts + Volume + MTF + Profile     |
//|                                            Copyright 2026 Mago201|
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.10"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plots: стрелки над/под высоко-объёмными барами
#property indicator_label1  "HighVolUp"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrYellow
#property indicator_width1  2

#property indicator_label2  "HighVolDn"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrange
#property indicator_width2  2

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

input group "=== Fair Value Gaps ==="
input bool     InpShowFVG          = true;          // Показывать FVG / имбалансы
input int      InpFVGMaxCount      = 10;            // Максимум активных FVG на сторону
input color    InpBullFVGColor     = clrDarkGreen;
input color    InpBearFVGColor     = clrDarkRed;
input int      InpFVGExtendBars    = 20;

input group "=== Liquidity Sweeps ==="
input bool     InpShowLiquidity    = true;
input color    InpLiquidityColor   = clrGold;

input group "=== Анализ объёмов ==="
input bool     InpShowVolume       = true;          // Подсветка объёмных свечей
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

input group "=== Прочее ==="
input string   InpObjPrefix        = "SMV_";
input bool     InpAlertOnBOS       = false;
input bool     InpAlertOnSweep     = false;

//+==================================================================+
//| ТИПЫ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ                                      |
//+==================================================================+
double BufHighVolUp[];
double BufHighVolDn[];

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
};

SwingState g_state;
SwingState g_mtfState;
datetime   g_mtfLastTime  = 0;
datetime   g_lastVPTime   = 0;
ENUM_TIMEFRAMES g_lastVPPeriod = PERIOD_CURRENT;
OBData     g_obs[];
Counters   g_cnt;
DrawCtx    g_ctx;
DrawCtx    g_ctxMTF;

//+==================================================================+
//| OnInit / OnDeinit                                                 |
//+==================================================================+
int OnInit()
{
   SetIndexBuffer(0, BufHighVolUp, INDICATOR_DATA);
   SetIndexBuffer(1, BufHighVolDn, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetDouble (0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -10);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT,  10);
   ArraySetAsSeries(BufHighVolUp, false);
   ArraySetAsSeries(BufHighVolDn, false);

   IndicatorSetString(INDICATOR_SHORTNAME, "SmartMoney+Volume MTF");

   InitContexts();
   ResetState(g_state);
   ResetState(g_mtfState);
   ResetCounters();
   ArrayResize(g_obs, 0);
   g_mtfLastTime = 0;
   g_lastVPTime  = 0;
   g_lastVPPeriod = PERIOD_CURRENT;

   ClearAllObjects();
   if(InpDashEnable) DashboardCreate();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
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

   int start;
   if(prev_calculated <= 0)
   {
      ArrayInitialize(BufHighVolUp, EMPTY_VALUE);
      ArrayInitialize(BufHighVolDn, EMPTY_VALUE);
      ResetState(g_state);
      ResetCounters();
      ArrayResize(g_obs, 0);
      ClearAllObjects();
      if(InpDashEnable) DashboardCreate();
      start = InpSwingLength;
   }
   else
   {
      start = prev_calculated - 1;
      if(start < InpSwingLength) start = InpSwingLength;
   }

   int last_confirmable = rates_total - InpSwingLength - 1;

   //--- Основной проход по текущему ТФ
   for(int i = start; i <= last_confirmable; ++i)
   {
      ProcessVolume(i, rates_total, time, open, close, high, low, tick_volume, volume);
      if(InpShowFVG && i >= 2)
         DetectFVG(i, time, high, low);
      DetectSwingGeneric(i, InpSwingLength,
                         time, open, high, low, close,
                         g_state, g_ctx, _Period, InpOBExtendBars, InpOBMaxCount);
   }

   //--- Незакрытые/неподтверждённые бары: только громкие свечи
   for(int i = last_confirmable + 1; i < rates_total; ++i)
   {
      BufHighVolUp[i] = EMPTY_VALUE;
      BufHighVolDn[i] = EMPTY_VALUE;
      ProcessVolume(i, rates_total, time, open, close, high, low, tick_volume, volume);
   }

   //--- Обновление mitigation для существующих OB
   if(InpShowOB)
      UpdateOBMitigation(time, high, low, rates_total);

   //--- MTF: пересчитываем при появлении нового бара старшего ТФ
   if(InpMTFEnable)
   {
      datetime curMTF = iTime(_Symbol, InpMTFPeriod, 0);
      if(curMTF != g_mtfLastTime)
      {
         ProcessMTF();
         g_mtfLastTime = curMTF;
      }
   }

   //--- Volume Profile: пересчёт при появлении нового бара
   datetime nowBar = time[rates_total - 1];
   if(InpVPEnable && (nowBar != g_lastVPTime || InpVPTimeframe != g_lastVPPeriod))
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

   //--- Dashboard
   if(InpDashEnable)
      DashboardUpdate();
   else
      ClearDashboard();

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

   if(isHigh) HandleSwingHigh(i, time, open, high, low, close,
                              state, ctx, tf, obExtendBars, obMaxCount);
   if(isLow ) HandleSwingLow (i, time, open, high, low, close,
                              state, ctx, tf, obExtendBars, obMaxCount);
}

void HandleSwingHigh(int i, const datetime &time[],
                     const double &open[], const double &high[],
                     const double &low[],  const double &close[],
                     SwingState &state, DrawCtx &ctx,
                     ENUM_TIMEFRAMES tf, int obExtendBars, int obMaxCount)
{
   bool isHH = state.lastH.valid && high[i] > state.lastH.price;
   string label = isHH ? "HH" : "LH";
   if(ctx.showSwings)
      DrawSwingLabel(time[i], high[i], label, true, ctx);
   if(!ctx.isMTF) { if(isHH) g_cnt.swingsHH++; else g_cnt.swingsLH++; }

   // BOS bull
   if(state.lastH.valid && ctx.showBOS && state.trend != -1 && high[i] > state.lastH.price)
   {
      DrawStructureLine(state.lastH.time, state.lastH.price,
                        time[i], state.lastH.price, "BOS", true, ctx);
      state.trend = 1;
      AlertStructure("BOS bull", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfBosBull++; else g_cnt.bosBull++;

      if(ctx.showOB)
         TryDrawOB(i, true, time, open, high, low, close, ctx, tf, obExtendBars, obMaxCount);
   }
   // CHoCH bull (разворот из медвежьего тренда)
   else if(state.lastH.valid && ctx.showCHOCH && state.trend == -1 && high[i] > state.lastH.price)
   {
      DrawStructureLine(state.lastH.time, state.lastH.price,
                        time[i], state.lastH.price, "CHoCH", true, ctx);
      state.trend = 1;
      AlertStructure("CHoCH bull", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfChochBull++; else g_cnt.chochBull++;

      if(ctx.showOB)
         TryDrawOB(i, true, time, open, high, low, close, ctx, tf, obExtendBars, obMaxCount);
   }

   // Liquidity sweep — только для текущего ТФ
   if(!ctx.isMTF && ctx.showSweep && state.lastH.valid &&
      high[i] > state.lastH.price && close[i] < state.lastH.price)
   {
      DrawSweep(time[i], high[i], true);
      AlertSweep("Sweep high", time[i]);
      g_cnt.sweepBull++;
   }

   state.prevH = state.lastH;
   state.lastH.time  = time[i];
   state.lastH.price = high[i];
   state.lastH.valid = true;
}

void HandleSwingLow(int i, const datetime &time[],
                    const double &open[], const double &high[],
                    const double &low[],  const double &close[],
                    SwingState &state, DrawCtx &ctx,
                    ENUM_TIMEFRAMES tf, int obExtendBars, int obMaxCount)
{
   bool isLL = state.lastL.valid && low[i] < state.lastL.price;
   string label = isLL ? "LL" : "HL";
   if(ctx.showSwings)
      DrawSwingLabel(time[i], low[i], label, false, ctx);
   if(!ctx.isMTF) { if(isLL) g_cnt.swingsLL++; else g_cnt.swingsHL++; }

   // BOS bear
   if(state.lastL.valid && ctx.showBOS && state.trend != 1 && low[i] < state.lastL.price)
   {
      DrawStructureLine(state.lastL.time, state.lastL.price,
                        time[i], state.lastL.price, "BOS", false, ctx);
      state.trend = -1;
      AlertStructure("BOS bear", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfBosBear++; else g_cnt.bosBear++;

      if(ctx.showOB)
         TryDrawOB(i, false, time, open, high, low, close, ctx, tf, obExtendBars, obMaxCount);
   }
   // CHoCH bear
   else if(state.lastL.valid && ctx.showCHOCH && state.trend == 1 && low[i] < state.lastL.price)
   {
      DrawStructureLine(state.lastL.time, state.lastL.price,
                        time[i], state.lastL.price, "CHoCH", false, ctx);
      state.trend = -1;
      AlertStructure("CHoCH bear", time[i], ctx.isMTF);
      if(ctx.isMTF) g_cnt.mtfChochBear++; else g_cnt.chochBear++;

      if(ctx.showOB)
         TryDrawOB(i, false, time, open, high, low, close, ctx, tf, obExtendBars, obMaxCount);
   }

   if(!ctx.isMTF && ctx.showSweep && state.lastL.valid &&
      low[i] < state.lastL.price && close[i] > state.lastL.price)
   {
      DrawSweep(time[i], low[i], false);
      AlertSweep("Sweep low", time[i]);
      g_cnt.sweepBear++;
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
//| Order Block                                                        |
//+==================================================================+
void TryDrawOB(int i, bool bull,
               const datetime &time[],
               const double &open[], const double &high[],
               const double &low[],  const double &close[],
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

   string tag  = bull ? "obB_" : "obS_";
   string name = ctx.prefix + tag + IntegerToString((long)t1);
   color  clr  = bull ? ctx.obBullClr : ctx.obBearClr;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, hi);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL,  true);
   ObjectSetInteger(0, name, OBJPROP_BACK,  true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

   // Регистрируем в массиве для трекинга mitigation
   AddOrUpdateOB(name, t1, hi, lo, t2, bull, ctx.isMTF);

   if(bull) g_cnt.obBullActive++;
   else     g_cnt.obBearActive++;

   // Лимит активных OB
   string limitTag = ctx.isMTF ? ("mtf_" + tag) : tag;
   LimitObjectsByTag(limitTag, obMaxCount, "");
}

void AddOrUpdateOB(string name, datetime t, double topP, double botP,
                   datetime extendTo, bool bull, bool mtf)
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
         return;
      }
   }
   int sz = ArraySize(g_obs);
   ArrayResize(g_obs, sz + 1);
   g_obs[sz].name      = name;
   g_obs[sz].time      = t;
   g_obs[sz].topPrice  = topP;
   g_obs[sz].botPrice  = botP;
   g_obs[sz].extendTo  = extendTo;
   g_obs[sz].bull      = bull;
   g_obs[sz].mtf       = mtf;
   g_obs[sz].mitigated = false;
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
   for(int idx = 0; idx < ArraySize(g_obs); ++idx)
   {
      if(g_obs[idx].mitigated) continue;
      if(g_obs[idx].mtf) continue; // MTF OB не трекаем по текущему ТФ

      int startBar = FindBarByTime(time, rates_total, g_obs[idx].time);
      if(startBar < 0) continue;
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

   if(CopyTime (_Symbol, InpMTFPeriod, 0, n, t) <= 0) return;
   if(CopyOpen (_Symbol, InpMTFPeriod, 0, n, o) <= 0) return;
   if(CopyHigh (_Symbol, InpMTFPeriod, 0, n, h) <= 0) return;
   if(CopyLow  (_Symbol, InpMTFPeriod, 0, n, l) <= 0) return;
   if(CopyClose(_Symbol, InpMTFPeriod, 0, n, c) <= 0) return;

   ArraySetAsSeries(t, false);
   ArraySetAsSeries(o, false);
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);

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
      DetectSwingGeneric(i, InpSwingLength, t, o, h, l, c,
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

void DashLine(int row, string text, color clr)
{
   string nm = InpObjPrefix + "dash_l" + IntegerToString(row);
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nm, OBJPROP_CORNER, InpDashCorner);
   int xPad = 12, yPad = 8;
   int rowHeight = InpDashFontSize + 5;
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, InpDashX + xPad);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, InpDashY + yPad + row * rowHeight);
   ObjectSetString (0, nm, OBJPROP_TEXT,     text);
   ObjectSetInteger(0, nm, OBJPROP_COLOR,    clr);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, InpDashFontSize);
   ObjectSetString (0, nm, OBJPROP_FONT,     InpDashFont);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN,   true);
   bool rightCorner = (InpDashCorner == CORNER_RIGHT_UPPER || InpDashCorner == CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, rightCorner ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER);
}

void DashboardUpdate()
{
   // удалить все строки и пересоздать (простой, но надёжный путь)
   string p = InpObjPrefix + "dash_l";
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, p) == 0) ObjectDelete(0, nm);
   }

   string trendStr = TrendStr(g_state.trend);
   color  trendClr = TrendColor(g_state.trend);

   int row = 0;
   DashLine(row++, _Symbol + "  " + EnumToString(_Period),                              InpDashAccent);
   DashLine(row++, "─────────────────────",                                              InpDashTextColor);
   DashLine(row++, "Тренд " + EnumToString(_Period) + ":  " + trendStr,                 trendClr);

   if(InpMTFEnable)
   {
      string mtfStr = TrendStr(g_mtfState.trend);
      color  mtfClr = TrendColor(g_mtfState.trend);
      DashLine(row++, "Тренд " + EnumToString(InpMTFPeriod) + ":  " + mtfStr,           mtfClr);
   }

   DashLine(row++, "─ Структура ─",                                                      InpDashAccent);
   DashLine(row++, StringFormat("BOS    +%d  / -%d",   g_cnt.bosBull,   g_cnt.bosBear),  InpDashTextColor);
   DashLine(row++, StringFormat("CHoCH  +%d  / -%d",   g_cnt.chochBull, g_cnt.chochBear),InpDashTextColor);
   DashLine(row++, StringFormat("Sweeps +%d  / -%d",   g_cnt.sweepBull, g_cnt.sweepBear),InpDashTextColor);
   DashLine(row++, StringFormat("HH/HL  %d / %d",      g_cnt.swingsHH,  g_cnt.swingsHL), InpDashTextColor);
   DashLine(row++, StringFormat("LH/LL  %d / %d",      g_cnt.swingsLH,  g_cnt.swingsLL), InpDashTextColor);

   if(InpMTFEnable)
   {
      DashLine(row++, "─ MTF структура ─",                                                InpDashAccent);
      DashLine(row++, StringFormat("BOS    +%d  / -%d", g_cnt.mtfBosBull,   g_cnt.mtfBosBear),   InpDashTextColor);
      DashLine(row++, StringFormat("CHoCH  +%d  / -%d", g_cnt.mtfChochBull, g_cnt.mtfChochBear), InpDashTextColor);
   }

   DashLine(row++, "─ Зоны ─",                                                            InpDashAccent);
   DashLine(row++, StringFormat("OB+   active %d  mit %d", g_cnt.obBullActive, g_cnt.obBullMit), InpDashTextColor);
   DashLine(row++, StringFormat("OB-   active %d  mit %d", g_cnt.obBearActive, g_cnt.obBearMit), InpDashTextColor);
   DashLine(row++, StringFormat("FVG   +%d  / -%d",        g_cnt.fvgBull,      g_cnt.fvgBear),   InpDashTextColor);

   DashLine(row++, "─ Объём ─",                                                           InpDashAccent);
   DashLine(row++, StringFormat("Громких +%d / -%d  (×%.2f)", g_cnt.hivolUp, g_cnt.hivolDn, InpVolumeMultiplier), InpDashTextColor);

   if(InpVPEnable)
   {
      ENUM_TIMEFRAMES vpTF = (InpVPTimeframe == PERIOD_CURRENT) ? _Period : InpVPTimeframe;
      DashLine(row++, "─ Volume Profile ─",                                                InpDashAccent);
      DashLine(row++, StringFormat("TF: %s  rows: %d  N: %d", EnumToString(vpTF), InpVPRows, InpVPLookback), InpDashTextColor);
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
   if(InpVPShowPoc)
   {
      double pocPrice = pmin + (pocIdx + 0.5) * rowH;
      DrawVPLine("vp_poc", pocPrice, InpVPPocColor, STYLE_DOT,  "POC " + DoubleToString(pocPrice, _Digits));
   }
   if(InpVPShowVa)
   {
      double vahPrice = pmin + (vaHigh + 1) * rowH;
      double valPrice = pmin + vaLow * rowH;
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
