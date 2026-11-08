-- The target's buffs and debuffs: the game's aura container (filled by the game itself, so it reads
-- them in a fight too), for the unit "target", under the target header's cast bar: first your own
-- debuffs on it, then its buffs. The setting "Target buffs and debuffs" (Immersion tab) turns it off.
local IF = ImprovedForever
local IN = IF.Interface
local TH = IN.TargetHeader

local TA = {}
IN.TargetAuras = TA

local SIZE, MAX_EACH, GAP, GROUP_GAP = 22, 8, 3, 12
local GAP_UNDER = 22        -- (under the cast bar: room for its text)

local function Style(b)
    b:SetSize(SIZE, SIZE)
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
    border:SetSize(SIZE * 1.2, SIZE * 1.2)
    pcall(b.AddDispelTypeTexture, b, border, {
        style = styles and styles.Border or 0,
        showWhenHarmful = true, showWithoutDispelType = true,
    })
end

-- (made the first time it's shown; nil: this client has none)
local container
local function Container()
    if container ~= nil then return container or nil end
    container = false
    if not (AuraContainerSortMethod and AuraContainerSortDirection and TH.castBox) then return nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", "ImprovedForeverTargetAuras", UIParent, "CustomAuraContainerTemplate")
    if not (ok and c) then return nil end
    c:SetFrameStrata("LOW")
    pcall(c.SetUnit, c, "target")
    local function Group(key, filter)
        pcall(c.AddAuraGroup, c, key, filter, {
            maxFrameCount = MAX_EACH,
            sortMethod = AuraContainerSortMethod.Expiration,
            sortDirection = AuraContainerSortDirection.Reverse,
            layout = { elementSpacing = GAP, groupSpacing = GROUP_GAP, elementWidth = SIZE, elementHeight = SIZE },
            initializeFrame = Style,
        })
    end
    Group("debuffs", "HARMFUL|PLAYER")
    Group("buffs", "HELPFUL")
    -- (the row's left on the rule's left, under the cast bar)
    c:SetPoint("TOPLEFT", TH.castBox, "BOTTOMLEFT", 0, -GAP_UNDER)
    c:Hide()
    container = c
    return c
end

-- Shown while there is a target and its header is up, the setting on
local function Wanted()
    local s = IF.db and IN.Settings()
    return s and s.targetAuras ~= false and s.target and TH.look:IsShown() and UnitExists("target") or false
end

local function Update()
    local on = Wanted()
    local c = (on or container) and Container()
    if not c then return end
    if c:IsShown() ~= on then
        c:SetShown(on)
        pcall(c.SetEnabled, c, on)
    end
end

function TA.Apply()
    Update()
end

IN.Watcher("target auras", 0.2, Update)
