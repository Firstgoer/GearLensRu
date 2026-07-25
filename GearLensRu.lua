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
    [1]  = "Head",      [2]  = "Neck",      [3]  = "Shoulder",
    [5]  = "Chest",     [6]  = "Waist",     [7]  = "Legs",
    [8]  = "Feet",      [9]  = "Wrist",     [10] = "Hands",
    [11] = "Ring 1",    [12] = "Ring 2",
    [13] = "Trinket 1", [14] = "Trinket 2",
    [15] = "Back",      [16] = "Main Hand", [17] = "Off Hand",
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
    [6]  = "Никтоускорители",
    [10] = "Нейронные пружины",
    [15] = "Гоблинский планер",
}

-- ── Scan tooltip ──────────────────────────────────────────────────────────────

local scanTip = CreateFrame("GameTooltip", "GearLensScanTip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- ── Tooltip readers ─────────────────────────────────────────────────────────────
-- Scraping a hidden, never-shown GameTooltip's FontStrings (SetInventoryItem +
-- GearLensScanTipTextLeftN:GetText()) is unreliable on the modern client: it can
-- intermittently omit dynamically-appended lines (e.g. an engineering tinker's
-- "Use:" line) even when the item is fully cached, producing false "missing tinker"
-- warnings that only a /reload clears. C_TooltipInfo reads the authoritative tooltip
-- data provider directly and does not depend on a rendered frame, so we prefer it and
-- keep the legacy scrape only as a fallback for clients without the API.
-- Both helpers return a DENSE array of left-text strings (blank lines become ""),
-- so callers can iterate with ipairs without a nil hole truncating the scan early.
local function GetInventoryTooltipLines(unit, slot)
    local out = {}
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = C_TooltipInfo.GetInventoryItem(unit, slot)
        if data and data.lines then
            for _, row in ipairs(data.lines) do out[#out + 1] = row.leftText or "" end
            return out
        end
    end
    scanTip:ClearLines()
    scanTip:SetInventoryItem(unit, slot)
    for i = 1, scanTip:NumLines() do
        local o = _G["GearLensScanTipTextLeft" .. i]
        out[#out + 1] = (o and o:GetText()) or ""
    end
    return out
end

local function GetHyperlinkTooltipLines(link)
    local out = {}
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(link)
        if data and data.lines then
            for _, row in ipairs(data.lines) do out[#out + 1] = row.leftText or "" end
            return out
        end
    end
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    for i = 1, scanTip:NumLines() do
        local o = _G["GearLensScanTipTextLeft" .. i]
        out[#out + 1] = (o and o:GetText()) or ""
    end
    return out
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

local function GetAvgIlvlForUnit(unit)
    if unit == "player" and GetAverageItemLevel then
        return GetAverageItemLevel()
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
    return total / 16, total / 16
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
        local anyIncomplete = false

        -- Average ilvl badge
        local equipped, maxLvl = GetAvgIlvlForUnit(unit)
        if maxLvl and maxLvl > equipped + 0.05 then
            ilvlLabel:SetFormattedText(
                "|cFF00FF00%.1f|r|cFFAAAAAA/%.1f|r", equipped, maxLvl)
        else
            ilvlLabel:SetFormattedText("|cFF00FF00%.1f|r", equipped)
        end

        -- Engineering detection.
        -- Own character: use the profession API directly — no scanning needed.
        -- Inspected player: we can't call GetProfessions() on them, so we do a
        -- lightweight scan of the 3 tinker slots only.  A tinker on any one of
        -- them proves engineering.  The main loop below re-scans each slot
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

        -- Hoist per-unit constants out of the slot loop
        local unitIsPlayer  = (unit == "player")
        local unitIsBS      = unitIsPlayer and IsBlacksmith()
        local unitIsEnchant = unitIsPlayer and IsEnchanter()
        local _, unitClass  = UnitClass(unit)
        local expectedArmor = unitClass and CLASS_ARMOR[unitClass]

        -- Per-slot update (single pass — ScanSlot called once per slot here)
        for _, info in ipairs(SLOT_BUTTONS) do
            local slot  = info.id
            local entry = slotLabels[slot]
            if entry then
                local data = ScanSlot(unit, slot)
                if data and data.incompleteRead then anyIncomplete = true end

                -- Ilvl chip
                if data and data.ilvl and data.ilvl > 0 then
                    local c = QUALITY_COLOR[data.quality] or QUALITY_COLOR[1]
                    entry.label:SetTextColor(c[1], c[2], c[3])
                    entry.label:SetText(data.ilvl)
                    -- When the item is upgraded, show the base ilvl smaller to the
                    -- right; otherwise just the single current number, centered.
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
                if showIssues and entry.warn and data then
                    -- In some clients GetInventoryItemLink(unit, 17) returns the 2H weapon
                    -- link when no off-hand is equipped.  Skip all checks in that case.
                    if slot == 17 and data.equipLoc == "INVTYPE_2HWEAPON" then
                        entry.warn._issues = {}
                        entry.warn:Hide()
                    else
                        local issues = {}

                        if data.emptyGems > 0 then
                            if data.emptyGems == 1 then
                                table.insert(issues, "This item is missing 1 gem!")
                            else
                                table.insert(issues, "This item is missing " .. data.emptyGems .. " gems!")
                            end
                        end

                        if data.outdatedGems > 0 then
                            if data.outdatedGems == 1 then
                                table.insert(issues, "This item has an outdated gem!")
                            else
                                table.insert(issues, "This item has " .. data.outdatedGems .. " outdated gems!")
                            end
                        end

                        if data.lowQualityGems > 0 then
                            if data.lowQualityGems == 1 then
                                table.insert(issues, "This item has a low quality gem!")
                            else
                                table.insert(issues, "This item has " .. data.lowQualityGems .. " low quality gems!")
                            end
                        end

                        if slot == 6 and data.totalSockets == 0 then
                            table.insert(issues, "This item is missing a Belt Buckle!")
                        end

                        if BS_SOCKET_SLOTS[slot] and unitIsBS then
                            local baseSockets = GetBaseSocketCount(data.link)
                            if data.totalSockets <= baseSockets then
                                table.insert(issues, "This item is missing a Blacksmithing socket!")
                            end
                        end

                        -- Enchanting: ring enchants (only enchanters can enchant rings)
                        if (slot == 11 or slot == 12) and unitIsEnchant
                        and not data.hasEnchant then
                            table.insert(issues, "This item is not enchanted!")
                        end

                        -- Regular enchant check.
                        -- Engineering tinkers and regular enchants are NOT mutually exclusive —
                        -- both can be applied to gloves and cloaks simultaneously.
                        if ENCHANT_SLOTS[slot] and not data.hasEnchant then
                            local skip = slot == 17
                                         and not (data.equipLoc and ENCHANTABLE_OH[data.equipLoc])
                            if not skip then
                                table.insert(issues, "This item is not enchanted!")
                                -- If they have the tinker but skipped the enchant, educate them.
                                if ENG_TINKER_PATTERNS[slot] and data.hasEngTinker then
                                    table.insert(issues,
                                        "Tinkers and enchants can both be applied to this slot!")
                                end
                            end
                        end

                        -- Engineering tinker checks.
                        -- For own character, profession is checked directly.
                        -- For inspected players, engineering is inferred from any observed tinker.
                        if unitIsEngineer and ENG_TINKER_PATTERNS[slot] then
                            if not data.hasEngTinker then
                                table.insert(issues,
                                    "This item is missing " .. ENG_TINKER_NAMES[slot] .. "!")
                            end
                        end

                        -- Armor specialization: wrong armor type loses 5% primary stat bonus
                        if ARMOR_SPEC_SLOTS[slot] and data.armorType then
                            if expectedArmor and data.armorType ~= expectedArmor
                            and data.armorType ~= "Miscellaneous" then
                                table.insert(issues,
                                    "This item breaks your Armor Specialization bonus!")
                            end
                        end

                        -- Item upgrades: flag items that have not been fully upgraded
                        if data.upgradeLevel and data.maxUpgrade
                        and data.upgradeLevel < data.maxUpgrade then
                            table.insert(issues, string.format(
                                "This item has not been fully upgraded (%d/%d)!",
                                data.upgradeLevel, data.maxUpgrade))
                        end

                        -- Eye of the Black Prince: extra socket on Sha-Touched/ToT weapons (ilvl 522-541)
                        if EYE_WEAPON_EQUIPLOC[data.equipLoc]
                        and data.ilvl and data.ilvl >= EYE_MIN_ILVL and data.ilvl <= EYE_MAX_ILVL
                        and not IsPvPItem(data.name) then
                            local baseSockets = GetBaseSocketCount(data.link)
                            if data.totalSockets <= baseSockets then
                                table.insert(issues, "This weapon is missing an Eye of the Black Prince socket!")
                            end
                        end

                        -- Legendary meta gem: Wrathion questline reward, relevant for ToT helms
                        if slot == 1
                        and data.ilvl and data.ilvl >= META_MIN_ILVL and data.ilvl <= META_MAX_ILVL
                        and not IsPvPItem(data.name) then
                            for _, gemID in ipairs(data.gemIDs) do
                                local _, _, gemQuality, _, _, _, gemSubType = GetItemInfo(gemID)
                                if gemSubType and gemSubType:find("Meta", 1, true) then
                                    if (gemQuality or 0) < 5 then
                                        table.insert(issues, "This helm is missing a Legendary meta gem!")
                                    end
                                    break  -- only one meta socket possible
                                end
                            end
                        end

                        if #issues > 0 then
                            entry.warn._issues = issues
                            entry.warn:Show()
                        else
                            entry.warn._issues = {}
                            entry.warn:Hide()
                        end
                    end
                elseif entry.warn then
                    entry.warn:Hide()
                end
            end
        end

        if isActive and not isActive() then
            HideAll()
            retryCount = 0
        else
            ilvlPanel:Show()
            -- If any equipped slot returned an incomplete tooltip read, the async
            -- data provider wasn't ready yet. Re-scan shortly (bounded) so the frame
            -- self-heals to correct values without needing a /reload.
            if anyIncomplete and retryCount < 6 then
                retryCount = retryCount + 1
                retryFrame = retryFrame or CreateFrame("Frame")
                local waited = 0
                retryFrame:SetScript("OnUpdate", function(self, dt)
                    waited = waited + dt
                    if waited >= 0.3 then
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

    -- Helper: strip leading "This <word> " so whisper/chat lines are concise
    local function ShortIssue(s)
        return (s:gsub("^This %a+ ", ""))
    end

    -- ── Whisper Issues button ─────────────────────────────────────────────────
    local whisperBtn = CreateFrame("Button", nil, InspectFrame, "UIPanelButtonTemplate")
    whisperBtn:SetSize(110, 22)
    whisperBtn:SetFrameStrata("HIGH")
    whisperBtn:SetPoint("BOTTOMRIGHT", InspectFrame, "BOTTOMRIGHT", -8, 8)
    whisperBtn:SetText("Whisper Issues")
    whisperBtn:Hide()
    whisperBtn:SetScript("OnClick", function()
        local allIssues = inspectGetIssues()
        if #allIssues == 0 then
            print("|cFF00FF00GearLens:|r No gear issues found.")
            return
        end
        local unit = (InspectFrame and InspectFrame.unit) or inspectUnit
        local name, realm = UnitName(unit)
        if not name then return end
        local target = (realm and realm ~= "") and (name .. "-" .. realm) or name
        SendChatMessage("GearLens gear report:", "WHISPER", nil, target)
        for _, entry in ipairs(allIssues) do
            for _, issue in ipairs(entry.issues) do
                SendChatMessage("[" .. entry.name .. "] " .. ShortIssue(issue), "WHISPER", nil, target)
            end
        end
    end)

    -- ── Report to Chat button ─────────────────────────────────────────────────
    local reportBtn = CreateFrame("Button", nil, InspectFrame, "UIPanelButtonTemplate")
    reportBtn:SetSize(110, 22)
    reportBtn:SetFrameStrata("HIGH")
    reportBtn:SetPoint("BOTTOMLEFT", InspectFrame, "BOTTOMLEFT", 8, 8)
    reportBtn:SetText("Report to Chat")
    reportBtn:Hide()
    reportBtn:SetScript("OnClick", function()
        local allIssues = inspectGetIssues()
        if #allIssues == 0 then
            print("|cFF00FF00GearLens:|r No gear issues found.")
            return
        end
        local unit    = (InspectFrame and InspectFrame.unit) or inspectUnit
        local name    = UnitName(unit) or "Unknown"
        local channel = GetChatChannel()
        SendChatMessage("GearLens: " .. name .. " has gear issues:", channel)
        for _, entry in ipairs(allIssues) do
            for _, issue in ipairs(entry.issues) do
                SendChatMessage("[" .. entry.name .. "] " .. ShortIssue(issue), channel)
            end
        end
    end)

    -- Wrap the raw refresh so both buttons are shown/hidden based on issue state
    local function doRefresh()
        rawRefresh()
        local hasIssues = #inspectGetIssues() > 0
        local gearTab   = InspectPaperDollFrame and InspectPaperDollFrame:IsShown()
        local show      = hasIssues and gearTab
        whisperBtn:SetShown(show)
        reportBtn:SetShown(show)
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

            local evtFrame = CreateFrame("Frame")
            evtFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
            evtFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
            evtFrame:SetScript("OnEvent", function(_, event, arg1)
                -- UNIT_INVENTORY_CHANGED fires for any unit; only react to the player.
                if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
                ScheduleCharRefresh()
            end)

            -- LoadAddOn("Blizzard_InspectUI") -- TODO: LoadAddon is not working
            SetupInspectOverlay()

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
-- current-vs-base item level for every equipped slot. Use it to confirm the
-- C_TooltipInfo path works (run before any /reload) or to diagnose a recurrence.
SLASH_GEARLENSRU1 = "/glr"
SlashCmdList["GEARLENSRU"] = function(msg)
    local usingCTI = (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) and true or false
    print(("|cFF00FF00GearLens:|r Engineer=%s  C_TooltipInfo=%s")
        :format(tostring(IsEngineer()), tostring(usingCTI)))
    for _, slot in ipairs({ 6, 10, 15 }) do
        local name = ENG_TINKER_NAMES[slot]
        local patterns = ENG_TINKER_PATTERNS[slot]
        local link = GetInventoryItemLink("player", slot)
        if not link then
            print(("|cFF00FF00GearLens:|r [%d] %s: (empty slot)"):format(slot, name))
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
            print(("|cFF00FF00GearLens:|r [%d] %s: tinker %s"):format(
                slot, name, found and "|cFF00FF00FOUND|r" or "|cFFFF0000NOT FOUND|r"))
        end
    end
    -- Current (upgraded) vs base item level per equipped slot; upgraded ones marked.
    for _, slot in ipairs(ILVL_SLOTS) do
        local data = ScanSlot("player", slot)
        if data and data.ilvl then
            local upgraded = data.baseIlvl and data.baseIlvl < data.ilvl
            print(("|cFF00FF00GearLens:|r [%d] ilvl cur=%s base=%s%s%s"):format(
                slot, tostring(data.ilvl), tostring(data.baseIlvl),
                upgraded and " |cFF00FF00(upgraded)|r" or "",
                data.incompleteRead and " |cFFFF0000(incomplete read)|r" or ""))
        end
    end
end
