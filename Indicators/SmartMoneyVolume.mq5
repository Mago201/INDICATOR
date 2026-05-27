//+------------------------------------------------------------------+
//|                                          SmartMoneyVolume.mq5    |
//|                                Smart Money Concepts + Volume     |
//|                                            Copyright 2026 Mago201 |
//+------------------------------------------------------------------+
#property copyright "Mago201 / INDICATR007"
#property link      "https://github.com/Mago201/INDICATOR"
#property version   "1.00"
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

//+------------------------------------------------------------------+
//| Входные параметры                                                 |
//+------------------------------------------------------------------+
input group "=== Структура (Swing / BOS / CHoCH) ==="
input int      InpSwingLength      = 5;             // Длина свинга (баров слева/справа)
input bool     InpShowSwings       = true;          // Метки HH/HL/LH/LL
input bool     InpShowBOS          = true;          // Линии BOS
input bool     InpShowCHOCH        = true;          // Линии CHoCH
input color    InpBullColor        = clrLime;       // Цвет бычьих структур
input color    InpBearColor        = clrRed;        // Цвет медвежьих структур

input group "=== Order Blocks ==="
input bool     InpShowOB           = true;          // Показывать ордер-блоки
input int      InpOBMaxCount       = 5;             // Максимум активных OB на сторону
input color    InpBullOBColor      = clrSeaGreen;   // Цвет бычьего OB
input color    InpBearOBColor      = clrCrimson;    // Цвет медвежьего OB
input int      InpOBExtendBars     = 30;            // Длина OB вправо (в барах)

input group "=== Fair Value Gaps ==="
input bool     InpShowFVG          = true;          // Показывать FVG / имбалансы
input int      InpFVGMaxCount      = 10;            // Максимум активных FVG на сторону
input color    InpBullFVGColor     = clrDarkGreen;
input color    InpBearFVGColor     = clrDarkRed;
input int      InpFVGExtendBars    = 20;            // Длина FVG вправо (в барах)

input group "=== Liquidity Sweeps ==="
input bool     InpShowLiquidity    = true;          // Снятия ликвидности (sweep)
input color    InpLiquidityColor   = clrGold;

input group "=== Анализ объёмов ==="
input bool     InpShowVolume       = true;          // Подсвечивать объёмные свечи
input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK; // Тип объёма
input int      InpVolumePeriod     = 20;            // Период средн. объёма
input double   InpVolumeMultiplier = 1.8;           // Множитель к среднему (>1.0)
input bool     InpShowVolText      = false;         // Подписывать значение объёма
input color    InpVolTextColor     = clrSilver;

input group "=== Прочее ==="
input string   InpObjPrefix        = "SMV_";        // Префикс графических объектов
input bool     InpAlertOnBOS       = false;         // Алерт при BOS/CHoCH
input bool     InpAlertOnSweep     = false;         // Алерт при liquidity sweep

//+------------------------------------------------------------------+
//| Буферы                                                            |
//+------------------------------------------------------------------+
double BufHighVolUp[];
double BufHighVolDn[];

//--- Состояние структуры
struct SwingPoint
{
   datetime time;
   double   price;
   int      shift;     // bar shift (мы храним абсолютные времена)
   bool     valid;
};

SwingPoint g_lastSwingHigh;
SwingPoint g_lastSwingLow;
SwingPoint g_prevSwingHigh;
SwingPoint g_prevSwingLow;

int g_trend = 0;       // 1 = bull, -1 = bear, 0 = flat

//+------------------------------------------------------------------+
//| Init                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufHighVolUp, INDICATOR_DATA);
   SetIndexBuffer(1, BufHighVolDn, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 234); // стрелка вниз -> метка над баром
   PlotIndexSetInteger(1, PLOT_ARROW, 233); // стрелка вверх -> метка под баром
   PlotIndexSetDouble (0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -10);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT,  10);

   IndicatorSetString(INDICATOR_SHORTNAME, "SmartMoney+Volume");

   ResetSwings();
   ClearAllObjects();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinit                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ClearAllObjects();
}

//+------------------------------------------------------------------+
//| Сброс свингов                                                     |
//+------------------------------------------------------------------+
void ResetSwings()
{
   g_lastSwingHigh.valid = false;
   g_lastSwingLow.valid  = false;
   g_prevSwingHigh.valid = false;
   g_prevSwingLow.valid  = false;
   g_trend = 0;
}

//+------------------------------------------------------------------+
//| Удаление всех объектов с нашим префиксом                          |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Получить объём с учётом настройки                                 |
//+------------------------------------------------------------------+
long GetVolume(int idx, const long &tick_vol[], const long &real_vol[])
{
   if(InpVolumeType == VOLUME_REAL)
      return real_vol[idx];
   return tick_vol[idx];
}

//+------------------------------------------------------------------+
//| Главный расчёт                                                    |
//+------------------------------------------------------------------+
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
      ResetSwings();
      ClearAllObjects();
      start = InpSwingLength;
   }
   else
   {
      start = prev_calculated - 1;
      if(start < InpSwingLength) start = InpSwingLength;
   }

   //--- Проходим по барам слева направо
   //--- Свинг можно подтвердить только когда после него прошло InpSwingLength баров
   int last_confirmable = rates_total - InpSwingLength - 1;

   for(int i = start; i <= last_confirmable; ++i)
   {
      // 1) Volume highlight
      ProcessVolume(i, rates_total, time, open, close, high, low, tick_volume, volume);

      // 2) FVG (3-свечной паттерн на барах i-2, i-1, i)
      if(InpShowFVG && i >= 2)
         DetectFVG(i, time, high, low);

      // 3) Свинг подтверждается на баре i (центр), если i+InpSwingLength доступен
      DetectSwing(i, time, high, low, close);
   }

   //--- Очистим буфер для последних незакрытых баров (они ещё не подтверждены)
   for(int i = last_confirmable + 1; i < rates_total; ++i)
   {
      BufHighVolUp[i] = EMPTY_VALUE;
      BufHighVolDn[i] = EMPTY_VALUE;
      // обработаем громкие свечи и для незакрытых, чтобы видеть «горячие» бары
      ProcessVolume(i, rates_total, time, open, close, high, low, tick_volume, volume);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Анализ объёма для бара i                                          |
//+------------------------------------------------------------------+
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
   if((double)curVol >= avg * InpVolumeMultiplier)
   {
      bool bullish = close[i] >= open[i];
      if(bullish)
         BufHighVolUp[i] = high[i];
      else
         BufHighVolDn[i] = low[i];

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
}

//+------------------------------------------------------------------+
//| Форматирование объёма                                             |
//+------------------------------------------------------------------+
string FormatVolume(long v)
{
   if(v >= 1000000) return DoubleToString(v / 1000000.0, 2) + "M";
   if(v >= 1000)    return DoubleToString(v / 1000.0, 1)    + "K";
   return IntegerToString(v);
}

//+------------------------------------------------------------------+
//| Поиск Fair Value Gap                                              |
//| Бычий FVG: low[i] > high[i-2] (между ними «пустой» бар i-1)       |
//| Медвежий: high[i] < low[i-2]                                      |
//+------------------------------------------------------------------+
void DetectFVG(int i, const datetime &time[], const double &high[], const double &low[])
{
   if(low[i] > high[i-2])
   {
      DrawFVG(time[i-2], high[i-2], time[i], low[i], true);
      LimitObjectsByTag("fvgB_", InpFVGMaxCount);
   }
   else if(high[i] < low[i-2])
   {
      DrawFVG(time[i-2], low[i-2], time[i], high[i], false);
      LimitObjectsByTag("fvgS_", InpFVGMaxCount);
   }
}

//+------------------------------------------------------------------+
//| Рисуем FVG-прямоугольник                                          |
//+------------------------------------------------------------------+
void DrawFVG(datetime t1, double p1, datetime t2, double p2, bool bull)
{
   string tag  = bull ? "fvgB_" : "fvgS_";
   string name = InpObjPrefix + tag + IntegerToString((long)t2);
   datetime tEnd = t2 + PeriodSeconds() * InpFVGExtendBars;
   color clr  = bull ? InpBullFVGColor : InpBearFVGColor;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, tEnd, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, tEnd);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Ограничить количество объектов с заданным тегом                   |
//+------------------------------------------------------------------+
void LimitObjectsByTag(string tag, int maxCount)
{
   if(maxCount <= 0) return;
   string prefix = InpObjPrefix + tag;
   // Соберём все объекты с этим префиксом
   string names[];
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

   // Простая сортировка по времени по возрастанию
   for(int a = 0; a < cnt - 1; ++a)
      for(int b = a + 1; b < cnt; ++b)
         if(times[a] > times[b])
         {
            datetime tt = times[a]; times[a] = times[b]; times[b] = tt;
            string   ss = names[a]; names[a] = names[b]; names[b] = ss;
         }

   int toDelete = cnt - maxCount;
   for(int x = 0; x < toDelete; ++x)
      ObjectDelete(0, names[x]);
}

//+------------------------------------------------------------------+
//| Подтверждение свинга на баре i                                    |
//| swing high: high[i] - максимум на отрезке [i-L .. i+L]            |
//| swing low : low [i] - минимум                                     |
//+------------------------------------------------------------------+
void DetectSwing(int i, const datetime &time[],
                 const double &high[], const double &low[],
                 const double &close[])
{
   int L = InpSwingLength;
   if(i < L) return;

   bool isHigh = true, isLow = true;
   for(int k = 1; k <= L; ++k)
   {
      if(high[i] <= high[i-k] || high[i] <= high[i+k]) isHigh = false;
      if(low[i]  >= low[i-k]  || low[i]  >= low[i+k])  isLow  = false;
      if(!isHigh && !isLow) break;
   }

   if(isHigh) OnSwingHigh(i, time, high, close);
   if(isLow ) OnSwingLow (i, time, low,  close);
}

//+------------------------------------------------------------------+
//| Обработать новый swing high                                       |
//+------------------------------------------------------------------+
void OnSwingHigh(int i, const datetime &time[], const double &high[], const double &close[])
{
   // Метка
   string label = (g_lastSwingHigh.valid && high[i] > g_lastSwingHigh.price) ? "HH" : "LH";
   if(InpShowSwings)
      DrawSwingLabel(time[i], high[i], label, true);

   // BOS / CHoCH срабатывают по close, но мы фиксируем на самом swing-баре,
   // когда уже достоверно знаем относительный уровень.
   if(g_lastSwingHigh.valid && InpShowBOS && g_trend != -1 && high[i] > g_lastSwingHigh.price)
   {
      DrawStructureLine(g_lastSwingHigh.time, g_lastSwingHigh.price,
                        time[i], g_lastSwingHigh.price,
                        "BOS", true);
      g_trend = 1;
      AlertStructure("BOS bull", time[i]);
   }
   else if(g_lastSwingHigh.valid && InpShowCHOCH && g_trend == -1 && high[i] > g_lastSwingHigh.price)
   {
      DrawStructureLine(g_lastSwingHigh.time, g_lastSwingHigh.price,
                        time[i], g_lastSwingHigh.price,
                        "CHoCH", true);
      g_trend = 1;
      AlertStructure("CHoCH bull", time[i]);
   }

   // Liquidity sweep: текущий бар пробил предыдущий swing high, но закрылся ниже него
   if(InpShowLiquidity && g_lastSwingHigh.valid &&
      high[i] > g_lastSwingHigh.price && close[i] < g_lastSwingHigh.price)
   {
      DrawSweep(time[i], high[i], true);
      AlertSweep("Sweep high", time[i]);
   }

   // Order block: последний медвежий бар перед импульсным движением вверх,
   // приведшим к пробою предыдущего high. Здесь просто — берём бар с минимумом
   // на отрезке [i-L .. i-1] с близом ниже открытия.
   if(InpShowOB && g_trend == 1)
      TryDrawOB(i, true);

   g_prevSwingHigh = g_lastSwingHigh;
   g_lastSwingHigh.time  = time[i];
   g_lastSwingHigh.price = high[i];
   g_lastSwingHigh.shift = i;
   g_lastSwingHigh.valid = true;
}

//+------------------------------------------------------------------+
//| Обработать новый swing low                                        |
//+------------------------------------------------------------------+
void OnSwingLow(int i, const datetime &time[], const double &low[], const double &close[])
{
   string label = (g_lastSwingLow.valid && low[i] < g_lastSwingLow.price) ? "LL" : "HL";
   if(InpShowSwings)
      DrawSwingLabel(time[i], low[i], label, false);

   if(g_lastSwingLow.valid && InpShowBOS && g_trend != 1 && low[i] < g_lastSwingLow.price)
   {
      DrawStructureLine(g_lastSwingLow.time, g_lastSwingLow.price,
                        time[i], g_lastSwingLow.price,
                        "BOS", false);
      g_trend = -1;
      AlertStructure("BOS bear", time[i]);
   }
   else if(g_lastSwingLow.valid && InpShowCHOCH && g_trend == 1 && low[i] < g_lastSwingLow.price)
   {
      DrawStructureLine(g_lastSwingLow.time, g_lastSwingLow.price,
                        time[i], g_lastSwingLow.price,
                        "CHoCH", false);
      g_trend = -1;
      AlertStructure("CHoCH bear", time[i]);
   }

   if(InpShowLiquidity && g_lastSwingLow.valid &&
      low[i] < g_lastSwingLow.price && close[i] > g_lastSwingLow.price)
   {
      DrawSweep(time[i], low[i], false);
      AlertSweep("Sweep low", time[i]);
   }

   if(InpShowOB && g_trend == -1)
      TryDrawOB(i, false);

   g_prevSwingLow = g_lastSwingLow;
   g_lastSwingLow.time  = time[i];
   g_lastSwingLow.price = low[i];
   g_lastSwingLow.shift = i;
   g_lastSwingLow.valid = true;
}

//+------------------------------------------------------------------+
//| Метка свинга                                                      |
//+------------------------------------------------------------------+
void DrawSwingLabel(datetime t, double price, string text, bool isHigh)
{
   string name = InpObjPrefix + "sw_" + IntegerToString((long)t);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,  t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, price);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, isHigh ? InpBearColor : InpBullColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
//| Линия структуры (BOS / CHoCH)                                     |
//+------------------------------------------------------------------+
void DrawStructureLine(datetime t1, double p1, datetime t2, double p2,
                       string text, bool bull)
{
   string tag  = (text == "BOS") ? "bos_" : "choch_";
   string name = InpObjPrefix + tag + IntegerToString((long)t2);
   color  clr  = bull ? InpBullColor : InpBearColor;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, (text == "CHoCH") ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);

   // подпись посередине
   string lbl = name + "_lbl";
   double mid = (p1 + p2) / 2.0;
   datetime tm = t1 + (t2 - t1) / 2;
   if(ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_TEXT, 0, tm, mid);
   ObjectSetInteger(0, lbl, OBJPROP_TIME,  tm);
   ObjectSetDouble (0, lbl, OBJPROP_PRICE, mid);
   ObjectSetString (0, lbl, OBJPROP_TEXT, text);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
}

//+------------------------------------------------------------------+
//| Стрелка-маркер для liquidity sweep                                |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Найти и нарисовать Order Block                                    |
//| bull = true  -> бычий OB (последний медвежий бар перед импульсом) |
//| bull = false -> медвежий OB (последний бычий бар перед импульсом) |
//+------------------------------------------------------------------+
void TryDrawOB(int i, bool bull)
{
   // Возьмём бар на расстоянии 1..InpSwingLength назад противоположной направленности
   int L = InpSwingLength;
   int ob = -1;
   for(int k = 1; k <= L; ++k)
   {
      int idx = i - k;
      if(idx <= 0) break;
      // Доступ к O/C через iOpen/iClose (текущий символ/период)
      double op = iOpen (_Symbol, PERIOD_CURRENT, BarsTotalShift(idx));
      double cl = iClose(_Symbol, PERIOD_CURRENT, BarsTotalShift(idx));
      bool bearishBar = cl < op;
      bool bullishBar = cl > op;
      if(bull && bearishBar) { ob = idx; break; }
      if(!bull && bullishBar){ ob = idx; break; }
   }
   if(ob < 0) return;

   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, BarsTotalShift(ob));
   double   hi = iHigh(_Symbol, PERIOD_CURRENT, BarsTotalShift(ob));
   double   lo = iLow (_Symbol, PERIOD_CURRENT, BarsTotalShift(ob));
   datetime t2 = t1 + PeriodSeconds() * InpOBExtendBars;

   string tag  = bull ? "obB_" : "obS_";
   string name = InpObjPrefix + tag + IntegerToString((long)t1);
   color  clr  = bull ? InpBullOBColor : InpBearOBColor;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, hi);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

   LimitObjectsByTag(tag, InpOBMaxCount);
}

//+------------------------------------------------------------------+
//| Перевод "индекса слева" в "shift справа" для iOpen/iHigh/...      |
//+------------------------------------------------------------------+
int BarsTotalShift(int leftIndex)
{
   int total = Bars(_Symbol, PERIOD_CURRENT);
   int shift = total - 1 - leftIndex;
   if(shift < 0) shift = 0;
   return shift;
}

//+------------------------------------------------------------------+
//| Алерты                                                             |
//+------------------------------------------------------------------+
void AlertStructure(string what, datetime t)
{
   if(!InpAlertOnBOS) return;
   // Триггерим только для свежих баров, чтобы не спамить при пересчёте истории
   if(TimeCurrent() - t > PeriodSeconds() * 2) return;
   Alert(_Symbol, " ", EnumToString(_Period), " ", what, " @ ", TimeToString(t, TIME_DATE|TIME_MINUTES));
}

void AlertSweep(string what, datetime t)
{
   if(!InpAlertOnSweep) return;
   if(TimeCurrent() - t > PeriodSeconds() * 2) return;
   Alert(_Symbol, " ", EnumToString(_Period), " ", what, " @ ", TimeToString(t, TIME_DATE|TIME_MINUTES));
}
//+------------------------------------------------------------------+
