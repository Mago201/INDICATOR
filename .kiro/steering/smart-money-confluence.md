---
title: Smart Money Confluence Preset (SmartMoneyVolume.mq5)
inclusion: manual
---

# Smart Money Confluence — пресет для `Indicators/SmartMoneyVolume.mq5`

Готовый набор настроек для торговли «вместе с крупным участником»: ищем
**снятие ликвидности → слом структуры (CHoCH/BOS) с импульсом → возврат в Order
Block → подтверждение дельтой**, и показываем сигнал только при совпадении
нескольких независимых факторов (score-режим).

> Это образовательный пресет по технике, а не торговая рекомендация. Параметры —
> отправная точка; адаптируйте под инструмент/таймфрейм и проверяйте на истории.

## Идея пресета

Сигнал входа = совпадение «следов» крупного игрока в одной точке:
1. Биас старшего ТФ (MTF-структура).
2. Снятие ликвидности против биаса (stop hunt).
3. CHoCH/BOS в сторону биаса + FVG-импульс (displacement) = «сильный» OB.
4. Возврат цены в Order Block (зона набора, помечена макс. объёмом `V:`).
5. Подтверждение дельтой по тикам (BUY: Δ>0 / SELL: Δ<0) и/или дивергенцией CVD.
6. Premium/Discount: BUY в discount, SELL в premium.

## Рекомендуемые значения входных параметров

### Структура
- `InpSwingLength = 5`
- `InpShowBOS = true`, `InpShowCHOCH = true`

### Order Blocks
- `InpShowOB = true`
- `InpOBMaxCount = 5`
- `InpOBHideMitigated = false`
- `InpOBExtendOnTouch = true`
- `InpOBShowVolume = true`  ← макс. объём внутри OB (метка `V:`)

### Fair Value Gaps
- `InpShowFVG = true`

### Ликвидность
- `InpLiqLevelsEnable = true`
- `InpLiqShowLines = true`
- `InpLiqShowEqual = true` (EQH/EQL — пулы стопов)
- `InpLiqShowDaily = true`, `InpLiqShowSessions = true`

### MTF (биас старшего ТФ)
- `InpMTFEnable = true`
- `InpMTFPeriod = PERIOD_H1` (для входов на M5/M15); для H1-входов ставьте H4
- `InpMTFShowOB = true`

### Объём
- `InpShowVolume = true`
- `InpVolumeType = VOLUME_TICK` (на форексе), `VOLUME_REAL` для биржевых символов
- `InpVolumeMultiplier = 1.8`

### Delta / CVD (footprint по тикам)
- `InpDeltaEnable = true`
- `InpDeltaLookback = 120`
- `InpDeltaShowDiv = true` (дивергенции цена/CVD)
- `InpDeltaDivSwing = 2`, `InpDeltaDivRecent = 30`
- `InpDeltaShowBars = false` (включайте точечно — иначе мешает)
- `InpDeltaAlertDiv = false` (true, если нужен алерт)

### Volume Profile (TP-ориентиры)
- `InpVPEnable = true`
- `InpEntryUseVPForTP = true` (POC/VAH/VAL как кандидаты TP)

## Entry — score-режим (главное)

Включаем score, чтобы не было «всё или ничего», и берём только «жирные» сетапы.

- `InpEntryEnable = true`
- `InpEntryUseScore = true`
- `InpEntryMinScore = 8`

Веса (баланс «подтверждений»):
- `InpEntryWeightTrend = 2`
- `InpEntryWeightMTF = 2`
- `InpEntryWeightOB = 2`
- `InpEntryWeightStrongOB = 2`
- `InpEntryWeightVolume = 1`
- `InpEntryWeightSweep = 2`
- `InpEntryWeightStruct = 2`
- `InpEntryWeightPremDisc = 2`
- `InpEntryWeightRR = 1`
- `InpEntryWeightVPCnflu = 1`
- `InpEntryWeightReject = 1`
- `InpEntryWeightGrabChoCH = 3`  ← самый сильный фактор
- `InpEntryWeightDelta = 2`      ← подтверждение объёмом по тикам

### Жёсткие гейты (работают и в score-режиме)
Минимальный «скелет» сетапа — оставляем обязательным:
- `InpEntryNeedOB = true` (вход только из активного OB)
- `InpEntryNeedPremDisc = true` (BUY в discount / SELL в premium)
- `InpEntryNeedRR = true`, `InpEntryMinRR = 1.5`

Остальные — опционально, для более строгого отбора:
- `InpEntryNeedGrabChoCH = true` (классический grab→CHoCH)
- `InpEntryNeedStrongOB = true` (OB только с displacement/FVG)
- `InpEntryNeedDelta = true` (требовать подтверждение дельтой; вне окна тиков
  фильтр **мягкий** и не блокирует исторические сигналы)

### Анти-кластеризация
- `InpEntryCooldownBars = 3`
- `InpEntryMinDistATR = 0.5`
- `InpEntrySLATRMult = 0.30`, `InpEntryATRPeriod = 14`

## Торговый чек-лист
1. Биас на MTF (H1/H4).
2. Снятие ликвидности против биаса (прокол EQH/EQL или swing).
3. CHoCH/BOS в сторону биаса + FVG (сильный OB).
4. Возврат в OB (смотрим метку `V:` — крупный объём в зоне).
5. Подтверждение: Δ бара в сторону входа и/или дивергенция CVD на дашборде.
6. SL за зону OB (+ATR-буфер), TP — ближайший пул ликвидности / POC / VAH/VAL.
7. Входим только при `score >= InpEntryMinScore`.

## Важные оговорки
- Дельта/CVD считаются по тикам (`CopyTicksRange`). Для истории нужны
  загруженные тики; на форексе классификация buy/sell приблизительная
  (фолбэк по изменению цены). На биржевых символах с реальным объёмом точнее.
- `InpHeavyOnNewBarOnly = true` — дельта пересчитывается на новом баре
  (производительность). Для «живой» дельты текущего бара значение в дашборде
  обновляется на каждом тяжёлом пересчёте.
- Это индикатор-помощник: окончательное решение и риск-менеджмент — за трейдером.
