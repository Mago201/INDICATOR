# SmartMoneyVolume — индикатор для MetaTrader 5

**v1.10** — теперь со старшим ТФ, mitigation Order Blocks, дашбордом и Volume Profile.

Один индикатор объединяет:
- **Smart Money Concepts (SMC)** — структура, BOS, CHoCH, OB, FVG, sweeps
- **Анализ объёмов** — подсветка громких свечей
- **Multi-Timeframe** — структуру старшего ТФ прямо на текущем графике
- **Order Block mitigation** — отметку сработавших и активных зон
- **Dashboard** — счётчик всех сигналов в углу графика
- **Volume Profile** — POC / VAH / VAL с любого таймфрейма

## Что показывает

| Элемент | Описание |
|---|---|
| **HH / HL / LH / LL** | Метки структурных свингов |
| **BOS** (сплошная) | Пробой структуры в направлении тренда |
| **CHoCH** (пунктир) | Смена характера рынка / разворот |
| **Order Blocks** | Зоны последнего противоположного бара перед импульсом. **Серые с пунктиром** = mitigated |
| **Fair Value Gaps** | 3-свечные имбалансы |
| **Liquidity Sweeps** | Стрелки в местах снятия ликвидности |
| **High-Volume bars** | Стрелки над/под объёмными свечами |
| **MTF структура** | Свинги/BOS/CHoCH/OB старшего ТФ (синим/малиновым) |
| **Volume Profile** | Гистограмма объёмов по ценовым уровням + POC/VAH/VAL |
| **Dashboard** | Панель в углу со счётчиками всех сигналов |

## Установка

1. MT5 → **Файл → Открыть каталог данных** → `MQL5/Indicators/`.
2. Скопируйте [`Indicators/SmartMoneyVolume.mq5`](Indicators/SmartMoneyVolume.mq5) в эту папку.
3. В MetaEditor (`F4`) откройте файл и нажмите **Compile** (`F7`).
4. В «Навигаторе» MT5 обновите список и перетащите индикатор на график.

## Параметры

### Структура (Swing / BOS / CHoCH)
- `InpSwingLength` — баров слева/справа для подтверждения свинга. Больше = крупнее структура.
- `InpShowSwings`, `InpShowBOS`, `InpShowCHOCH` — переключатели элементов.
- `InpBullColor` / `InpBearColor` — цвета.

### Order Blocks + Mitigation
- `InpShowOB` — включить ордер-блоки.
- `InpOBMaxCount` — максимум активных OB на сторону.
- `InpOBExtendBars` — длина прямоугольника вправо.
- `InpOBHideMitigated` — `true` = удалять сработавшие OB; `false` = показывать серым.
- `InpOBMitigatedClr` — цвет сработавшего OB.
- `InpOBExtendOnTouch` — обрезать прямоугольник на момент касания (правая граница = бар касания).

### Fair Value Gaps
- `InpShowFVG`, `InpFVGMaxCount`, `InpFVGExtendBars`, `InpBullFVGColor`, `InpBearFVGColor`.

### Liquidity Sweeps
- `InpShowLiquidity`, `InpLiquidityColor`.

### Объёмы
- `InpShowVolume` — подсвечивать объёмные свечи.
- `InpVolumeType` — `VOLUME_TICK` или `VOLUME_REAL` (для бирж с реальными объёмами).
- `InpVolumePeriod` — период скользящей среднего объёма.
- `InpVolumeMultiplier` — во сколько раз выше среднего, чтобы считать «громким». 1.8 = +80%.
- `InpShowVolText`, `InpVolTextColor` — текстовая подпись объёма.

### MTF (старший таймфрейм)
- `InpMTFEnable` — отображать структуру старшего ТФ на текущем графике.
- `InpMTFPeriod` — какой ТФ анализировать (например, H1 на M15-чарте).
- `InpMTFLookback` — сколько баров MTF брать для анализа (по умолчанию 300).
- `InpMTFShowSwings`, `InpMTFShowBOS`, `InpMTFShowCHOCH`, `InpMTFShowOB` — что рисовать.
- `InpMTFBullColor` / `InpMTFBearColor` — цвета MTF структур (по умолчанию голубой/малиновый, чтобы отличать от обычных).
- `InpMTFBullOBClr` / `InpMTFBearOBClr` — цвета MTF OB.
- `InpMTFLineWidth` — толщина MTF-линий (рекомендую 2 для контраста).

> Если выбрать ТФ младше текущего, MTF-блок будет проигнорирован (защита).

### Dashboard
- `InpDashEnable` — показывать панель.
- `InpDashCorner` — угол графика (`CORNER_RIGHT_UPPER` по умолчанию).
- `InpDashX` / `InpDashY` — отступ от угла в пикселях.
- `InpDashWidth` — ширина панели.
- `InpDashTextColor`, `InpDashBgColor`, `InpDashAccent` — цвета.
- `InpDashFont`, `InpDashFontSize` — шрифт (рекомендую моноширинный).

Панель показывает:
- Текущий тренд по структуре (BULL/BEAR/FLAT) на текущем и MTF-таймфреймах
- Счётчики BOS+/-, CHoCH+/-, Sweeps+/-, HH/HL/LH/LL
- OB активные/сработавшие отдельно для бычьих и медвежьих
- FVG +/-
- Громкие свечи +/- с указанием множителя
- Параметры активного Volume Profile

### Volume Profile
- `InpVPEnable` — включить.
- `InpVPTimeframe` — на каком ТФ считать профиль (`PERIOD_CURRENT` = текущий). Можно построить D1-профиль на M15-графике.
- `InpVPLookback` — сколько баров `InpVPTimeframe` использовать.
- `InpVPRows` — на сколько ценовых зон делить диапазон.
- `InpVPWidthPct` — какую часть видимой области графика занимает гистограмма (в %).
- `InpVPColor` — цвет обычных строк.
- `InpVPPocColor` — цвет POC (Point of Control — самая объёмная зона).
- `InpVPVaColor` — цвет Value Area (зоны с ~70% объёма вокруг POC).
- `InpVPShowPoc` / `InpVPShowVa` — рисовать ли горизонтальные линии POC/VAH/VAL.
- `InpVPValueArea` — доля объёма для VA (по умолчанию 0.70 = 70%).
- `InpVPRightSide` — `true` = гистограмма растёт ВЛЕВО от правого края (стандарт), `false` = вправо.

### Прочее
- `InpObjPrefix` — префикс имён объектов (изолирует индикатор от других).
- `InpAlertOnBOS`, `InpAlertOnSweep` — звуковые алерты для свежих сигналов.

## Стратегии применения

### 1. Тренд по MTF + вход по локальному OB
Если `InpMTFPeriod = H1` показывает BULL и есть свежий H1-BOS, ищите на M15:
- Bullish OB на M15 в зоне H1-OB
- Подтверждение громким объёмом (стрелка)
- Вход на касании M15-OB, стоп под ним

### 2. Контртренд по CHoCH + sweep ликвидности
- Sweep противоположной зоны (стрелка золотая)
- Сразу после — CHoCH = ранний сигнал разворота
- Усиление: касание VAH/VAL Volume Profile

### 3. Magnet trade — FVG/POC
- FVG не закрыт → цена с высокой вероятностью вернётся его заполнить
- POC = магнит для цены (наибольший объём)
- Используйте как цель TP

### 4. Dashboard scan
- За сессию смотрим: тренд на двух ТФ совпадает? Сколько было BOS / CHoCH? Высокий ли объём?
- Если несколько индикаторов согласуются — высоко-качественный сетап

## Особенности

- **Без перерисовки структур.** Свинги подтверждаются только когда после них прошло `InpSwingLength` баров.
- **Объёмная стрелка может «мерцать»** на текущем баре, пока он не закрыт — это нормально.
- **OB mitigation** срабатывает на первом касании зоны (low внутри bull-OB или high внутри bear-OB) и считается необратимым.
- **MTF пересчитывается** только при появлении нового бара старшего ТФ — производительно даже на длинной истории.
- **Volume Profile** перестраивается с каждым новым баром текущего ТФ.

## Рекомендации по настройке

| Сценарий | InpSwingLength | InpMTFPeriod | InpVolumeMultiplier |
|---|---|---|---|
| Скальпинг M1/M5 | 8–12 | M30 / H1 | 2.0–2.5 |
| Дейтрейдинг M15/M30 | 5–7 | H1 / H4 | 1.7–2.0 |
| Свинг H1/H4 | 3–5 | D1 / W1 | 1.5–1.8 |
| Биржевые рынки (фьючи, акции, MOEX) | — | — | `InpVolumeType = VOLUME_REAL` |

## Файлы

- [`Indicators/SmartMoneyVolume.mq5`](Indicators/SmartMoneyVolume.mq5) — исходный код.
