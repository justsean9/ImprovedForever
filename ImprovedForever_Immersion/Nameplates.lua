-- The nameplates in the module's look: the name in gold (the header's
-- font), under it a thin line in the nameplate's colour over a dark
-- track, the level in the small circle at the line's end;
-- (your target's full size, the others a little smaller and softer). Each is a frame of
-- ours anchored to the game's plate (a plain anchor: probe verified
-- taint-free; the plate is never measured or changed), and the game's own
-- look of it (its UnitFrame) drawn at alpha 0 by an animation of ours
-- (IF.Focus.Fade). Plates that only carry widgets and the soft-interact
-- object (the fishing bobber) stay the game's. Health can be secret:
-- handed to the bar, never compared.
local IF = ImprovedForever
local IN = IF.Interface
local HS = IN.HeaderSlot
local UF = IN.UnitFrames
local TH = IN.TargetHeader

local Try, Flag, Secret = UF.Try, UF.Flag, UF.Secret

local W, LINE_H, BADGE = 110, 4, 20
local TRACK = { 0, 0, 0, 0.55 }
local NAME_SIZE = 17
local TITLE_SIZE = 12
local TITLE_COLOR = { 0.85, 0.82, 0.7 }   -- (the NPC's job, <Warrior Trainer>: softer than the name)
local STEP = 0.1
local OTHER_SCALE, OTHER_ALPHA = 0.8, 0.85
local PLATE_DROP = 34                -- (ours sits this far under the game's plate centre: closer to the head)
local FADE_SPEED = 8                    -- (how fast alpha and size ease)

---------------------------------------------------------------------------
-- One plate of ours (pooled)
---------------------------------------------------------------------------
local pool = {}

local function Build()
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(W, LINE_H)
    p:SetFrameStrata("LOW")
    p:EnableMouse(false)
    p:Hide()
    local track = p:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    p.track = track
    track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
    p.bar = CreateFrame("StatusBar", nil, p)
    p.bar:SetAllPoints()
    p.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    p.bar:SetMinMaxValues(0, 1)
    p.bar:SetValue(1)
    p.name = HS.Text(p, HS.FONT, NAME_SIZE, HS.GOLD[1], HS.GOLD[2], HS.GOLD[3])
    p.name:SetPoint("BOTTOM", p, "TOP", 0, 3)
    p.name:SetWidth(W * 2.4)
    p.title = HS.Text(p, HS.FONT, TITLE_SIZE, TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
    p.title:SetWidth(W * 2.4)
    local badge = p:CreateTexture(nil, "OVERLAY", nil, 2)
    badge:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("LEFT", p, "RIGHT", 2, 0)
    p.badge = badge
    p.level = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.level:SetDrawLayer("OVERLAY", 3)
    p.level:SetPoint("CENTER", badge, "CENTER", 0, -0.5)
    p.skull = p:CreateTexture(nil, "OVERLAY", nil, 4)
    p.skull:SetAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", true)
    p.skull:SetPoint("CENTER", badge, "CENTER")
    p.skull:Hide()
    return p
end

local function Same(other)
    return function(unit) return UnitIsUnit(unit, other) end
end
local IsTarget, IsSoft = Same("target"), Same("softinteract")

-- Your debuffs on it, under the line: the game's aura container (filled
-- by the game itself, so it reads them in a fight too), one per plate of
-- ours, the unit handed to it.
local DEBUFF_SIZE, DEBUFF_MAX, DEBUFF_GAP = 16, 5, 2

local function StyleDebuff(b)
    b:SetSize(DEBUFF_SIZE, DEBUFF_SIZE)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    local time = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    time:SetPoint("TOP", b, "BOTTOM", 0, -1)
    pcall(b.SetIcon, b, icon)
    pcall(b.SetApplicationCount, b, count)
    pcall(b.SetDurationText, b, time)
    local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER")
    border:SetSize(DEBUFF_SIZE * 1.2, DEBUFF_SIZE * 1.2)
    pcall(b.AddDispelTypeTexture, b, border, {
        style = styles and styles.Border or 0,
        showWhenHarmful = true, showWithoutDispelType = true,
    })
end

-- (nil: this client has none)
local function AuraList(p)
    if p.auras ~= nil then return p.auras or nil end
    p.auras = false
    if not (AuraContainerSortMethod and AuraContainerSortDirection) then return nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, p, "CustomAuraContainerTemplate")
    if not (ok and c) then return nil end
    pcall(c.AddAuraGroup, c, "debuffs", "HARMFUL|PLAYER", {
        maxFrameCount = DEBUFF_MAX,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        layout = { elementSpacing = DEBUFF_GAP, groupSpacing = 0, elementWidth = DEBUFF_SIZE, elementHeight = DEBUFF_SIZE },
        initializeFrame = StyleDebuff,
    })
    c:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, p.auraDrop or -3)
    c:Hide()
    p.auras = c
    return c
end

-- (shown for the unit, or hidden: the setting off, or none)
local function Auras(p, unit)
    local on = unit and IN.Settings().nameplateDebuffs ~= false
    local c = (on or p.auras) and AuraList(p)
    if not c then return end
    if on then pcall(c.SetUnit, c, unit) end
    c:SetShown(on and true or false)
    pcall(c.SetEnabled, c, on and true or false)
end

local function Level(p, unit)
    local ok, l, r, g, b = pcall(function()
        local v = UnitLevel(unit)
        if Secret(v) then error("secret") end
        if not v or v <= 0 then return nil end
        local color = (GetCreatureDifficultyColor or GetQuestDifficultyColor)(v)
        return v, color.r, color.g, color.b
    end)
    p.skull:SetShown(ok and not l)
    if ok and l then
        p.level:SetText(l)
        p.level:SetTextColor(r, g, b)
    else
        p.level:SetText("")
    end
end

-- (drawn at its current alpha and size; none left: not shown)
local function Draw(p)
    local a = p.alpha * (p.seen or 1)
    p:SetScale(math.max(0.01, p.scale * (p.size or 1)))
    p:SetAlpha(a)
    p:SetShown(a > 0.01)
end

-- The name's font and size, from the settings (N.FONTS: the Interface tab's
-- choices); the game's standard font when a file can't be set
local N = {}
IN.Nameplates = N

N.FONTS = {
    { key = "morpheus", name = "Morpheus", file = HS.FONT },
    { key = "friz", name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
    { key = "arial", name = "Arial Narrow", file = "Fonts\\ARIALN.TTF" },
    { key = "skurri", name = "Skurri", file = "Fonts\\skurri.ttf" },
}
N.SIZE_MIN, N.SIZE_MAX, N.SIZE_DEFAULT = 8, 24, NAME_SIZE

local function NameFont()
    local s = IN.Settings()
    local file = HS.FONT
    for _, f in ipairs(N.FONTS) do
        if f.key == s.nameplateFont then file = f.file end
    end
    -- (the choices have Latin letters only, bar Arial Narrow's Cyrillic)
    if not HS.LATIN then file = STANDARD_TEXT_FONT end
    local size = math.max(N.SIZE_MIN, math.min(N.SIZE_MAX, tonumber(s.nameplateNameSize) or NAME_SIZE))
    return file, size
end

local function StyleName(p)
    local file, size = NameFont()
    if p.nameFile == file and p.nameSize == size then return end
    if not p.name:SetFont(file, size, "") then p.name:SetFont(STANDARD_TEXT_FONT, size, "") end
    local tsize = math.max(8, math.floor(size * 0.72 + 0.5))
    if not p.title:SetFont(file, tsize, "") then p.title:SetFont(STANDARD_TEXT_FONT, tsize, "") end
    p.nameFile, p.nameSize = file, size
end


-- The job under an NPC's name (<Warrior Trainer>): the game draws it itself
-- only when it draws the name too, so it's read from the unit's tooltip, its
-- second line (a level line has a number: not a job). A player's: the guild.
-- (nil: none, or secret)
local function Title(unit)
    local ok, t = pcall(function()
        local v
        if Flag(UnitIsPlayer, unit) then
            v = GetGuildInfo(unit)
        else
            local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
            local line = data and data.lines and data.lines[2]
            v = line and line.leftText
            if type(v) == "string" and not Secret(v) and v:find("%d") then v = nil end
        end
        if Secret(v) or type(v) ~= "string" or v == "" then return nil end
        return "<" .. v .. ">"
    end)
    return ok and t or nil
end

-- The name's colour: NPCs and mobs in the header's gold, other players in
-- their class colour (white when it can't be read).
local function NameColor(unit)
    if not Flag(UnitIsPlayer, unit) then return HS.GOLD[1], HS.GOLD[2], HS.GOLD[3] end
    local ok, r, g, b = pcall(function()
        local _, class = UnitClass(unit)
        if Secret(class) or not class then return nil end
        local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
            or RAID_CLASS_COLORS[class]
        if not c then return nil end
        return c.r, c.g, c.b
    end)
    if ok and r then return r, g, b end
    return 1, 1, 1
end

local function Refresh(p)
    local unit = p.unit
    if not unit then return end
    StyleName(p)
    Try(p.name.SetText, p.name, UnitName(unit))
    if Flag(UnitIsDeadOrGhost, unit) then
        p.name:SetTextColor(0.5, 0.5, 0.5)
    else
        local r, g, b = NameColor(unit)
        p.name:SetTextColor(r, g, b)
    end
    -- (the health line off, for NPCs and players apart: the name alone)
    local set = IN.Settings()
    local hide
    if Flag(UnitIsPlayer, unit) then hide = set.nameplateHideBarPlayers == true
    else hide = set.nameplateHideBar ~= false end
    local showBar = not hide
    p.bar:SetShown(showBar)
    p.track:SetShown(showBar)
    p.badge:SetShown(showBar)
    -- (the job under the name, as the game's: the guild line of an NPC)
    if p.titleUnit ~= unit then p.titleUnit, p.titleText = unit, Title(unit) end
    local title = p.titleText
    local hasTitle = title ~= nil
    p.title:SetText(title or "")
    p.title:SetShown(hasTitle)
    if p.barShown ~= showBar or p.hasTitle ~= hasTitle then
        p.barShown, p.hasTitle = showBar, hasTitle
        p.name:ClearAllPoints()
        p.title:ClearAllPoints()
        if showBar then
            -- (over the line: the name, the job between it and the line)
            if hasTitle then
                p.title:SetPoint("BOTTOM", p, "TOP", 0, 3)
                p.name:SetPoint("BOTTOM", p.title, "TOP", 0, 1)
            else
                p.name:SetPoint("BOTTOM", p, "TOP", 0, 3)
            end
        else
            -- (no line: the name where the line was, the job under it)
            if hasTitle then
                p.name:SetPoint("CENTER", p, "CENTER", 0, 6)
                p.title:SetPoint("TOP", p.name, "BOTTOM", 0, -1)
            else
                p.name:SetPoint("CENTER", p, "CENTER", 0, 0)
            end
        end
        p.auraDrop = showBar and -3 or (hasTitle and -17 or -9)
        if p.auras then
            p.auras:ClearAllPoints()
            p.auras:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, p.auraDrop)
        end
    end
    local value, max = UnitHealth(unit), UnitHealthMax(unit)
    if not Try(p.bar.SetMinMaxValues, p.bar, 0, max) or not Try(p.bar.SetValue, p.bar, value) then
        p.bar:SetMinMaxValues(0, 1)
        p.bar:SetValue(0)
    end
    local r, g, b = TH.NameplateColor(unit)
    p.bar:SetStatusBarColor(r, g, b)
    if showBar then
        Level(p, unit)
    else
        p.skull:Hide()
        p.level:SetText("")
    end
    -- (your target's at full size, the others softer: eased on a change)
    local target = Flag(IsTarget, unit)
    p.goalAlpha = target and 1 or OTHER_ALPHA
    p.goalScale = target and 1 or OTHER_SCALE
    p:SetFrameLevel(target and 20 or 10)
    if not p.alpha then
        p.alpha, p.scale = p.goalAlpha, p.goalScale
        Draw(p)
    end
end

---------------------------------------------------------------------------
-- The game's plates in play: unit token -> { game plate, ours }
---------------------------------------------------------------------------
local active = {}

local function HideGame(game, on)
    local ok, unitFrame = pcall(function() return game.UnitFrame end)
    if ok and type(unitFrame) == "table" then pcall(IF.Focus.Fade, unitFrame, on) end
end

local function IsCreature(unit)
    local ok, kind = pcall(function()
        local guid = UnitGUID(unit)
        if Secret(guid) or type(guid) ~= "string" then return false end
        return guid:find("^Creature") or guid:find("^Player") or guid:find("^Vehicle") or guid:find("^Pet")
    end)
    return ok and kind and true or false
end

local function Wanted(unit)
    local s = IN.Settings()
    if s.nameplates == false or UF.EditMode() then return false end
    if Flag(UnitNameplateShowsWidgetsOnly, unit) then return false end
    -- (the soft-interact object that isn't a creature or player, the fishing
    -- bobber, stays the game's; a soft-interact NPC gets our look)
    if Flag(IsSoft, unit) and not Flag(IsTarget, unit) and not IsCreature(unit) then return false end
    return true
end


local function Release(unit)
    local a = active[unit]
    if not a then return end
    active[unit] = nil
    HideGame(a.game, false)
    if a.ours then
        Auras(a.ours, nil)
        a.ours:Hide()
        a.ours.unit = nil
        pool[#pool + 1] = a.ours
    end
end

local function Add(unit)
    Release(unit)
    local game = C_NamePlate.GetNamePlateForUnit(unit)
    if not game then return end
    local a = { game = game }
    active[unit] = a
    if not Wanted(unit) then return end
    local p = table.remove(pool) or Build()
    a.ours = p
    p.unit = unit
    p.game = game
    p.seen, p.size = 1, 1
    p.titleUnit = nil
    p.alpha = nil
    HideGame(game, true)
    p:ClearAllPoints()
    p:SetPoint("CENTER", game, "CENTER", 0, -PLATE_DROP)
    Refresh(p)
    Auras(p, unit)
end

-- (an error said once, then no more)
local broken
local function Safe(fn, ...)
    if broken then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        broken = true
        for unit in pairs(active) do Release(unit) end
        IF.Print("Immersion: the nameplates stopped after an error: " .. tostring(err))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Safe(Add, unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Safe(Release, unit)
    else
        for u, a in pairs(active) do
            if a.ours then Safe(Refresh, a.ours) end
        end
    end
end)

-- Behind an object the game dims its plate (its alpha: only read, in a pcall)
-- but keeps its size; far away it shrinks and fades both. So ours goes out
-- only while the game's plate is dimmed at a normal size: ramping from
-- OCCLUDED_LOW (gone) to OCCLUDED_HIGH (whole). A far one stays ours, a
-- little smaller (FAR_MIN at the smallest) until the game takes the plate.
local OCCLUDED_LOW, OCCLUDED_HIGH = 0.25, 0.45
local NEAR_SCALE, FAR_MIN = 0.57, 0.6
local function Seen(game)
    local ok, a, sc = pcall(function() return game:GetAlpha(), game:GetScale() end)
    if not ok or type(a) ~= "number" or type(sc) ~= "number" or Secret(a) or Secret(sc) then return 1, 1 end
    local size = math.max(FAR_MIN, math.min(1, sc / NEAR_SCALE))
    if sc < NEAR_SCALE * 0.8 then return 1, size end
    return math.max(0, math.min(1, (a - OCCLUDED_LOW) / (OCCLUDED_HIGH - OCCLUDED_LOW))), size
end

local function Ease(p, elapsed)
    if not p.alpha then return end
    local k = math.min(1, elapsed * FADE_SPEED)
    local seen, size = Seen(p.game)
    p.seen = (p.seen or 1) + (seen - (p.seen or 1)) * k
    p.size = (p.size or 1) + (size - (p.size or 1)) * k
    p.alpha = p.alpha + (p.goalAlpha - p.alpha) * k
    p.scale = p.scale + (p.goalScale - p.scale) * k
    if math.abs(p.alpha - p.goalAlpha) < 0.01 then p.alpha, p.scale = p.goalAlpha, p.goalScale end
    Draw(p)
end


local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    local data = since >= STEP
    if data then since = 0 end
    for _, a in pairs(active) do
        if a.ours then
            if data then Safe(Refresh, a.ours) end
            Safe(Ease, a.ours, elapsed)
        end
    end
end)

-- The setting changed: every plate in play drawn again (ours, or the game's)
function N.Apply()
    pcall(N.ApplyCVar)
    local units = {}
    for unit in pairs(active) do units[#units + 1] = unit end
    for _, unit in ipairs(units) do Safe(Add, unit) end
end

---------------------------------------------------------------------------
-- Friendly NPC plates: the game draws none by itself (nameplateShowFriendlyNPCs
-- 0), only their name as plain text, so ours has nothing to dress. The setting
-- turns the CVar on (remembering yours, put back when it's off).
---------------------------------------------------------------------------
-- Far away (no plate) the engine draws a unit's name itself, tiny and in the
-- game's colours: green for NPCs, blue for players. Those can't be restyled,
-- so the setting turns them off and only our plates are left.
local CVARS = {
    { "nameplateShowFriendlyNPCs", "1", function(s) return s.nameplateFriendlyNPCs ~= false end },
    { "UnitNameNPC", "0", function(s) return s.nameplateHideFarNames ~= false end },
    { "UnitNameFriendlyPlayerName", "0", function(s) return s.nameplateHideFarNames ~= false end },
    { "UnitNameNonCombatCreatureName", "0", function(s) return s.nameplateHideFarNames ~= false end },
}
-- (the rest of the game's unit name options: one the client doesn't have reads nil and is skipped)
for _, name in ipairs({
    "UnitNameFriendlySpecialNPCName", "UnitNameHostleNPC", "UnitNameInteractiveNPC",
    "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName",
    "UnitNameFriendlyMinionName", "UnitNameEnemyPlayerName", "UnitNameEnemyPetName",
    "UnitNameEnemyGuardianName", "UnitNameEnemyTotemName", "UnitNameEnemyMinionName",
}) do
    CVARS[#CVARS + 1] = { name, "0", function(s) return s.nameplateHideFarNames ~= false end }
end

function N.ApplyCVar()
    if InCombatLockdown() then
        N.cvarPending = true
        return
    end
    N.cvarPending = nil
    local s = IN.Settings()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    -- (an earlier version kept the one value as a string)
    if type(s.cvarWas) ~= "table" then s.cvarWas = {} end
    local on = s.nameplates ~= false
    for _, c in ipairs(CVARS) do
        local name, value, test = c[1], c[2], c[3]
        local was = s.cvarWas[name]
        if on and test(s) then
            local now = get(name)
            if was == nil and now ~= nil then s.cvarWas[name] = now end
            if now ~= nil and now ~= value then pcall(set, name, value) end
        elseif was ~= nil then
            pcall(set, name, was)
            s.cvarWas[name] = nil
        end
    end
end

local cvarEvents = CreateFrame("Frame")
cvarEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
cvarEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
cvarEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not N.cvarPending then return end
    pcall(N.ApplyCVar)
end)
