-- GearLens.lua
-- • Per-slot ilvl numbers on a dark chip (quality-colored text, always readable)
-- • Per-slot warning icons for missing gems / enchants / belt buckle / tinkers
--   – hover the icon for details
-- • Average ilvl badge on both CharacterFrame and InspectFrame

local ADDON_NAME = ...

-- ── Constants ─────────────────────────────────────────────────────────────────

local ILVL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

local SLOT_BUTTONS = {
    { name = "HeadSlot",          id = 1  },
    { name = "NeckSlot",          id = 2  },
    { name = "ShoulderSlot",      id = 3  },
    { name = "BackSlot",          id = 15 },
    { name = "ChestSlot",         id = 5  },
    { name = "WristSlot",         id = 9  },
    { name = "HandsSlot",         id = 10 },
    { name = "WaistSlot",         id = 6  },
    { name = "LegsSlot",          id = 7  },
    { name = "FeetSlot",          id = 8  },
    { name = "Finger0Slot",       id = 11 },
    { name = "Finger1Slot",       id = 12 },
    { name = "Trinket0Slot",      id = 13 },
    { name = "Trinket1Slot",      id = 14 },
    { name = "MainHandSlot",      id = 16 },
    { name = "SecondaryHandSlot", id = 17 },
    { name = "RangedSlot",        id = 18 },
}

-- Quality colors – epic is brighter than Blizzard default for readability
local QUALITY_COLOR = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.55, 1.00 },
    [4] = { 0.85, 0.55, 1.00 },  -- lightened epic purple
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
}

local ENCHANT_SLOTS = {
    [3]  = "Shoulder",  [5]  = "Chest",
    [7]  = "Legs",      [8]  = "Feet",
    [9]  = "Wrist",     [10] = "Hands",
    [15] = "Back",      [16] = "Main Hand",
    [17] = "Off Hand",
}

local SLOT_NAMES = {
    [1]  = "Голова",            [2]  = "Шея",                [3]  = "Плечи",
    [5]  = "Грудь",             [6]  = "Пояс",               [7]  = "Ноги",
    [8]  = "Ступни",            [9]  = "Запястья",           [10] = "Кисти рук",
    [11] = "Первое кольцо",     [12] = "Второе кольцо",
    [13] = "Первый аксессуар",  [14] = "Второй аксессуар",
    [15] = "Спина",             [16] = "Правая рука",        [17] = "Левая рука",
    [18] = "Дальний бой",
}

local EMPTY_SOCKET_TEXT = {
    ["Красное гнездо"] = true,  ["Желтое гнездо"] = true,  ["Синее гнездо"]       = true,
    ["Особое гнездо"] = true, ["Бесцветное гнездо"] = true, ["Гнездо для зубчатого колеса"] = true,
    ["Радужное гнездо"] = true,
}

local ENCHANTABLE_OH = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true,
}

-- MoP PvP season gear — exempt from Eye / legendary meta checks
local PVP_PATTERNS = { "злонравного", "деспотичного", "бездушного", "гордого" }
local function IsPvPItem(name)
    if not name then return false end
    for _, pat in ipairs(PVP_PATTERNS) do
        if name:find(pat, 1, true) then return true end
    end
    return false
end

-- Eye of the Black Prince: adds a socket to Sha-Touched / Thunder King weapons only.
-- Tooltip: "Add a prismatic socket to a Sha-Touched weapon or Armament of the Thunder King."
-- Max ilvl 541 = fully-upgraded Thunderforged heroic ToT; SoO weapons (528+ normal) cannot receive it.
local EYE_WEAPON_EQUIPLOC = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,  -- hunter bows/guns/crossbows (slot 16 in MoP)
}
local EYE_MIN_ILVL = 522
local EYE_MAX_ILVL = 541

-- Legendary meta gem from Wrathion's questline — relevant for ToT-tier helms
local META_MIN_ILVL = 522
local META_MAX_ILVL = 541  -- max fully-upgraded Thunderforged heroic ToT

-- Armor specialization: wearing wrong armor type loses the 5% primary stat bonus
local CLASS_ARMOR = {
    WARRIOR = "Латы", PALADIN = "Латы", DEATHKNIGHT = "Латы",
    HUNTER  = "Кольчуга",  SHAMAN  = "Кольчуга",
    DRUID   = "Кожа", MONK  = "Кожа", ROGUE = "Кожа",
    MAGE    = "Ткань", WARLOCK = "Ткань",  PRIEST = "Ткань",
}
-- Only these slots contribute to the armor specialization bonus
local ARMOR_SPEC_SLOTS = {
    [1]=true, [3]=true, [5]=true, [6]=true, [7]=true, [8]=true, [9]=true, [10]=true,
}

-- Engineering tinkers do NOT appear in the item link's enchant field.
-- Detect all of them via distinctive substrings in their tooltip "Use:" line.
-- Patterns are matched case-insensitively (see ScanSlot).
local ENG_TINKER_PATTERNS = {
    [6]  = { "значительно повышает вашу скорость бега" },          -- Nitro Boosts
    [10] = { "в зависимости от того, какой из этих показателей наивысший",              -- Synapse Springs
             "показатель уклонения на" },                                 -- Phase Fingers ("Increase your Dodge by ...")
    [15] = { "скорость падения" },                            -- Goblin Glider
}
local ENG_TINKER_NAMES = {
    [6]  = "Нитроускорители",
    [10] = "Нейронные пружины",
    [15] = "Гоблинский планер",
}

-- Bounded self-heal for incomplete tooltip reads. 12 x 0.4s ≈ 5s covers the window
-- after a cold client start where the server has not yet delivered item data; late
-- arrivals beyond it are picked up by GET_ITEM_INFO_RECEIVED.
local RETRY_LIMIT = 12
local RETRY_DELAY = 0.4

-- ── Scan tooltip ──────────────────────────────────────────────────────────────

local scanTip = CreateFrame("GameTooltip", "GearLensScanTip", UIParent, "GameTooltipTemplate")

-- Populate the scan tooltip and return its left-hand text lines.
-- SetOwner is called before EVERY read, not once at load. A scan tooltip that is only
-- ClearLines()'d between reads works at first and degrades later in the session, after
-- which SetInventoryItem populates fewer lines — or none. That matches the observed
-- symptom exactly: correct for a while, then persistently wrong until a /reload, which
-- recreates this frame. A /reload does NOT refill the client's item cache, so a stale
-- cache cannot be what /reload was fixing. SetOwner also clears the previous lines,
-- which is why no separate ClearLines() call is needed.
local function ReadScanTip(method, a, b)
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip[method](scanTip, a, b)
    local out = {}
    for i = 1, scanTip:NumLines() do
        local o = _G["GearLensScanTipTextLeft" .. i]
        out[#out + 1] = (o and o:GetText()) or ""
    end
    return out
end

-- A populated item tooltip always carries at least a name line and one detail line.
-- Anything shorter means it did not populate at all, so re-own and read once more
-- before believing an empty result.
local function ScanLines(method, a, b)
    local out = ReadScanTip(method, a, b)
    if #out < 2 then out = ReadScanTip(method, a, b) end
    return out
end

-- ── Tooltip readers ─────────────────────────────────────────────────────────────
-- MoP Classic (5.5.4) does NOT expose C_TooltipInfo — "/glr diag" reports it as nil —
-- so in practice every read here goes through the legacy FontString scrape. The
-- C_TooltipInfo branch is kept for clients that do have the API, where it reads the
-- authoritative data provider without depending on a rendered frame.
-- The scrape itself is sound: it returns every line the tooltip has. What it cannot do
-- is invent lines the client has not received yet. Before the server delivers an item's
-- data the tooltip is short or truncated — the "Использование:" line of an engineering
-- tinker can be absent while the item's own "Уровень предмета" line is already there —
-- so a scan taken in that window silently under-reports. Callers must treat an
-- incomplete read as retryable (see RETRY_LIMIT and GET_ITEM_INFO_RECEIVED) rather
-- than as "the item has no tinker/socket/upgrade".
-- Both helpers return a DENSE array of left-text strings (blank lines become ""),
-- so callers can iterate with ipairs without a nil hole truncating the scan early.
local function GetInventoryTooltipLines(unit, slot)
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = C_TooltipInfo.GetInventoryItem(unit, slot)
        if data and data.lines then
            local out = {}
            for _, row in ipairs(data.lines) do out[#out + 1] = row.leftText or "" end
            return out
        end
    end
    return ScanLines("SetInventoryItem", unit, slot)
end

local function GetHyperlinkTooltipLines(link)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(link)
        if data and data.lines then
            local out = {}
            for _, row in ipairs(data.lines) do out[#out + 1] = row.leftText or "" end
            return out
        end
    end
    return ScanLines("SetHyperlink", link)
end

-- Sticky last-known-good tinker detection. Engineering tinkers do NOT alter the item
-- link (see ENG_TINKER_PATTERNS note below), so once we have positively seen a tinker
-- on the item currently equipped in a slot, we trust that against any later transient
-- empty tooltip read. Keyed by slot; invalidated when the equipped link changes.
local tinkerSeen = {}

-- Sticky last-known-good upgrade level, same idea. The "Уровень улучшения: X/Y" line
-- can be momentarily absent from a tooltip read, which would otherwise drop the
-- "not fully upgraded" warning (false negative) until a /reload. Upgrading an item
-- changes its link, so a cached value can never survive an actual upgrade.
-- slot -> { link = <link>, cur = X, max = Y }
local upgradeSeen = {}

-- Sticky last-known-good current (upgrade-aware) item level. The "Уровень предмета:"
-- line can be missing from a transient incomplete tooltip read, which drops the chip
-- back to the base ilvl (e.g. shows 528 instead of the upgraded 540). Reuse the last
-- value seen for the same equipped item; the link changes on upgrade so it can't stale.
-- slot -> { link = <link>, ilvl = <current ilvl> }
local ilvlSeen = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function GetEnchantFromLink(link)
    if not link then return 0 end
    return tonumber(link:match("item:%d+:(%d+):")) or 0
end

-- Returns an array of non-zero gem item IDs from the item link (up to 4 slots).
local function GetFilledGemIDs(link)
    if not link then return {} end
    local data = link:match("|Hitem:([^|]+)|h") or link:match("item:([%d:%-]+)")
    if not data then return {} end
    local fields = {}
    for part in (data .. ":"):gmatch("([^:]*):") do
        fields[#fields + 1] = part
    end
    local ids = {}
    for i = 3, 6 do  -- gem1 is at index 3
        local g = tonumber(fields[i])
        if g and g ~= 0 then ids[#ids + 1] = g end
    end
    return ids
end

local function ScanSlot(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if not link then return nil end

    local name, _, quality, baseIlvl, itemMinLevel, _, itemSubType, _, equipLoc = GetItemInfo(link)

    -- Read the equipped item's tooltip via the data provider (C_TooltipInfo when
    -- available), which resolves the real equipped state — correct upgraded ilvl and
    -- accurate socket/tinker "Use:" lines — without depending on a rendered frame.
    -- For inspected units the inspect API may not expose full gem data, so we may
    -- occasionally miss an empty socket, but we avoid the false positives that come
    -- from scraping a hidden tooltip or from an incomplete inspect item link.
    local tipLines = GetInventoryTooltipLines(unit, slot)

    -- Effective item level includes MoP gear upgrades (up to +8 ilvl per item).
    -- In this client GetDetailedItemLevelInfo(link) returns the BASE ilvl, ignoring
    -- the gear-upgrade system. The tooltip "Item Level" line, built from the real
    -- equipped item via SetInventoryItem above, DOES carry the upgraded value, so it
    -- is authoritative. GetDetailedItemLevelInfo / GetItemInfo base ilvl are fallbacks
    -- for the rare case the tooltip line is missing (e.g. not yet cached).
    local effectiveIlvl  = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
    local tooltipIlvl    = nil
    local ilvl           = effectiveIlvl or baseIlvl
    local emptyGems      = 0
    local gemIDs         = GetFilledGemIDs(link)
    local totalSockets   = #gemIDs
    local hasEngTinker   = false
    local tinkerPatterns = ENG_TINKER_PATTERNS[slot]
    local upgradeLevel   = nil
    local maxUpgrade     = nil

    -- Classify each filled gem:
    --   outdated    = required level is more than 10 below the item's (wrong expansion era)
    --                 gap of 10 cleanly separates expansion tiers:
    --                   level 90 item → flag gems requiring < 80 (pre-Cata)
    --                   level 85 item → flag gems requiring < 75 (pre-Wrath)
    --   low quality = current-era but below Rare (green quality, quality < 3)
    local outdatedGems   = 0
    local lowQualityGems = 0
    if itemMinLevel and itemMinLevel > 0 then
        for _, gemID in ipairs(gemIDs) do
            local gemName, _, gemQuality, gemIlvl = GetItemInfo(gemID)
            -- "Perfect" cuts of uncommon gems have blue-equivalent stats;
            -- skip both checks for them regardless of their item level or quality.
            local isPerfect = gemName and gemName:find("^Совершенный ", 1, true)
            if not isPerfect then
                -- MoP gems are ilvl 88-90. Flag anything below 81 in level 85+ gear
                -- (catches Wrath-era and below; Cata gems sit at ~82-86 and are borderline).
                if gemIlvl and gemIlvl > 0
                and itemMinLevel and itemMinLevel >= 85
                and gemIlvl < 81 then
                    outdatedGems = outdatedGems + 1
                elseif gemQuality and gemQuality < 3 then
                    lowQualityGems = lowQualityGems + 1
                end
            end
        end
    end

    for _, text in ipairs(tipLines) do
        if text then
            local lvl = text:match("Уровень предмета: (%d+)")
            local cur, max = text:match("Уровень улучшения: (%d+)/(%d+)")
            if lvl then
                -- Authoritative: this line carries the upgraded ilvl in MoP Classic.
                tooltipIlvl = tonumber(lvl)
            elseif cur then
                upgradeLevel, maxUpgrade = tonumber(cur), tonumber(max)
            elseif EMPTY_SOCKET_TEXT[text] then
                emptyGems    = emptyGems + 1
                totalSockets = totalSockets + 1
            elseif tinkerPatterns and not hasEngTinker then
                local textLower = text:lower()
                for _, pattern in ipairs(tinkerPatterns) do
                    if textLower:find(pattern, 1, true) then
                        hasEngTinker = true
                        break
                    end
                end
            end
        end
    end

    -- Sticky last-known-good tinker detection: once a tinker has been seen on the
    -- item currently equipped in this slot, trust it against a later transient empty
    -- tooltip read (tinkers do not change the item link). Invalidate on link change.
    if tinkerPatterns then
        if hasEngTinker then
            tinkerSeen[slot] = link
        elseif tinkerSeen[slot] == link then
            hasEngTinker = true
        end
    end

    -- Sticky last-known-good upgrade level: if this read missed the upgrade line but
    -- we previously parsed one for the same equipped item, reuse it.
    if upgradeLevel and maxUpgrade then
        upgradeSeen[slot] = { link = link, cur = upgradeLevel, max = maxUpgrade }
    else
        local cached = upgradeSeen[slot]
        if cached and cached.link == link then
            upgradeLevel, maxUpgrade = cached.cur, cached.max
        end
    end

    -- Sticky last-known-good current ilvl: if this read missed the "Уровень предмета:"
    -- line, reuse the value last seen for the same equipped item so the chip doesn't
    -- fall back to the base ilvl on a transient incomplete read.
    if tooltipIlvl then
        ilvlSeen[slot] = { link = link, ilvl = tooltipIlvl }
    else
        local cached = ilvlSeen[slot]
        if cached and cached.link == link then
            tooltipIlvl = cached.ilvl
        end
    end

    -- Prefer the upgrade-aware tooltip value over the base-only API ilvl.
    if tooltipIlvl then ilvl = tooltipIlvl end

    -- A complete equipped-item tooltip always carries the "Уровень предмета:" line.
    -- If it was absent AND we had no cached value, the tooltip read was incomplete
    -- (the async data provider wasn't ready) — signal a retry to the caller.
    local incompleteRead = (tooltipIlvl == nil)

    return {
        link           = link,
        name           = name,
        ilvl           = ilvl,       -- current (upgrade-aware) item level
        baseIlvl       = baseIlvl,   -- base item level before MoP gear upgrades
        incompleteRead = incompleteRead,
        quality        = quality,
        emptyGems      = emptyGems,
        totalSockets   = totalSockets,
        gemIDs         = gemIDs,
        outdatedGems   = outdatedGems,
        lowQualityGems = lowQualityGems,
        hasEnchant     = GetEnchantFromLink(link) ~= 0,
        hasEngTinker   = hasEngTinker,
        equipLoc       = equipLoc,
        armorType      = itemSubType,
        upgradeLevel   = upgradeLevel,
        maxUpgrade     = maxUpgrade,
    }
end

-- Returns (equipped average, maximum average). The caller shows the first number and
-- appends "/second" only when the second is higher.
local function GetAvgIlvlForUnit(unit)
    if unit == "player" and GetAverageItemLevel then
        -- GetAverageItemLevel() returns one average that counts the best items in bags
        -- and one for what is actually worn. Returning them unswapped made the character
        -- frame show the bag-inclusive figure while the inspect frame below shows an
        -- equipped-only one, so the two frames could not be compared — and since the
        -- worn average never exceeds the bag-inclusive one, the "/max" half never
        -- appeared. Order the pair by value rather than by position: the average that
        -- may draw on bags is by definition >= the one restricted to worn gear, so this
        -- holds whichever order the client returns them in.
        local a, b = GetAverageItemLevel()
        if a and b then return math.min(a, b), math.max(a, b) end
        return a or b or 0, a or b or 0
    end
    local total = 0
    local mainHandIlvl = 0
    for _, slot in ipairs(ILVL_SLOTS) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            -- The tooltip "Item Level" line (resolved from the equipped item) carries the
            -- upgraded ilvl; GetDetailedItemLevelInfo / GetItemInfo report base only and
            -- would undercount the inspected unit's average. Tooltip first, API fallback.
            local ilvl
            for _, text in ipairs(GetInventoryTooltipLines(unit, slot)) do
                local lvl = text and text:match("Уровень предмета: (%d+)")
                if lvl then ilvl = tonumber(lvl); break end
            end
            ilvl = ilvl
                   or (GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link))
                   or select(4, GetItemInfo(link))
            if ilvl and ilvl > 0 then
                total = total + ilvl
                if slot == 16 then mainHandIlvl = ilvl end
            end
        end
    end
    -- Blizzard's formula uses 16 slots and counts the main hand twice when there is no
    -- off-hand equipped.  This covers 2H weapons, hunter ranged weapons, and any other
    -- class that leaves slot 17 empty.
    if mainHandIlvl > 0 and not GetInventoryItemLink(unit, 17) then
        total = total + mainHandIlvl
    end
    -- Both values are the same on purpose: only equipped gear is visible on an
    -- inspected unit, so there is no separate maximum and the caller shows one number.
    local avg = total / 16
    return avg, avg
end

-- ── Profession helpers ────────────────────────────────────────────────────────

local BS_SOCKET_SLOTS = { [9] = true, [10] = true }  -- Wrist, Hands

-- Skill line IDs are locale-independent internal constants
-- 164 = Blacksmithing, 202 = Engineering, 333 = Enchanting
local profCache = {}
local function HasProfession(skillLine)
    if profCache[skillLine] ~= nil then return profCache[skillLine] end
    local p1, p2 = GetProfessions()
    -- If neither profession slot is populated yet, the data hasn't loaded —
    -- return false but do NOT cache so the next call retries.
    if not p1 and not p2 then return false end
    if p1 then
        local _, _, _, _, _, _, line = GetProfessionInfo(p1)
        if line == skillLine then profCache[skillLine] = true; return true end
    end
    if p2 then
        local _, _, _, _, _, _, line = GetProfessionInfo(p2)
        if line == skillLine then profCache[skillLine] = true; return true end
    end
    profCache[skillLine] = false
    return false
end

local function IsBlacksmith() return HasProfession(164) end
local function IsEngineer()   return HasProfession(202) end
local function IsEnchanter()  return HasProfession(333) end

-- Scan the base item (by ID only, no gems/upgrades) to get its native socket count
local function GetBaseSocketCount(link)
    local itemID = link and link:match("item:(%d+)")
    if not itemID then return 0 end
    local count = 0
    for _, text in ipairs(GetHyperlinkTooltipLines("item:" .. itemID)) do
        if text and EMPTY_SOCKET_TEXT[text] then
            count = count + 1
        end
    end
    return count
end

-- Pure, UI-independent gear evaluation for a unit. Used by both the
-- Character/Inspect overlay (via SetupOverlay's Refresh) and the party/raid
-- roster window. Calls ScanSlot exactly once per slot; callers get the raw
-- ScanSlot data back alongside the derived issue list so they don't have to
-- re-scan for ilvl-chip rendering.
local function EvaluateUnit(unit)
    local equipped, maxLvl = GetAvgIlvlForUnit(unit)

    -- Engineering detection.
    -- Own character: use the profession API directly — no scanning needed.
    -- Inspected player: we can't call GetProfessions() on them, so we do a
    -- lightweight scan of the 3 tinker slots only. A tinker on any one of
    -- them proves engineering. The main loop below re-scans each slot
    -- independently via ScanSlot, so this preliminary scan doesn't interfere.
    local unitIsEngineer = (unit == "player") and IsEngineer()
    if not unitIsEngineer then
        for slot, patterns in pairs(ENG_TINKER_PATTERNS) do
            local link = GetInventoryItemLink(unit, slot)
            if link then
                for _, text in ipairs(GetInventoryTooltipLines(unit, slot)) do
                    if text then
                        local textLower = text:lower()
                        for _, pat in ipairs(patterns) do
                            if textLower:find(pat, 1, true) then
                                unitIsEngineer = true
                                break
                            end
                        end
                    end
                    if unitIsEngineer then break end
                end
            end
            if unitIsEngineer then break end
        end
    end

    local unitIsPlayer = (unit == "player")
    -- Blacksmithing detection, same idea. The profession adds an extra socket
    -- to wrists or hands, so more gems in the link than the item has base
    -- sockets proves it.
    local unitIsBS = unitIsPlayer and IsBlacksmith()
    if not unitIsBS then
        for bsSlot in pairs(BS_SOCKET_SLOTS) do
            local bsLink = GetInventoryItemLink(unit, bsSlot)
            if bsLink and #GetFilledGemIDs(bsLink) > GetBaseSocketCount(bsLink) then
                unitIsBS = true
                break
            end
        end
    end

    -- Enchanting detection, same idea as engineering above.
    local unitIsEnchant = unitIsPlayer and IsEnchanter()
    if not unitIsEnchant then
        for _, ringSlot in ipairs({ 11, 12 }) do
            local ringLink = GetInventoryItemLink(unit, ringSlot)
            if ringLink and GetEnchantFromLink(ringLink) ~= 0 then
                unitIsEnchant = true
                break
            end
        end
    end

    local _, unitClass  = UnitClass(unit)
    local expectedArmor = unitClass and CLASS_ARMOR[unitClass]

    local anyIncomplete = false
    local slots = {}

    for _, info in ipairs(SLOT_BUTTONS) do
        local slot = info.id
        local data = ScanSlot(unit, slot)
        local issues = {}

        if data then
            if data.incompleteRead then anyIncomplete = true end

            -- A tooltip can be truncated rather than absent: after a cold
            -- client start the item's own lines ("Уровень предмета") are
            -- present while the tinker's "Использование:" line, which needs
            -- the enchant's spell data, is not yet. Treat an unseen tinker on
            -- an engineer's tinker slot as incomplete too, so the bounded
            -- retry keeps looking instead of warning.
            if unitIsEngineer and ENG_TINKER_PATTERNS[slot] and not data.hasEngTinker then
                anyIncomplete = true
            end

            -- In some clients GetInventoryItemLink(unit, 17) returns the 2H
            -- weapon link when no off-hand is equipped. Skip all checks then.
            if slot == 17 and data.equipLoc == "INVTYPE_2HWEAPON" then
                issues = {}
            else
                if data.emptyGems > 0 then
                    if data.emptyGems == 1 then
                        table.insert(issues, "Пустое гнездо для самоцвета.")
                    else
                        table.insert(issues, "Пустых гнезд для самоцветов: " .. data.emptyGems .. ".")
                    end
                end

                if data.outdatedGems > 0 then
                    if data.outdatedGems == 1 then
                        table.insert(issues, "Устаревший самоцвет.")
                    else
                        table.insert(issues, "Устаревших самоцветов: " .. data.outdatedGems .. ".")
                    end
                end

                if data.lowQualityGems > 0 then
                    if data.lowQualityGems == 1 then
                        table.insert(issues, "Самоцвет низкого качества.")
                    else
                        table.insert(issues, "Самоцветов низкого качества: " .. data.lowQualityGems .. ".")
                    end
                end

                if slot == 6 and data.totalSockets == 0 then
                    table.insert(issues, "Нет пряжки для пояса.")
                end

                if BS_SOCKET_SLOTS[slot] and unitIsBS then
                    local baseSockets = GetBaseSocketCount(data.link)
                    if data.totalSockets <= baseSockets then
                        table.insert(issues, "Нет дополнительного гнезда (кузнечное дело).")
                    end
                end

                if (slot == 11 or slot == 12) and unitIsEnchant and not data.hasEnchant then
                    table.insert(issues, "Отсутсвуют чары.")
                end

                if ENCHANT_SLOTS[slot] and not data.hasEnchant then
                    local skip = slot == 17
                                 and not (data.equipLoc and ENCHANTABLE_OH[data.equipLoc])
                    if not skip then
                        table.insert(issues, "Отсутсвуют чары.")
                        if ENG_TINKER_PATTERNS[slot] and data.hasEngTinker then
                            table.insert(issues,
                                "На этот слот можно наложить и чары, и улучшение инженера.")
                        end
                    end
                end

                if unitIsEngineer and ENG_TINKER_PATTERNS[slot] then
                    if not data.hasEngTinker then
                        table.insert(issues,
                            "Нет улучшения инженера: " .. ENG_TINKER_NAMES[slot] .. ".")
                    end
                end

                if ARMOR_SPEC_SLOTS[slot] and data.armorType then
                    if expectedArmor and data.armorType ~= expectedArmor
                    and data.armorType ~= "Miscellaneous" then
                        table.insert(issues, "Нарушен бонус специализации брони.")
                    end
                end

                if data.upgradeLevel and data.maxUpgrade
                and data.upgradeLevel < data.maxUpgrade then
                    table.insert(issues, string.format(
                        "Предмет улучшен не полностью (%d/%d).",
                        data.upgradeLevel, data.maxUpgrade))
                end

                if EYE_WEAPON_EQUIPLOC[data.equipLoc]
                and data.ilvl and data.ilvl >= EYE_MIN_ILVL and data.ilvl <= EYE_MAX_ILVL
                and not IsPvPItem(data.name) then
                    local baseSockets = GetBaseSocketCount(data.link)
                    if data.totalSockets <= baseSockets then
                        table.insert(issues, "Нет гнезда от Ока Черного принца.")
                    end
                end

                if slot == 1
                and data.ilvl and data.ilvl >= META_MIN_ILVL and data.ilvl <= META_MAX_ILVL
                and not IsPvPItem(data.name) then
                    for _, gemID in ipairs(data.gemIDs) do
                        local _, _, gemQuality, _, _, _, gemSubType = GetItemInfo(gemID)
                        if gemSubType and gemSubType:find("Meta", 1, true) then
                            if (gemQuality or 0) < 5 then
                                table.insert(issues, "Нет легендарного особого самоцвета.")
                            end
                            break
                        end
                    end
                end
            end
        end

        slots[slot] = {
            data   = data,
            name   = SLOT_NAMES[slot] or ("Slot " .. slot),
            issues = issues,
        }
    end

    return {
        avgIlvl       = equipped,
        maxIlvl       = maxLvl,
        isEngineer    = unitIsEngineer,
        isBS          = unitIsBS,
        isEnchanter   = unitIsEnchant,
        anyIncomplete = anyIncomplete,
        slots         = slots,
    }
end

-- Returns every unit token in the player's current group, "player" first
-- (raid tokens already include the player, so they aren't duplicated).
local function GetGroupUnits()
    if IsInRaid() then
        local units = {}
        for i = 1, GetNumGroupMembers() do
            table.insert(units, "raid" .. i)
        end
        return units
    end
    local units = { "player" }
    if IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            table.insert(units, "party" .. i)
        end
    end
    return units
end

-- Whether `unit` can be inspected right now: connected, within inspect range
-- (distance index 1 — see Wowpedia's CheckInteractDistance), and permitted by
-- CanInspect (e.g. not an invalid target). Covers "different zone/instance"
-- too, since CheckInteractDistance returns false for a unit that isn't
-- loaded client-side.
local function IsUnitInspectable(unit)
    if UnitIsUnit(unit, "player") then return true end
    if not UnitExists(unit) or not UnitIsConnected(unit) then return false end
    if not CheckInteractDistance(unit, 1) then return false end
    return CanInspect(unit) and true or false
end

-- ── Party/raid roster scan ────────────────────────────────────────────────────
-- Throttled NotifyInspect queue: one request in flight at a time, a fixed
-- delay between requests (mirrors how other inspect-based addons avoid the
-- server silently ignoring rapid-fire NotifyInspect calls), and a bounded
-- self-heal timeout if INSPECT_READY never arrives (member went out of range
-- or offline mid-request).

local ROSTER_INSPECT_TIMEOUT = 3   -- seconds to wait for INSPECT_READY
local ROSTER_INSPECT_DELAY   = 1   -- seconds between successive NotifyInspect calls

local rosterState  = {}   -- UnitGUID(unit) -> "pending" | "scanning" | "far" | "done"
local rosterEval   = {}   -- UnitGUID(unit) -> EvaluateUnit(unit) result
local rosterRetryCount = {} -- UnitGUID(unit) -> retries used on the current incomplete read
local rosterQueue  = {}   -- ordered array of unit tokens still to process
local rosterOnUpdate        -- callback(unit) fired whenever a unit's state changes
-- unit token currently waiting on INSPECT_READY, or nil. NOTE: INSPECT_READY is a
-- single global event with no unit payload, so a manual Blizzard-UI inspect fired
-- while the roster scan is mid-flight can be misattributed to this unit — see the
-- "Known limitation" entries in docs/superpowers/plans/2026-07-26-party-raid-gear-check.md.
local rosterInspectWaiting
local rosterTimer            -- single reusable timer frame
local rosterBusy = false     -- true whenever the queue has more work coming

-- GUIDs are stable across raid-index reshuffles; unit tokens (e.g. "raid5")
-- are not, so all persistent state is keyed by GUID rather than by token.
local function RosterKey(unit)
    return UnitGUID(unit) or unit
end

local function RosterSetState(unit, state)
    rosterState[RosterKey(unit)] = state
    if rosterOnUpdate then rosterOnUpdate(unit) end
end

local function RosterAfterDelay(delay, fn)
    rosterTimer = rosterTimer or CreateFrame("Frame")
    local waited = 0
    rosterTimer:SetScript("OnUpdate", function(self, dt)
        waited = waited + dt
        if waited >= delay then
            self:SetScript("OnUpdate", nil)
            fn()
        end
    end)
end

local RosterProcessNext  -- forward declaration; RosterInspectUnit calls it back

local function RosterInspectUnit(unit)
    RosterSetState(unit, "scanning")
    rosterInspectWaiting = unit
    NotifyInspect(unit)
    RosterAfterDelay(ROSTER_INSPECT_TIMEOUT, function()
        if rosterInspectWaiting ~= unit then return end -- INSPECT_READY got there first
        rosterInspectWaiting = nil
        RosterSetState(unit, "far")
        RosterProcessNext()
    end)
end

-- Records unit's EvaluateUnit() result, and retries (bounded, same RETRY_LIMIT/
-- RETRY_DELAY window SetupOverlay's Refresh() uses for the same symptom — see
-- "The scan tooltip" in CLAUDE.md) if the read came back incomplete, rather than
-- settling for "done" on a cold-cache tooltip scrape. No re-inspect is needed for
-- the retry: the item data is already cached client-side from the original
-- NotifyInspect (or is the player's own gear), so re-running EvaluateUnit after a
-- short delay is enough for the tooltip scan to self-heal.
local function RosterEvaluateAndRetry(unit)
    local key = RosterKey(unit)
    local eval = EvaluateUnit(unit)
    rosterEval[key] = eval
    if eval.anyIncomplete and (rosterRetryCount[key] or 0) < RETRY_LIMIT then
        rosterRetryCount[key] = (rosterRetryCount[key] or 0) + 1
        RosterAfterDelay(RETRY_DELAY, function() RosterEvaluateAndRetry(unit) end)
        return
    end
    rosterRetryCount[key] = nil
    RosterSetState(unit, "done")
    RosterAfterDelay(ROSTER_INSPECT_DELAY, RosterProcessNext)
end

RosterProcessNext = function()
    local unit = table.remove(rosterQueue, 1)
    if not unit then
        rosterBusy = false
        return
    end

    if UnitIsUnit(unit, "player") then
        RosterEvaluateAndRetry(unit)
        return
    end

    if not IsUnitInspectable(unit) then
        RosterSetState(unit, "far")
        RosterProcessNext()
        return
    end

    RosterInspectUnit(unit)
end

-- Call from the INSPECT_READY event handler. No-ops if nothing is waiting.
function GearLensRosterOnInspectReady()
    local unit = rosterInspectWaiting
    if not unit then return end
    rosterInspectWaiting = nil
    RosterEvaluateAndRetry(unit)
end

-- Starts (or restarts) a full scan of `units`, in order, discarding any
-- previous scan's state. `onUpdate(unit)` fires whenever a unit's state
-- changes, so the roster window can refresh that one row.
function GearLensRosterStartScan(units, onUpdate)
    rosterQueue = {}
    for _, u in ipairs(units) do table.insert(rosterQueue, u) end
    rosterOnUpdate = onUpdate
    rosterInspectWaiting = nil
    if rosterTimer then rosterTimer:SetScript("OnUpdate", nil) end
    for _, u in ipairs(units) do
        RosterSetState(u, "pending")
    end
    rosterBusy = true
    RosterProcessNext()
end

-- Stops the queue without discarding already-collected results, so closing
-- the roster window mid-scan doesn't keep sending inspect requests in the
-- background.
function GearLensRosterStopScan()
    rosterQueue = {}
    rosterInspectWaiting = nil
    rosterBusy = false
    if rosterTimer then rosterTimer:SetScript("OnUpdate", nil) end
end

-- Re-queues a single unit at the front of the line (the roster window's
-- per-row Recheck button). If the queue is idle, processing starts right
-- away; otherwise it's picked up as soon as the request ahead of it finishes.
function GearLensRosterRecheckUnit(unit)
    RosterSetState(unit, "pending")
    table.insert(rosterQueue, 1, unit)
    if not rosterBusy then
        rosterBusy = true
        RosterProcessNext()
    end
end

-- ── UI helpers ────────────────────────────────────────────────────────────────

-- Solid-colour texture using WHITE8X8 (available since vanilla, no API version risk)
local function SetSolidColor(texture, r, g, b, a)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(r, g, b, a or 1)
end

-- ── Tooltip issue lines ───────────────────────────────────────────────────────
-- Slot buttons call UpdateTooltip every frame, wiping any lines we append in
-- OnEnter.  Instead we hook OnTooltipSetItem which fires after every refresh,
-- so our lines survive each update cycle.

local activeTooltipIssues = nil

GameTooltip:HookScript("OnTooltipSetItem", function(self)
    if not activeTooltipIssues or #activeTooltipIssues == 0 then return end
    self:AddLine(" ")
    for _, line in ipairs(activeTooltipIssues) do
        self:AddLine(line, 1, 0.5, 0, true)
    end
    self:Show()
end)

-- ── Overlay factory ───────────────────────────────────────────────────────────

local function SetupOverlay(parentFrame, slotPrefix, getUnit, showIssues, isActive)
    -- Average ilvl: plain text, no background or border, anchored above weapon slots
    local ilvlPanel = CreateFrame("Frame", nil, parentFrame)
    ilvlPanel:SetHeight(20)
    ilvlPanel:SetFrameLevel(parentFrame:GetFrameLevel() + 10)

    local ilvlLabel = ilvlPanel:CreateFontString(nil, "OVERLAY")
    ilvlLabel:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    ilvlLabel:SetPoint("CENTER", ilvlPanel, "CENTER")

    -- Per-slot labels: { chip, label, warnFrame (or nil) }
    local slotLabels = {}

    local initFrame = CreateFrame("Frame")
    initFrame:SetScript("OnUpdate", function(sf)
        sf:SetScript("OnUpdate", nil)

        for _, info in ipairs(SLOT_BUTTONS) do

            local btn = _G[slotPrefix .. info.name]
                     or _G["Character" .. info.name]
                     or _G[info.name]
            if btn then
                local baseLevel = btn:GetFrameLevel()

                -- ── Dark chip behind the ilvl number ─────────────────────────
                local chip = CreateFrame("Frame", nil, btn)
                chip:SetHeight(16)
                chip:SetFrameLevel(baseLevel + 3)
                -- Anchor left/right edges inset from the slot button so the chip
                -- exactly fills the inner icon area rather than overlapping the border.
                chip:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  1, 1)
                chip:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 1)

                local chipBg = chip:CreateTexture(nil, "BACKGROUND")
                chipBg:SetAllPoints()
                SetSolidColor(chipBg, 0, 0, 0, 0.72)

                local label = chip:CreateFontString(nil, "OVERLAY")
                label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                label:SetPoint("CENTER", chip, "CENTER", 1, 0)

                -- Smaller, dimmer base-ilvl number shown to the right of the current
                -- ilvl when the item has been upgraded (current > base).
                local subLabel = chip:CreateFontString(nil, "OVERLAY")
                subLabel:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
                subLabel:SetTextColor(0.7, 0.7, 0.7)
                subLabel:Hide()

                chip:Hide()

                -- ── Warning icon for gear issues (own character only) ─────────
                local warnFrame = nil
                if showIssues then
                    warnFrame = CreateFrame("Frame", nil, btn)
                    warnFrame:SetAllPoints(btn)
                    warnFrame:SetFrameLevel(baseLevel + 5)
                    -- Mouse disabled so clicks pass through to the slot button beneath
                    warnFrame:EnableMouse(false)

                    -- Semi-transparent dark overlay to further highlight the issue
                    local warnBacking = warnFrame:CreateTexture(nil, "BACKGROUND")
                    warnBacking:SetAllPoints()
                    warnBacking:SetTexture("Interface\\Buttons\\WHITE8X8")
                    warnBacking:SetVertexColor(0, 0, 0, 0.55)

                    -- Help button texture (contains the full circular button graphic)
                    local warnIcon = warnFrame:CreateTexture(nil, "ARTWORK")
                    warnIcon:SetAllPoints()
                    warnIcon:SetTexture(616343)

                    warnFrame._issues = {}

                    -- Set active issues so the GameTooltip hook can append them
                    -- after every UpdateTooltip refresh cycle
                    btn:HookScript("OnEnter", function()
                        if warnFrame:IsShown() and #warnFrame._issues > 0 then
                            activeTooltipIssues = warnFrame._issues
                        end
                    end)
                    btn:HookScript("OnLeave", function()
                        activeTooltipIssues = nil
                    end)
                    warnFrame:Hide()
                end

                slotLabels[info.id] = { chip = chip, label = label, sub = subLabel, warn = warnFrame }
            end
        end

        -- Anchor ilvl label above the weapon slots
        local mainBtn = _G[slotPrefix .. "MainHandSlot"]
                     or _G["Character" .. "MainHandSlot"]
                     or _G["MainHandSlot"]
        local offBtn  = _G[slotPrefix .. "SecondaryHandSlot"]
                     or _G["Character" .. "SecondaryHandSlot"]
                     or _G["SecondaryHandSlot"]
        if mainBtn and offBtn then
            ilvlPanel:SetPoint("BOTTOMLEFT",  mainBtn, "TOPLEFT",  0, 8)
            ilvlPanel:SetPoint("BOTTOMRIGHT", offBtn,  "TOPRIGHT", 0, 8)
        end

    end)

    -- ── Refresh ───────────────────────────────────────────────────────────────
    local HideAll  -- forward declaration; defined after Refresh
    local retryFrame           -- lazily-created timer for incomplete-read retries
    local retryCount = 0
    local function Refresh()
        local unit = getUnit()
        local evalResult = EvaluateUnit(unit)
        local anyIncomplete = evalResult.anyIncomplete

        -- Average ilvl badge
        local equipped, maxLvl = evalResult.avgIlvl, evalResult.maxIlvl
        if maxLvl and maxLvl > equipped + 0.05 then
            ilvlLabel:SetFormattedText(
                "|cFF00FF00%.1f|r|cFFAAAAAA/%.1f|r", equipped, maxLvl)
        else
            ilvlLabel:SetFormattedText("|cFF00FF00%.1f|r", equipped)
        end

        -- Per-slot update
        for _, info in ipairs(SLOT_BUTTONS) do
            local slot  = info.id
            local entry = slotLabels[slot]
            if entry then
                local slotEval = evalResult.slots[slot]
                local data = slotEval and slotEval.data

                -- Ilvl chip
                if data and data.ilvl and data.ilvl > 0 then
                    local c = QUALITY_COLOR[data.quality] or QUALITY_COLOR[1]
                    entry.label:SetTextColor(c[1], c[2], c[3])
                    entry.label:SetText(data.ilvl)
                    if entry.sub and data.baseIlvl and data.baseIlvl > 0
                    and data.baseIlvl < data.ilvl then
                        entry.sub:SetText(data.baseIlvl)
                        entry.label:ClearAllPoints()
                        entry.label:SetPoint("CENTER", entry.chip, "CENTER", -6, 0)
                        entry.sub:ClearAllPoints()
                        entry.sub:SetPoint("LEFT", entry.label, "RIGHT", -2, -1)
                        entry.sub:Show()
                    elseif entry.sub then
                        entry.sub:Hide()
                        entry.label:ClearAllPoints()
                        entry.label:SetPoint("CENTER", entry.chip, "CENTER", 1, 0)
                    end
                    entry.chip:Show()
                else
                    entry.chip:Hide()
                end

                -- Warning icon
                if showIssues and entry.warn then
                    local issues = slotEval and slotEval.issues or {}
                    if #issues > 0 then
                        entry.warn._issues = issues
                        entry.warn:Show()
                    else
                        entry.warn._issues = {}
                        entry.warn:Hide()
                    end
                end
            end
        end

        if isActive and not isActive() then
            HideAll()
            retryCount = 0
        else
            ilvlPanel:Show()
            -- If any equipped slot returned an incomplete tooltip read, the
            -- async data provider wasn't ready yet. Re-scan shortly (bounded)
            -- so the frame self-heals to correct values without needing a
            -- /reload.
            if anyIncomplete and retryCount < RETRY_LIMIT then
                retryCount = retryCount + 1
                retryFrame = retryFrame or CreateFrame("Frame")
                local waited = 0
                retryFrame:SetScript("OnUpdate", function(self, dt)
                    waited = waited + dt
                    if waited >= RETRY_DELAY then
                        self:SetScript("OnUpdate", nil)
                        Refresh()
                    end
                end)
            else
                retryCount = 0
            end
        end
    end

    HideAll = function()
        ilvlPanel:Hide()
        for _, entry in pairs(slotLabels) do
            entry.chip:Hide()
            if entry.warn then entry.warn:Hide() end
        end
    end

    -- Collect all slots that currently have visible issues (used by the whisper button)
    local function GetAllIssues()
        local result = {}
        for _, info in ipairs(SLOT_BUTTONS) do
            local slot  = info.id
            local entry = slotLabels[slot]
            if entry and entry.warn and entry.warn._issues and #entry.warn._issues > 0 then
                table.insert(result, {
                    name   = SLOT_NAMES[slot] or ("Slot " .. slot),
                    issues = entry.warn._issues,
                })
            end
        end
        return result
    end

    ilvlPanel:Hide()
    return Refresh, HideAll, GetAllIssues
end

-- ── Party/raid roster window ─────────────────────────────────────────────────

local ROSTER_ROW_HEIGHT = 22
local ROSTER_MAX_ROWS   = 40  -- full raid

local rosterFrame, rosterScrollChild, rosterRows

-- NOTE ON CLOSURES: `row` below is the table this function returns, built as
-- a local BEFORE any :SetScript wiring so every closure captures that same
-- table (not the `frame` widget). GearLensRefreshRosterRows mutates row.unit on every
-- refresh; Tasks 6/7/8 each add one more :SetScript call here, all placed
-- right before `return row` so they close over the fully-built table and see
-- row.unit updates made after the row was created.
local function CreateRosterRow(parent, index)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(340, ROSTER_ROW_HEIGHT)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROSTER_ROW_HEIGHT)
    frame:EnableMouse(true)

    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", frame, "LEFT", 4, 0)
    name:SetWidth(110)
    name:SetJustifyH("LEFT")

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("LEFT", name, "RIGHT", 4, 0)
    status:SetWidth(110)
    status:SetJustifyH("LEFT")

    local recheckBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    recheckBtn:SetSize(96, 18)
    recheckBtn:SetPoint("LEFT", status, "RIGHT", 4, 0)
    recheckBtn:SetText("Перепроверить")
    recheckBtn:Hide()

    local whisperBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    whisperBtn:SetSize(24, 18)
    whisperBtn:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
    whisperBtn:SetText("Ш")
    whisperBtn:Hide()

    local reportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reportBtn:SetSize(24, 18)
    reportBtn:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    reportBtn:SetText("О")
    reportBtn:Hide()

    frame:Hide()

    local row = {
        frame   = frame,
        name    = name,
        status  = status,
        recheck = recheckBtn,
        whisper = whisperBtn,
        report  = reportBtn,
        unit    = nil,
    }

    -- Tasks 6/7/8 insert more :SetScript calls here, above this line.

    frame:SetScript("OnEnter", function(self)
        local unit = row.unit
        if not unit or rosterState[RosterKey(unit)] ~= "done" then return end
        local eval = rosterEval[RosterKey(unit)]
        if not eval then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(UnitName(unit) or unit)
        local any = false
        for _, info in ipairs(SLOT_BUTTONS) do
            local slotEval = eval.slots[info.id]
            if slotEval and #slotEval.issues > 0 then
                any = true
                for _, issue in ipairs(slotEval.issues) do
                    GameTooltip:AddLine("[" .. slotEval.name .. "] " .. issue, 1, 0.5, 0, true)
                end
            end
        end
        if not any then
            GameTooltip:AddLine("Проблем со снаряжением не найдено.", 0, 1, 0)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    recheckBtn:SetScript("OnClick", function()
        if row.unit then GearLensRosterRecheckUnit(row.unit) end
    end)

    whisperBtn:SetScript("OnClick", function()
        if row.unit then GearLensWhisperIssues(row.unit, GearLensBuildIssueList(rosterEval[RosterKey(row.unit)])) end
    end)
    reportBtn:SetScript("OnClick", function()
        if row.unit then GearLensReportIssuesToChat(row.unit, GearLensBuildIssueList(rosterEval[RosterKey(row.unit)])) end
    end)

    return row
end

local function EnsureRosterFrame()
    if rosterFrame then return end

    rosterFrame = CreateFrame("Frame", "GearLensRosterFrame", UIParent, "BackdropTemplate")
    rosterFrame:SetSize(380, 360)
    rosterFrame:SetPoint("CENTER")
    rosterFrame:SetFrameStrata("HIGH")
    rosterFrame:SetMovable(true)
    rosterFrame:EnableMouse(true)
    rosterFrame:RegisterForDrag("LeftButton")
    rosterFrame:SetScript("OnDragStart", rosterFrame.StartMoving)
    rosterFrame:SetScript("OnDragStop", rosterFrame.StopMovingOrSizing)
    rosterFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    rosterFrame:Hide()
    rosterFrame:SetScript("OnHide", GearLensRosterStopScan)

    local title = rosterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", rosterFrame, "TOP", 0, -16)
    title:SetText("GearLens: Проверка группы")

    local closeBtn = CreateFrame("Button", nil, rosterFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", rosterFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() rosterFrame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "GearLensRosterScrollFrame", rosterFrame,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", rosterFrame, "TOPLEFT", 12, -40)
    scroll:SetPoint("BOTTOMRIGHT", rosterFrame, "BOTTOMRIGHT", -30, 16)

    rosterScrollChild = CreateFrame("Frame", nil, scroll)
    rosterScrollChild:SetSize(340, ROSTER_ROW_HEIGHT * ROSTER_MAX_ROWS)
    scroll:SetScrollChild(rosterScrollChild)

    rosterRows = {}
    for i = 1, ROSTER_MAX_ROWS do
        rosterRows[i] = CreateRosterRow(rosterScrollChild, i)
    end
end

local rosterUnitRow = {}  -- unit token -> row index, rebuilt each GearLensRefreshRosterRows call

local function DescribeRosterRow(row, unit)
    row.recheck:Hide()
    row.whisper:Hide()
    row.report:Hide()

    if not unit then
        row.status:SetText("")
        return
    end

    local state = rosterState[RosterKey(unit)]
    if state == "pending" then
        row.status:SetTextColor(0.7, 0.7, 0.7)
        row.status:SetText("В очереди...")
    elseif state == "scanning" then
        row.status:SetTextColor(0.7, 0.7, 0.7)
        row.status:SetText("Проверка...")
    elseif state == "far" then
        row.status:SetTextColor(1, 0.3, 0.3)
        row.status:SetText("Далеко")
        row.recheck:Show()
    elseif state == "done" then
        local eval = rosterEval[RosterKey(unit)]
        if not eval then
            row.status:SetText("")
            return
        end
        local issueCount = 0
        for _, slotEval in pairs(eval.slots) do
            issueCount = issueCount + #slotEval.issues
        end
        if issueCount > 0 then
            row.status:SetTextColor(1, 0.5, 0)
            row.status:SetFormattedText("%.0f — проблем: %d", eval.avgIlvl, issueCount)
            if not UnitIsUnit(unit, "player") then
                row.whisper:Show()
                row.report:Show()
            end
        else
            row.status:SetTextColor(0.12, 1, 0)
            row.status:SetFormattedText("%.0f — ОК", eval.avgIlvl)
        end
    else
        row.status:SetText("")
    end
end

function GearLensRefreshRosterRows()
    local units = GetGroupUnits()
    wipe(rosterUnitRow)
    for i, row in ipairs(rosterRows) do
        local unit = units[i]
        row.unit = unit
        if unit then
            rosterUnitRow[unit] = i
            local _, class = UnitClass(unit)
            local color = class and RAID_CLASS_COLORS[class]
            if color then
                row.name:SetTextColor(color.r, color.g, color.b)
            else
                row.name:SetTextColor(1, 1, 1)
            end
            row.name:SetText(UnitName(unit) or unit)
            DescribeRosterRow(row, unit)
            row.frame:Show()
        else
            row.frame:Hide()
        end
    end
end

local function OnRosterUnitUpdate(unit)
    local idx = rosterUnitRow[unit]
    local row = idx and rosterRows[idx]
    if row then DescribeRosterRow(row, unit) end
end

function GearLensToggleRosterWindow()
    EnsureRosterFrame()
    if rosterFrame:IsShown() then
        rosterFrame:Hide()
        return
    end
    GearLensRefreshRosterRows()
    GearLensRosterStartScan(GetGroupUnits(), OnRosterUnitUpdate)
    rosterFrame:Show()
end

-- If the group's composition changes while the roster window is open,
-- rebuild the row list but leave already-"done" members alone — only newly
-- present members (not yet marked "done"/"pending"/"scanning" for their
-- GUID) get queued via GearLensRosterRecheckUnit, which reuses the same
-- queue-or-run-now logic the per-row Recheck button uses. This does NOT
-- reset state on every roster event, so a member who finished scanning a
-- moment ago isn't redundantly re-inspected because someone else joined or
-- left.
--
-- GUIDs that drop out of the group entirely (member left) are also purged from
-- rosterState/rosterEval here. Without this, a member who leaves and rejoins
-- later in the same window-open session would keep showing their stale
-- pre-leave "done" snapshot with no indication it's stale, since a rejoined
-- member's GUID is identical to before and the state-based re-queue check
-- above would see "done" and skip it.
local rosterUpdateFrame = CreateFrame("Frame")
rosterUpdateFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterUpdateFrame:SetScript("OnEvent", function()
    if not (rosterFrame and rosterFrame:IsShown()) then return end

    GearLensRefreshRosterRows()

    local currentUnits = GetGroupUnits()
    local currentGUIDs = {}
    for _, unit in ipairs(currentUnits) do
        currentGUIDs[RosterKey(unit)] = true
    end
    for key in pairs(rosterState) do
        if not currentGUIDs[key] then
            rosterState[key] = nil
            rosterEval[key] = nil
            rosterRetryCount[key] = nil
        end
    end

    for _, unit in ipairs(currentUnits) do
        local state = rosterState[RosterKey(unit)]
        if state ~= "done" and state ~= "pending" and state ~= "scanning" then
            GearLensRosterRecheckUnit(unit)
        end
    end
end)

-- ── Minimap button ────────────────────────────────────────────────────────────
-- Fixed position (no dragging, no SavedVariables) — simplest option that
-- still gives one-click access to the roster window.

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "GearLensMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    local angle = math.rad(220)
    btn:SetPoint("CENTER", Minimap, "CENTER",
        -80 * math.cos(angle), 80 * math.sin(angle))

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 1)
    icon:SetTexture("Interface\\AddOns\\GearLensRu\\GearLens_Icon")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetScript("OnClick", GearLensToggleRosterWindow)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("GearLens")
        GameTooltip:AddLine("Проверка снаряжения группы", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ── Addon init ────────────────────────────────────────────────────────────────

local inspectUnit    = "target"
local inspectRefresh, inspectHide, inspectGetIssues
local charRefresh
local charNeedsRecheck = false

-- Chat-channel resolver (used by Report to Chat button)
local function GetChatChannel()
    if IsInRaid() then return "RAID" end
    local instCat = LE_PARTY_CATEGORY_INSTANCE or 2
    if UnitExists("party1") then
        return IsInGroup(instCat) and "INSTANCE_CHAT" or "PARTY"
    end
    return "SAY"
end

-- Sends each flagged slot's issues as a whisper to `unit`. Shared by the
-- Inspect frame's Whisper button and the roster window's per-row button.
function GearLensWhisperIssues(unit, allIssues)
    if #allIssues == 0 then
        print("|cFF00FF00GearLens:|r Проблем со снаряжением не найдено.")
        return
    end
    local name, realm = UnitName(unit)
    if not name then return end
    local target = (realm and realm ~= "") and (name .. "-" .. realm) or name
    SendChatMessage("GearLens: отчет по снаряжению", "WHISPER", nil, target)
    for _, entry in ipairs(allIssues) do
        for _, issue in ipairs(entry.issues) do
            SendChatMessage("[" .. entry.name .. "] " .. issue, "WHISPER", nil, target)
        end
    end
end

-- Sends each flagged slot's issues to the current chat channel, prefixed
-- with the target's name. Shared the same way as GearLensWhisperIssues above.
function GearLensReportIssuesToChat(unit, allIssues)
    if #allIssues == 0 then
        print("|cFF00FF00GearLens:|r Проблем со снаряжением не найдено.")
        return
    end
    local name    = UnitName(unit) or "Неизвестно"
    local channel = GetChatChannel()
    SendChatMessage("GearLens: проблемы со снаряжением у " .. name .. ":", channel)
    for _, entry in ipairs(allIssues) do
        for _, issue in ipairs(entry.issues) do
            SendChatMessage("[" .. entry.name .. "] " .. issue, channel)
        end
    end
end

-- Converts an EvaluateUnit() result into the { name, issues } array shape
-- GearLensWhisperIssues/GearLensReportIssuesToChat expect (same shape GetAllIssues() returns).
function GearLensBuildIssueList(eval)
    local result = {}
    if not eval then return result end
    for _, info in ipairs(SLOT_BUTTONS) do
        local slotEval = eval.slots[info.id]
        if slotEval and #slotEval.issues > 0 then
            table.insert(result, { name = slotEval.name, issues = slotEval.issues })
        end
    end
    return result
end

local function SetupInspectOverlay()
    if not InspectFrame or inspectRefresh then return end
    local function GetInspectUnit()
        return (InspectFrame and InspectFrame.unit) or inspectUnit
    end

    local rawRefresh, rawHide, rawGetIssues = SetupOverlay(
        InspectFrame, "Inspect", GetInspectUnit, true,
        function() return InspectPaperDollFrame and InspectPaperDollFrame:IsShown() end)
    inspectHide      = rawHide
    inspectGetIssues = rawGetIssues

    -- ── Whisper Issues button ─────────────────────────────────────────────────
    local whisperBtn = CreateFrame("Button", nil, InspectFrame, "UIPanelButtonTemplate")
    whisperBtn:SetSize(110, 22)
    whisperBtn:SetFrameStrata("HIGH")
    whisperBtn:SetPoint("BOTTOMRIGHT", InspectFrame, "BOTTOMRIGHT", -8, 8)
    whisperBtn:SetText("Шепнуть игроку")
    whisperBtn:Hide()
    whisperBtn:SetScript("OnClick", function()
        local unit = (InspectFrame and InspectFrame.unit) or inspectUnit
        GearLensWhisperIssues(unit, inspectGetIssues())
    end)

    -- ── Report to Chat button ─────────────────────────────────────────────────
    local reportBtn = CreateFrame("Button", nil, InspectFrame, "UIPanelButtonTemplate")
    reportBtn:SetSize(110, 22)
    reportBtn:SetFrameStrata("HIGH")
    reportBtn:SetPoint("BOTTOMLEFT", InspectFrame, "BOTTOMLEFT", 8, 8)
    reportBtn:SetText("Отправить в чат")
    reportBtn:Hide()
    reportBtn:SetScript("OnClick", function()
        local unit = (InspectFrame and InspectFrame.unit) or inspectUnit
        GearLensReportIssuesToChat(unit, inspectGetIssues())
    end)

    -- Wrap the raw refresh so both buttons are shown/hidden based on issue state
    local function doRefresh()
        rawRefresh()
        -- Visibility follows the gear tab alone, not the issue count. Deriving it from
        -- issues made both buttons flicker on for about a second whenever a player was
        -- inspected: the first scan runs before the tooltip data has settled, reports
        -- issues that are not real, and the settled re-scan then hides them again.
        -- With nothing to report a click is harmless — it prints
        -- "Проблем со снаряжением не найдено." and sends nothing.
        local gearTab = (InspectPaperDollFrame and InspectPaperDollFrame:IsShown())
                        and true or false
        whisperBtn:SetShown(gearTab)
        reportBtn:SetShown(gearTab)
    end
    inspectRefresh = doRefresh

    if InspectPaperDollFrame then
        InspectPaperDollFrame:HookScript("OnShow", doRefresh)
        InspectPaperDollFrame:HookScript("OnHide", inspectHide)
        InspectPaperDollFrame:HookScript("OnHide", function()
            whisperBtn:Hide()
            reportBtn:Hide()
        end)
    end
    InspectFrame:HookScript("OnShow", function()
        if inspectRefresh then inspectRefresh() end
    end)
    InspectFrame:HookScript("OnHide", inspectHide)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("INSPECT_READY")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("SKILL_LINES_CHANGED")
loader:SetScript("OnEvent", function(_, event, arg1)

    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            local charHide
            charRefresh, charHide = SetupOverlay(
                CharacterFrame,
                "", function() return "player" end, true,
                function() return PaperDollFrame and PaperDollFrame:IsShown() end)

            CharacterFrame:HookScript("OnHide", charHide)
            PaperDollFrame:HookScript("OnShow", charRefresh)
            PaperDollFrame:HookScript("OnShow", function()
                if not charNeedsRecheck then return end
                charNeedsRecheck = false
                local waited = 0
                local delayFrame = CreateFrame("Frame")
                delayFrame:SetScript("OnUpdate", function(self, dt)
                    waited = waited + dt
                    if waited >= 1.5 then
                        self:SetScript("OnUpdate", nil)
                        if PaperDollFrame:IsShown() then charRefresh() end
                    end
                end)
            end)
            PaperDollFrame:HookScript("OnHide", charHide)

            -- Re-scan when the player's gear changes while the character frame is open.
            -- PLAYER_EQUIPMENT_CHANGED's first arg is a slot number, NOT a unit, so it
            -- must be handled separately from UNIT_INVENTORY_CHANGED (whose arg is a unit).
            local equipDelay
            local function ScheduleCharRefresh()
                if not (CharacterFrame:IsShown() and charRefresh) then return end
                -- Immediate pass for responsiveness, then a delayed pass once the
                -- newly-equipped item's upgraded ilvl / socket / enchant data is cached.
                charRefresh()
                equipDelay = equipDelay or CreateFrame("Frame")
                local waited = 0
                equipDelay:SetScript("OnUpdate", function(self, dt)
                    waited = waited + dt
                    if waited >= 0.3 then
                        self:SetScript("OnUpdate", nil)
                        if CharacterFrame:IsShown() then charRefresh() end
                    end
                end)
            end

            -- GET_ITEM_INFO_RECEIVED fires once the server delivers data for an item
            -- that GetItemInfo had to request. Until it arrives the equipped item's
            -- tooltip is short or truncated, so a scan taken during that window misses
            -- the ilvl, upgrade, socket and tinker lines. It arrives in bursts (bags,
            -- bank, other players' gear), so coalesce into one re-scan.
            local itemDataFrame, itemDataPending
            local function ScheduleItemDataRefresh()
                if itemDataPending then return end
                itemDataPending = true
                itemDataFrame = itemDataFrame or CreateFrame("Frame")
                local waited = 0
                itemDataFrame:SetScript("OnUpdate", function(self, dt)
                    waited = waited + dt
                    if waited >= 0.3 then
                        self:SetScript("OnUpdate", nil)
                        itemDataPending = false
                        if CharacterFrame and CharacterFrame:IsShown() and charRefresh then
                            charRefresh()
                        end
                        if InspectFrame and InspectFrame:IsShown() and inspectRefresh then
                            inspectRefresh()
                        end
                    end
                end)
            end

            local evtFrame = CreateFrame("Frame")
            evtFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
            evtFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
            evtFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
            evtFrame:SetScript("OnEvent", function(_, event, arg1)
                if event == "GET_ITEM_INFO_RECEIVED" then
                    ScheduleItemDataRefresh()
                    return
                end
                -- UNIT_INVENTORY_CHANGED fires for any unit; only react to the player.
                if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
                ScheduleCharRefresh()
            end)

            -- LoadAddOn("Blizzard_InspectUI") -- TODO: LoadAddon is not working
            SetupInspectOverlay()
            CreateMinimapButton()

        elseif arg1 == "Blizzard_InspectUI" then
            SetupInspectOverlay()
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "SKILL_LINES_CHANGED" then
        -- Profession data may not be available yet when ADDON_LOADED fires during login.
        -- Clear the cache here so the next Refresh() re-queries with valid data.
        -- SKILL_LINES_CHANGED also covers mid-session profession changes.
        table.wipe(profCache)

        -- After a zone transition the item tooltip cache (including tinker "Use:" lines)
        -- may not be fully repopulated yet.  Set a flag so the next PaperDoll open
        -- triggers a delayed re-scan once the client data has settled.
        if event == "PLAYER_ENTERING_WORLD" then
            charNeedsRecheck = true
            -- If the character frame is already open, OnShow won't fire —
            -- schedule the delayed re-scan directly.
            if PaperDollFrame and PaperDollFrame:IsShown() and charRefresh then
                local waited = 0
                local delayFrame = CreateFrame("Frame")
                delayFrame:SetScript("OnUpdate", function(self, dt)
                    waited = waited + dt
                    if waited >= 1.5 then
                        self:SetScript("OnUpdate", nil)
                        charNeedsRecheck = false
                        if PaperDollFrame:IsShown() then charRefresh() end
                    end
                end)
            end
        end

    elseif event == "INSPECT_READY" then
        SetupInspectOverlay()
        GearLensRosterOnInspectReady()

        if InspectFrame and InspectFrame:IsShown() and inspectRefresh then
            -- Normal manual inspect: immediate pass for ilvl numbers, then a
            -- delayed pass once gem/enchant data is fully cached.
            inspectRefresh()
            local waited = 0
            local delayFrame = CreateFrame("Frame")
            delayFrame:SetScript("OnUpdate", function(self, dt)
                waited = waited + dt
                if waited >= 0.5 then
                    self:SetScript("OnUpdate", nil)
                    if InspectFrame and InspectFrame:IsShown() and inspectRefresh then
                        inspectRefresh()
                    end
                end
            end)
        end
    end
end)

-- ── Debug slash command ─────────────────────────────────────────────────────────
-- "/glr" dumps tinker-line readability for the three engineering slots and the
-- current-vs-base item level for every equipped slot.
-- "/glr diag" adds the evidence behind a wrong result: line counts, the actual
-- "Использование:"/"Уровень ..." lines and each tinker pattern's match result.
-- "/glr dump <slot>" prints every tooltip line for one slot.
-- Neither retries, so both report the raw current state — run them right after a
-- cold client start to see an incomplete read, not after a /reload (which keeps the
-- client's item cache warm and therefore cannot reproduce it).
SLASH_GEARLENSRU1 = "/glr"
SlashCmdList["GEARLENSRU"] = function(msg)
    local usingCTI = (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) and true or false
    local cmd, arg = (msg or ""):lower():match("^%s*(%a*)%s*(%d*)")

    if cmd == "group" then
        GearLensToggleRosterWindow()
        return
    end

    if cmd == "roster" then
        local units = GetGroupUnits()
        print(("|cFF00FF00GearLens:|r Проверка группы: %d участников"):format(#units))
        for _, unit in ipairs(units) do
            local key   = RosterKey(unit)
            local state = rosterState[key] or "(нет данных)"
            local eval  = rosterEval[key]
            local inRange = IsUnitInspectable(unit)
            local ilvlText = eval and string.format("%.0f", eval.avgIlvl) or "—"
            print(("  %s (%s): состояние=%s  в радиусе=%s  ilvl=%s"):format(
                UnitName(unit) or unit, unit, state, tostring(inRange), ilvlText))
        end
        return
    end

    -- "/glr diag": the decisive evidence in one paste. For each tinker slot it shows
    -- how many lines the scan returned, every "Использование:" line found, and the
    -- per-pattern match result; for the ilvl slots, every "Уровень ..." line found.
    -- Substrings are matched without their first letter so a Cyrillic capital that
    -- string.lower() cannot fold does not hide the line from this diagnostic itself.
    if cmd == "diag" then
        local owner = scanTip:GetOwner()
        print(("|cFF00FF00GearLens:|r C_TooltipInfo=%s  владелец подсказки=%s  показана=%s")
            :format(type(C_TooltipInfo),
                    owner and (owner:GetName() or "без имени") or "|cFFFF0000нет|r",
                    tostring(scanTip:IsShown())))
        for _, slot in ipairs({ 6, 10, 15, 1, 8 }) do
            local link = GetInventoryItemLink("player", slot)
            if not link then
                print(("|cFF00FF00GearLens:|r [%d] слот пуст"):format(slot))
            else
                local lines = GetInventoryTooltipLines("player", slot)
                local hits, blank = 0, 0
                for _, text in ipairs(lines) do
                    if text == "" then blank = blank + 1 end
                end
                -- Blank count separates "the scan returned nothing" from "the scan
                -- returned line slots whose FontStrings had no text" — different faults.
                print(("|cFF00FF00GearLens:|r [%d] строк: %d  пустых: %d  NumLines()=%s")
                    :format(slot, #lines, blank, tostring(scanTip:NumLines())))
                for i = 1, math.min(3, #lines) do
                    print(("  сырая %d: [%s]"):format(i, lines[i]))
                end
                for i, text in ipairs(lines) do
                    if text ~= "" and (text:find("спользован", 1, true)
                                    or text:find("ровень предмета", 1, true)
                                    or text:find("ровень улучшения", 1, true)) then
                        hits = hits + 1
                        print(("  %d: [%s]"):format(i, text))
                    end
                end
                if hits == 0 then print("  (нет строк 'Использование:' / 'Уровень ...')") end
                for _, pat in ipairs(ENG_TINKER_PATTERNS[slot] or {}) do
                    local found = false
                    for _, text in ipairs(lines) do
                        if text:lower():find(pat, 1, true) then found = true; break end
                    end
                    print(("  pat '%s...' -> %s"):format(pat:sub(1, 24), tostring(found)))
                end
            end
        end
        return
    end

    -- "/glr dump <slot>": raw tooltip lines for one equipped slot, exactly as the
    -- scanner sees them. This is the evidence for why a line was or was not matched.
    if cmd == "dump" then
        local slot = tonumber(arg)
        if not slot then
            print("|cFF00FF00GearLens:|r Использование: /glr dump <номер слота>")
            return
        end
        if not GetInventoryItemLink("player", slot) then
            print(("|cFF00FF00GearLens:|r [%d] слот пуст"):format(slot))
            return
        end
        local lines = GetInventoryTooltipLines("player", slot)
        print(("|cFF00FF00GearLens:|r [%d] строк: %d  путь: %s  NumLines()=%s")
            :format(slot, #lines, usingCTI and "C_TooltipInfo" or "scrape",
                    tostring(scanTip:NumLines())))
        for i, text in ipairs(lines) do
            print(("  %d: [%s]"):format(i, tostring(text)))
        end
        return
    end

    print(("|cFF00FF00GearLens:|r Engineer=%s  C_TooltipInfo=%s")
        :format(tostring(IsEngineer()), tostring(usingCTI)))
    for _, slot in ipairs({ 6, 10, 15 }) do
        local name = ENG_TINKER_NAMES[slot]
        local patterns = ENG_TINKER_PATTERNS[slot]
        local link = GetInventoryItemLink("player", slot)
        if not link then
            print(("|cFF00FF00GearLens:|r [%d] %s: (слот пуст)"):format(slot, name))
        else
            local found = false
            for _, text in ipairs(GetInventoryTooltipLines("player", slot)) do
                if text then
                    local textLower = text:lower()
                    for _, pat in ipairs(patterns) do
                        if textLower:find(pat, 1, true) then found = true; break end
                    end
                end
                if found then break end
            end
            print(("|cFF00FF00GearLens:|r [%d] %s: улучшение %s"):format(
                slot, name, found and "|cFF00FF00НАЙДЕНО|r" or "|cFFFF0000НЕ НАЙДЕНО|r"))
        end
    end
    -- Current (upgraded) vs base item level per equipped slot; upgraded ones marked.
    for _, slot in ipairs(ILVL_SLOTS) do
        local data = ScanSlot("player", slot)
        if data and data.ilvl then
            local upgraded = data.baseIlvl and data.baseIlvl < data.ilvl
            print(("|cFF00FF00GearLens:|r [%d] ilvl cur=%s base=%s%s%s"):format(
                slot, tostring(data.ilvl), tostring(data.baseIlvl),
                upgraded and " |cFF00FF00(улучшен)|r" or "",
                data.incompleteRead and " |cFFFF0000(неполное чтение)|r" or ""))
        end
    end
end
