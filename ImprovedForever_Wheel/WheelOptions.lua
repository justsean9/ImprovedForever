-- The Wheel options tab, a tab of settings (IF.SettingsPage, SettingsPage.lua): the wheel's
-- size. Ring.lua does the work (IF.ApplyRingScale).
local IF = ImprovedForever

local ITEMS = {
    {
        key = "ringScale", group = "wheel", label = "Wheel size",
        tip = "How big the wheel is, in percent: smaller if it covers too much of the screen. Out of combat only.",
        slider = {
            min = 50, max = 150, step = 5,
            get = function() return tonumber(IF.db.ringScale) or 100 end,
            set = function(n)
                IF.db.ringScale = n
                IF.ApplyRingScale()
            end,
            format = function(n) return n .. "%" end,
        },
    },
}

local GROUPS = {
    { key = "wheel", label = "Wheel" },
}

IF.WheelOptions = IF.SettingsPage({ key = "wheelOptions", label = "Wheel options", module = "wheel", order = 21 },
    GROUPS, ITEMS)
