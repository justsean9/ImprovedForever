-- The target's buffs and debuffs: the game's aura container (filled by the game itself, so it reads
-- them in a fight too), for the unit "target", under the target header's cast bar: first your own
-- debuffs on it, then its buffs. The setting "Target buffs and debuffs" (Immersion tab) turns it off.
local IF = ImprovedForever
local IN = IF.Interface
local TH = IN.TargetHeader

local TA = {}
IN.TargetAuras = TA

local SIZE, MAX_EACH, GAP, GROUP_GAP = 22, 8, 3, 12
local GAP_UNDER = 2         -- (under the race / class line: the cast is on the diamond now, its text above it)

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
    pcall(b.SetTooltipAnchorPoint, b, "ANCHOR_TOP")
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
    -- (centred under the cast bar, which hangs under the race / class line: the width follows the
    -- icons, see Width below)
    c:SetSize(SIZE, SIZE)
    c:SetPoint("TOP", TH.castBox, "BOTTOM", 0, -GAP_UNDER)
    c:Hide()
    container = c
    return c
end

-- Shown while there is a target and its header is up, the setting on
local function Wanted()
    local s = IF.db and IN.Settings()
    return s and s.targetAuras ~= false and s.target and TH.look:IsShown() and UnitExists("target") or false
end

-- How many auras the target has now of a filter (out of a fight: in one their details are secret)
local function Count(filter)
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return 0 end
    local n = 0
    for i = 1, MAX_EACH do
        local ok, data = pcall(get, "target", i, filter)
        if not ok or type(data) ~= "table" then break end
        n = n + 1
    end
    return n
end

-- The row as wide as its icons, so centring it centres them: counted out of a fight, kept in one
local width = SIZE
local function Width(c)
    if not IF.InCombat() then
        local d, b = Count("HARMFUL|PLAYER"), Count("HELPFUL")
        local n = d + b
        width = n > 0 and (n * SIZE + (n - 1) * GAP + (d > 0 and b > 0 and GROUP_GAP - GAP or 0) + 4) or SIZE
    end
    -- (the game's container can hand its width back secret: not compared, set again)
    local now = c:GetWidth()
    if IN.UnitFrames.Secret(now) or now ~= width then c:SetSize(width, SIZE) end
end

local function Update()
    local on = Wanted()
    local c = (on or container) and Container()
    if not c then return end
    if on then Width(c) end
    if c:IsShown() ~= on then
        c:SetShown(on)
        pcall(c.SetEnabled, c, on)
    end
end

-- The game's list keeps the earlier target's icons for the unit "target" unless it is handed the unit
-- again: asked again, and off and on, whenever the target changes
local function Refresh()
    local c = container
    if not c then return end
    pcall(c.SetEnabled, c, false)
    pcall(c.SetUnit, c, "target")
    if c:IsShown() then pcall(c.SetEnabled, c, true) end
end

function TA.Apply()
    Update()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function()
    Update()
    Refresh()
end)

IN.Watcher("target auras", 0.2, Update)
