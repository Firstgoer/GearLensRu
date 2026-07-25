<img src="https://raw.githubusercontent.com/Firstgoer/GearLensRu/main/GearLens_Icon.png" width="128" align="right" alt="GearLensRu">

# GearLensRu

Per-slot item levels and gear checks on the Character and Inspect frames for
World of Warcraft Classic: Mists of Pandaria.

**[English](#english) · [Русский](#русский)**

> **Russian (ruRU) client only.** The addon reads the Russian client's tooltip
> strings, so its checks do not work on other locales, and its in-game text is
> Russian.

## English

GearLensRu shows the item level of every equipped item directly on the slots of
the Character frame and the Inspect frame, and flags what still needs doing.

### Item levels

- ilvl on every slot, coloured by item quality
- base level in small text beside it when the item is upgraded
- average ilvl above the weapon slots
- works for your own character and for inspected players

### Gear checks

A warning icon appears on the problem slot; hover it for details:

- missing enchant (off-hand aware, rings included for enchanters)
- empty sockets, outdated gems, low-quality gems
- missing belt buckle
- missing blacksmithing socket (wrists, hands)
- missing engineering tinkers: Nitro Boosts, Synapse Springs, Goblin Glider
- broken armor specialization bonus
- item not fully upgraded, with current and maximum level
- missing Eye of the Black Prince socket on 522–541 ilvl weapons
- missing legendary meta gem in a 522–541 ilvl helm

Seasonal PvP gear is excluded from the last two checks.

### Reports from the Inspect frame

Two buttons send the list of problems line by line, prefixed with the slot name —
by whisper to the inspected player, or to chat:

```
GearLens: проблемы со снаряжением у Иванко:
[Голова] Нет легендарного особого самоцвета.
[Кисти рук] Нет чар.
[Пояс] Нет пряжки для пояса.
```

The channel is picked automatically: raid, instance, party or say.

### Installation

1. Extract the `GearLensRu` folder into
   `World of Warcraft/_classic_/Interface/AddOns/`
2. Restart the game, or run `/reload`

### Requirements

- World of Warcraft Classic: Mists of Pandaria (interface 50504)
- Russian (ruRU) client

### Diagnostics

`/glr` reports engineering tinker detection and current vs base ilvl per slot.
`/glr diag` adds the scan tooltip's owner, line counts, the `Использование:` and
`Уровень ...` lines it found, and each tinker pattern's match result.
`/glr dump <slot>` prints every tooltip line for one slot.

Tooltip data is read through `C_TooltipInfo` where the client provides it, and
through a tooltip scrape otherwise — MoP Classic has no `C_TooltipInfo`, so the
scrape is the path that runs in practice. Detected tinkers and upgrade levels are
cached, and incomplete reads are retried automatically, without a `/reload`.

## Русский

GearLensRu показывает уровень каждого надетого предмета прямо на слотах в окне
персонажа и в окне осмотра другого игрока — и сразу отмечает то, что забыли
доделать.

### Уровень предметов

- Число ilvl на каждом слоте, окрашенное по качеству предмета
- Базовый уровень мелким шрифтом рядом, если предмет улучшен
- Средний ilvl над слотами оружия
- Работает и для своего персонажа, и для осматриваемого игрока

### Проверки снаряжения

На проблемном слоте появляется значок предупреждения, детали — по наведению:

- Нет чар (с учетом левой руки и колец у зачаровывателя)
- Пустые гнезда, устаревшие самоцветы, самоцветы низкого качества
- Нет пряжки для пояса
- Нет дополнительного гнезда от кузнечного дела (запястья, кисти рук)
- Нет улучшений инженера: нитроускорители, нейронные пружины, гоблинский планер
- Нарушен бонус специализации брони
- Предмет улучшен не полностью, с указанием текущего и максимального уровня
- Нет гнезда от Ока Черного принца на оружии 522–541 ilvl
- Нет легендарного особого самоцвета в шлеме 522–541 ilvl

Сезонное PvP-снаряжение исключено из последних двух проверок.

### Отчеты из окна осмотра

Кнопки **«Шепнуть игроку»** и **«Отправить в чат»** отправляют список найденных
проблем построчно, с названием слота в начале строки. Канал выбирается
автоматически: рейд, подземелье, группа или обычная речь.

### Установка

1. Распакуйте папку `GearLensRu` в
   `World of Warcraft/_classic_/Interface/AddOns/`
2. Перезапустите игру или выполните `/reload`

### Требования

- World of Warcraft Classic: Mists of Pandaria (интерфейс 50504)
- Русский клиент

### Диагностика

`/glr` выводит состояние определения улучшений инженера и текущий и базовый ilvl
по каждому слоту. `/glr diag` добавляет владельца подсказки, число строк,
найденные строки «Использование:» и «Уровень ...» и результат сопоставления
каждого шаблона. `/glr dump <слот>` печатает все строки подсказки для одного
слота.

Данные читаются через `C_TooltipInfo`, если клиент его предоставляет, и через
чтение подсказки в остальных случаях — в MoP Classic `C_TooltipInfo` нет, поэтому
на практике работает второй путь. Найденные улучшения инженера и уровни улучшения
предметов кешируются, а неполные чтения перепроверяются автоматически — без
`/reload`.

## Изменения / Changelog

См. [CHANGELOG.md](CHANGELOG.md) — записи на русском.
