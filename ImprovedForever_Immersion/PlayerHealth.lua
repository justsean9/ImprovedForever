-- Your health and power as two bars along the screen's bottom edge, the
-- power (mana, rage, energy...) on the edge and the health over it, sharing
-- each a 1px line as the header's rule (the quest guide's, HeaderSlot.lua):
-- full from end to end, two halves out from the middle, each darkening
-- toward its end (lost draws them in from both ends to the middle).
-- * the health: the game's own fills (the reputation bar's green, turning
--   orange past half and red when low, red pulsing under URGENT), the
--   heals coming to you drawn on past its end;
-- * the power: the unit frames' fill of its kind (UnitFrames.lua), in the
--   game's colour of it (mana a lighter blue), pulsing when mana is low;
--   while you cast, the power the spell will take lit at its end; while
--   mana comes back, a shine running along it.
-- Both ease to a new value: what's just gained flashes past the fill as it
-- grows, what's just lost stays as a pale trail, then eases in after it; a
-- spark flares on the fill's edge as it moves.
-- Where a fill stops reads at a glance: a bright cap marks its edge, over a
-- dark backing with a dim tint of its colour (how far full goes) and
-- notches at each quarter.
-- The health's line is always on while you're alive; the power's peeks:
-- shown in a fight or while your power isn't at rest (mana, energy short
-- of full; rage, runic power above none), faded out when it's at rest
-- again (the lines never show while dead or a ghost). Either one off: the
-- other alone on the edge.
-- Your health and power are secret in a fight: they go to the bars as
-- their max and value as they are (the bars work the fill out, never
-- compared here), the colours' strength from the game's percent through
-- curves, as the party cards' (PartyCards.lua). The heals coming and a
-- spell's cost go the same way, to bars of their own laid from the fill's
-- edge (DoesItDie's way: the game places them, so a secret moves them too).
local IF = ImprovedForever
local IN = IF.Interface
local UF = IN.UnitFrames

local PlayerHealth = {}
IN.PlayerHealth = PlayerHealth

local LINE_H = IN.HP_H or 5
local POWER_H = IN.MP_H or 5
local FADE = 0.3
local HOLD = 0.8                 -- (whole again: shown this long before fading)
local TRAIL_DELAY = 0.4          -- (the trail waits this long, then eases in)
local WHITE = "Interface\\Buttons\\WHITE8x8"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
-- (the health's colours, plain: green, turning orange then red)
local GREEN = { 0.25, 0.9, 0.3 }
local ORANGE = { 1, 0.6, 0.1 }
local RED = { 0.95, 0.2, 0.15 }
local TRAIL = { 1, 0.93, 0.82, 0.55 }
-- (the predictions, as ribbons: a soft fill and the game's diagonal
-- stripes (its absorb shield's) drifting along it; the heals coming to
-- you, a spell's cost (its stripes in the power's colour, lit))
local HEAL = { 0.45, 0.95, 0.5, 0.3 }
local HEAL_STRIPE = { 0.75, 1, 0.8, 0.75 }
local COST_BASE = { 0, 0, 0, 0.4 }
local STRIPES = "Interface\\RaidFrame\\Shield-Overlay"
local STRIPE_TILE = 32          -- (the stripes' tile, px: a drift of it loops seamlessly)
local RIBBON_TIME = 1.6         -- (one tile's drift, seconds)
local POWER_COLOR = { 0.3, 0.6, 1 }     -- (the power's, when the game has no colour for it: mana's)
-- (the game's mana blue (0, 0, 1) is near black on a thin line: a lighter one)
local OWN_COLORS = { MANA = POWER_COLOR }
-- (a fill's colour at its leading edge, against its middle: darker, never
-- see-through, so what's under it (the lead, the trail) stays hidden)
local EDGE = 0.55
local CAP_W = 2
-- (the empty part: a dark backing for contrast, a dim tint of the line's
-- colour showing how far full goes, notches at a quarter, half and three
-- quarters of each half)
local BACKING = 0.4
local TINT = 0.22
local NOTCHES = { 0.25, 0.5, 0.75 }
-- (the gain's flash, the spark's flare and its rest between two, the shine)
local LEAD_FADE = 0.6
local SPARK_GAP = 0.4
local SHINE_W, SHINE_TIME = 48, 0.9
-- (low mana: a pulse over the power's fill from LOW_MANA down)
local LOW_MANA = 0.25
local LOW_POINTS = { { 0, 1 }, { LOW_MANA, 1 }, { LOW_MANA + 0.001, 0 }, { 1, 0 } }
-- (the shine, gone at full)
local FULL_POINTS = { { 0, 1 }, { 0.995, 1 }, { 1, 0 } }
-- (the powers at rest when empty: out of a fight, the rest at full)
local RESTS_EMPTY = { RAGE = true, RUNIC_POWER = true }
-- (the colours over the green, by health left: orange from three quarters
-- to full at half, red from 40% to full at a quarter, the pulse under
-- URGENT)
local URGENT = 0.35
local ORANGE_POINTS = { { 0, 1 }, { 0.5, 1 }, { 0.75, 0 }, { 1, 0 } }
local RED_POINTS = { { 0, 1 }, { 0.25, 1 }, { 0.4, 0 }, { 1, 0 } }
local URGENT_POINTS = { { 0, 1 }, { URGENT, 1 }, { URGENT + 0.001, 0 }, { 1, 0 } }
-- (a track's layers: the trail and the lead under the fill, the heals
-- past it, the fill, the pulses, the cost and the shine over it, the
-- notches, the spark on top)
local L_UNDER, L_HEAL, L_FILL, L_OVER, L_MARKS, L_SPARK = 1, 2, 3, 4, 5, 6
local Try, Flag = UF.Try, UF.Flag
local SI = Enum.StatusBarInterpolation
local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- (both lines in one frame: it peeks, they're placed in it)
local holder = CreateFrame("Frame", "ImprovedForeverPlayerHealth", UIParent)
holder:SetFrameStrata("BACKGROUND")
holder:SetPoint("BOTTOMLEFT")
holder:SetPoint("BOTTOMRIGHT")
holder:SetHeight(LINE_H)
holder:SetAlpha(0)
holder:Hide()
PlayerHealth.holder = holder

---------------------------------------------------------------------------
-- Drawing helpers
---------------------------------------------------------------------------
-- (a layer frame of a track, over its own)
local function Layer(track, level)
    local f = CreateFrame("Frame", nil, track)
    f:SetAllPoints()
    f:SetFrameLevel(track:GetFrameLevel() + level)
    return f
end

-- A track: the frame the bars sit in, a dark backing under them for
-- contrast and a frame over them for the notches; what's sized by its
-- width (a half's) re-sized with it
local function Track(height)
    local t = CreateFrame("Frame", nil, holder)
    t:SetHeight(height)
    local back = t:CreateTexture(nil, "BACKGROUND", nil, 0)
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, BACKING)
    t.marks = Layer(t, L_MARKS)
    t.sparks = Layer(t, L_SPARK)
    t.notches = {}
    for _, at in ipairs(NOTCHES) do
        for side = -1, 1, 2 do
            local n = t.marks:CreateTexture(nil, "OVERLAY")
            n:SetColorTexture(0, 0, 0, 0.55)
            n:SetWidth(1)
            n.at, n.side = at, side
            t.notches[#t.notches + 1] = n
        end
    end
    t.sized = {}
    t:SetScript("OnSizeChanged", function(self)
        local half = (self:GetWidth() or 0) / 2
        for _, n in ipairs(self.notches) do
            local x = n.side * math.floor(half * n.at + 0.5)
            n:ClearAllPoints()
            n:SetPoint("TOP", self, "TOP", x, 0)
            n:SetPoint("BOTTOM", self, "BOTTOM", x, 0)
        end
        for _, fn in ipairs(self.sized) do fn(half) end
    end)
    return t
end

local line = Track(LINE_H)
local power = Track(POWER_H)

-- (a half's bar, full out from the middle)
local function Bar(track, left, level, parent)
    local bar = CreateFrame("StatusBar", nil, parent or track)
    bar:SetPoint(left and "TOPLEFT" or "TOPRIGHT", track)
    bar:SetPoint(left and "BOTTOMRIGHT" or "BOTTOMLEFT", track, "BOTTOM")
    bar:SetFrameLevel(track:GetFrameLevel() + level)
    bar:SetReverseFill(left)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    return bar
end

-- (a bar laid from a fill's leading edge (its outer one: the left half
-- fills reversed), a half wide so it shares the line's scale: outward (the
-- heals coming) or back in over the fill (a spell's cost))
local function EdgeBar(track, fill, left, outward, level, parent)
    local bar = CreateFrame("StatusBar", nil, parent or track)
    local edge = left and "LEFT" or "RIGHT"
    local from = outward and (left and "RIGHT" or "LEFT") or edge
    bar:SetPoint("TOP" .. from, fill, "TOP" .. edge)
    bar:SetPoint("BOTTOM" .. from, fill, "BOTTOM" .. edge)
    bar:SetFrameLevel(track:GetFrameLevel() + level)
    bar:SetReverseFill(outward == left)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    track.sized[#track.sized + 1] = function(half) bar:SetWidth(math.max(half, 1)) end
    return bar
end

-- (white: its colour is the gradient's, Grade)
local function Over(bar, sub)
    local t = bar:CreateTexture(nil, "ARTWORK", nil, sub)
    t:SetAllPoints(bar:GetStatusBarTexture())
    t:SetColorTexture(1, 1, 1, 1)
    t:SetAlpha(0)
    return t
end

-- (a fill's colour darkening toward its end, as the header's rule fades:
-- its colour at the middle, `edge` of it at the end, never see-through)
local function Grade(tex, left, color, edge)
    if not (tex and tex.SetGradient and CreateColor) then return end
    local e = edge or EDGE
    local lit = CreateColor(color[1], color[2], color[3], 1)
    local dark = CreateColor(color[1] * e, color[2] * e, color[3] * e, 1)
    -- (the gradient must not undo the texture's own alpha: the colours' strength)
    local own = tex:GetAlpha()
    pcall(tex.SetGradient, tex, "HORIZONTAL", left and dark or lit, left and lit or dark)
    tex:SetAlpha(own)
end

-- (a colour fading toward the end instead: at `alpha` at the middle, down
-- to `edge` of that at the end)
local function Fade(tex, left, color, alpha, edge)
    if not (tex and tex.SetGradient and CreateColor) then return end
    local a = alpha or 1
    local clear = CreateColor(color[1], color[2], color[3], a * (edge or 0))
    local lit = CreateColor(color[1], color[2], color[3], a)
    local own = tex:GetAlpha()
    pcall(tex.SetGradient, tex, "HORIZONTAL", left and clear or lit, left and lit or clear)
    tex:SetAlpha(own)
end

-- (a colour lit toward white)
local function Lit(color, by)
    return { color[1] + (1 - color[1]) * by, color[2] + (1 - color[2]) * by, color[3] + (1 - color[3]) * by }
end

-- (the empty part's tint of a half: the whole half, static, so its fade
-- toward the end stays put while the fill moves over it)
local function Tint(track, left, color)
    local t = track:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetPoint(left and "TOPLEFT" or "TOPRIGHT", track)
    t:SetPoint(left and "BOTTOMRIGHT" or "BOTTOMLEFT", track, "BOTTOM")
    t:SetColorTexture(1, 1, 1, 1)
    Fade(t, left, color, TINT, 0.5)
    return t
end

-- (a bright cap on the fill's leading edge, placed by the bar, so a
-- secret value moves it too)
local function Cap(bar, left, color)
    local fill = bar:GetStatusBarTexture()
    local c = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    c:SetPoint(left and "TOPLEFT" or "TOPRIGHT", fill)
    c:SetPoint(left and "BOTTOMLEFT" or "BOTTOMRIGHT", fill)
    c:SetWidth(CAP_W)
    c:SetColorTexture(color[1], color[2], color[3], 1)
    return c
end

-- (an alpha flash, from `from` to nothing)
local function Flash(region, from, time)
    local g = region:CreateAnimationGroup()
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(from)
    a:SetToAlpha(0)
    a:SetDuration(time)
    a:SetSmoothing("OUT")
    return g
end

-- (the spark on a fill's edge, flaring as it moves: never lit at rest,
-- where it would hide the very edge it marks)
local function Spark(track, fill, left)
    local s = track.sparks:CreateTexture(nil, "OVERLAY")
    s:SetTexture(SPARK)
    s:SetBlendMode("ADD")
    s:SetWidth(12)
    local edge = left and "LEFT" or "RIGHT"
    local h = track:GetHeight() * 2
    s:SetPoint("TOP", fill, "TOP" .. edge, 0, h)
    s:SetPoint("BOTTOM", fill, "BOTTOM" .. edge, 0, -h)
    s:SetAlpha(0)
    local g = s:CreateAnimationGroup()
    local up = g:CreateAnimation("Alpha")
    up:SetFromAlpha(0)
    up:SetToAlpha(1)
    up:SetDuration(0.08)
    up:SetOrder(1)
    local down = g:CreateAnimation("Alpha")
    down:SetFromAlpha(1)
    down:SetToAlpha(0)
    down:SetDuration(0.45)
    down:SetSmoothing("OUT")
    down:SetOrder(2)
    s.flare = g
    return s
end

-- (a pulse layer over a track's fills: its glows' strength the secret
-- curve's, the frame's alpha the pulse, never the holder's: it fades by
-- its own)
local function Pulse(track, low, time)
    local f = Layer(track, L_OVER)
    local g = f:CreateAnimationGroup()
    g:SetLooping("BOUNCE")
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(low)
    a:SetDuration(time)
    a:SetSmoothing("IN_OUT")
    return f, g
end

-- A ribbon over a prediction bar's span (the bar's own fill unseen): a
-- soft fill and the stripes drifting along (`drift` +1 right, -1 left).
-- The stripes lie still over the whole track, clipped to the span, so they
-- never stretch as the span moves (DoesItDie's way: its width may come from
-- a secret)
local function Ribbon(parent, track, bar, level, base, stripe, drift)
    local span = bar:CreateTexture(nil, "ARTWORK")
    span:SetTexture(WHITE)
    span:SetVertexColor(1, 1, 1, 0)
    bar:SetStatusBarTexture(span)
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetPoint("TOPLEFT", span)
    clip:SetPoint("BOTTOMRIGHT", span)
    clip:SetFrameLevel(track:GetFrameLevel() + level)
    clip:SetClipsChildren(true)
    local fill = clip:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    fill:SetColorTexture(base[1], base[2], base[3], base[4])
    local s = clip:CreateTexture(nil, "OVERLAY")
    s:SetTexture(STRIPES, "REPEAT", "REPEAT")
    s:SetHorizTile(true)
    s:SetVertTile(true)
    s:SetBlendMode("ADD")
    s:SetVertexColor(stripe[1], stripe[2], stripe[3], stripe[4] or 0.7)
    s:SetPoint("TOPLEFT", track, "TOPLEFT", -STRIPE_TILE * 2, 0)
    s:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", STRIPE_TILE * 2, 0)
    local g = s:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    local m = g:CreateAnimation("Translation")
    m:SetOffset(drift * STRIPE_TILE, 0)
    m:SetDuration(RIBBON_TIME)
    g:Play()
    return { span = span, clip = clip, fill = fill, stripes = s, drift = g }
end

local pulse, beat = Pulse(line, 0.1, 0.5)
local powerPulse, powerBeat = Pulse(power, 0.15, 0.6)

---------------------------------------------------------------------------
-- The two lines: two halves each, full out from the middle
---------------------------------------------------------------------------
-- (per line: its halves, the trail's value and when it eases in, the last
-- spark's time)
local healthLine = { halves = {}, trail = {} }
local powerLine = { halves = {}, trail = {} }
local halves, powerHalves = healthLine.halves, powerLine.halves

for i = 1, 2 do
    local left = i == 1
    local h = { left = left }
    Tint(line, left, { 1, 1, 1 })
    h.trail = Bar(line, left, L_UNDER)
    Fade(h.trail:GetStatusBarTexture(), left, TRAIL, TRAIL[4], 0.55)
    h.lead = Bar(line, left, L_UNDER)
    Fade(h.lead:GetStatusBarTexture(), left, Lit(GREEN, 0.6), 1, 0.7)
    h.lead:SetAlpha(0)
    h.flash = Flash(h.lead, 1, LEAD_FADE)
    h.bar = Bar(line, left, L_FILL)
    local fill = h.bar:GetStatusBarTexture()
    h.orange, h.red = Over(h.bar, 1), Over(h.bar, 2)
    Grade(fill, left, GREEN)
    Grade(h.orange, left, ORANGE)
    Grade(h.red, left, RED)
    h.cap = Cap(h.bar, left, { 1, 0.97, 0.88 })
    h.spark = Spark(line, fill, left)
    h.spark:SetVertexColor(0.8, 1, 0.8)
    -- (the heals coming, from the fill's end on)
    h.heal = EdgeBar(line, fill, left, true, L_HEAL)
    Ribbon(line, line, h.heal, L_HEAL, HEAL, HEAL_STRIPE, left and -1 or 1)
    -- (the pulse's red over it)
    local alarm = pulse:CreateTexture(nil, "OVERLAY")
    alarm:SetAllPoints(fill)
    alarm:SetColorTexture(1, 0.25, 0.2, 0.55)
    alarm:SetBlendMode("ADD")
    alarm:SetAlpha(0)
    h.alarm = alarm
    halves[i] = h

    local p = { left = left }
    p.tint = Tint(power, left, POWER_COLOR)
    p.trail = Bar(power, left, L_UNDER)
    Fade(p.trail:GetStatusBarTexture(), left, TRAIL, TRAIL[4], 0.55)
    p.lead = Bar(power, left, L_UNDER)
    p.lead:SetAlpha(0)
    p.flash = Flash(p.lead, 1, LEAD_FADE)
    p.bar = Bar(power, left, L_FILL)
    p.bar:SetValue(0)
    local pfill = p.bar:GetStatusBarTexture()
    p.cap = Cap(p.bar, left, Lit(POWER_COLOR, 0.5))
    p.spark = Spark(power, pfill, left)
    -- (low mana's pulse over it)
    local low = powerPulse:CreateTexture(nil, "OVERLAY")
    low:SetAllPoints(pfill)
    low:SetColorTexture(0.75, 0.9, 1, 0.6)
    low:SetBlendMode("ADD")
    low:SetAlpha(0)
    p.low = low
    -- (a spell's cost, from the fill's end back in, clipped to the fill: a
    -- cost past what you have lights it all)
    local clip = CreateFrame("Frame", nil, power)
    clip:SetPoint("TOPLEFT", pfill)
    clip:SetPoint("BOTTOMRIGHT", pfill)
    clip:SetFrameLevel(power:GetFrameLevel() + L_OVER)
    clip:SetClipsChildren(true)
    clip:Hide()
    p.costClip = clip
    p.cost = EdgeBar(power, pfill, left, false, L_OVER, clip)
    -- (a ribbon: the fill under it dimmed, the stripes drifting in, toward
    -- where the mana goes)
    p.costRibbon = Ribbon(clip, power, p.cost, L_OVER, COST_BASE, Lit(POWER_COLOR, 0.5), left and 1 or -1)
    -- (its far end marked)
    local costSpan = p.costRibbon.span
    local cut = p.costRibbon.clip:CreateTexture(nil, "OVERLAY", nil, 7)
    cut:SetColorTexture(0, 0, 0, 0.8)
    cut:SetWidth(1)
    cut:SetPoint("TOP", costSpan, left and "TOPRIGHT" or "TOPLEFT")
    cut:SetPoint("BOTTOM", costSpan, left and "BOTTOMRIGHT" or "BOTTOMLEFT")
    -- (mana coming back: a shine running out along the fill, clipped to
    -- it, gone at full)
    local shineClip = CreateFrame("Frame", nil, power)
    shineClip:SetPoint("TOPLEFT", pfill)
    shineClip:SetPoint("BOTTOMRIGHT", pfill)
    shineClip:SetFrameLevel(power:GetFrameLevel() + L_OVER)
    shineClip:SetClipsChildren(true)
    p.shineClip = shineClip
    local shine = CreateFrame("Frame", nil, shineClip)
    shine:SetSize(SHINE_W, POWER_H)
    shine:SetPoint(left and "LEFT" or "RIGHT", power, "CENTER")
    shine:SetAlpha(0)
    for side = 1, 2 do
        local t = shine:CreateTexture(nil, "OVERLAY")
        t:SetTexture(WHITE)
        t:SetBlendMode("ADD")
        t:SetPoint(side == 1 and "TOPLEFT" or "TOPRIGHT")
        t:SetPoint(side == 1 and "BOTTOMRIGHT" or "BOTTOMLEFT", shine, side == 1 and "BOTTOM" or "BOTTOM")
        Fade(t, side == 1, { 1, 1, 1 }, 0.7, 0)
    end
    local run = shine:CreateAnimationGroup()
    local move = run:CreateAnimation("Translation")
    move:SetDuration(SHINE_TIME)
    move:SetSmoothing("IN_OUT")
    local seen = run:CreateAnimation("Alpha")
    seen:SetFromAlpha(1)
    seen:SetToAlpha(1)
    seen:SetDuration(SHINE_TIME)
    power.sized[#power.sized + 1] = function(half)
        move:SetOffset((left and -1 or 1) * (half + SHINE_W), 0)
    end
    p.shine = run
    powerHalves[i] = p
end

---------------------------------------------------------------------------
-- Curves: a colour's strength from your health or power percent
---------------------------------------------------------------------------
local curves = {}
local function Curve(points)
    if curves[points] ~= nil then return curves[points] or nil end
    curves[points] = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, c = pcall(function()
            local made = C_CurveUtil.CreateCurve()
            made:SetType(Enum.LuaCurveType.Linear)
            for _, p in ipairs(points) do made:AddPoint(p[1], p[2]) end
            return made
        end)
        if ok then curves[points] = c end
    end
    return curves[points] or nil
end

-- (made-up values while /if linetest runs: hp, hpMax, mp, mpMax, heal)
local demo

-- (the health's and the power's reads: value and max, percent by a curve)
local HEALTH = {
    Read = function()
        if demo then return demo.hp, demo.hpMax end
        return UnitHealth("player"), UnitHealthMax("player")
    end,
    Percent = function(c) return UnitHealthPercent("player", true, c) end,
}
local POWER = {
    Read = function()
        if demo then return demo.mp, demo.mpMax end
        return UnitPower("player"), UnitPowerMax("player")
    end,
    Percent = function(c) return UnitPowerPercent("player", nil, false, c) end,
}

-- (the heals coming to you, as they are (maybe secret, maybe nil))
local function IncomingHeals()
    if demo then return demo.heal end
    if not UnitGetIncomingHeals then return nil end
    local ok, v = pcall(UnitGetIncomingHeals, "player")
    if ok then return v end
    return nil
end

-- (a region's alpha from a curve of your health (or power) percent,
-- secret or not)
local function Shade(t, points, of)
    of = of or HEALTH
    -- (read whole, out of a fight: worked out here, never by the curve)
    local value, max = of.Read()
    if not (Secret(value) or Secret(max)) and type(value) == "number" and type(max) == "number" and max > 0 then
        local x, alpha = value / max, points[#points][2]
        for i = 2, #points do
            local p, q = points[i - 1], points[i]
            if x <= q[1] then
                alpha = p[2] + (q[2] - p[2]) * (x - p[1]) / math.max(q[1] - p[1], 0.0001)
                break
            end
        end
        t:SetAlpha(math.min(math.max(alpha, 0), 1))
        return
    end
    local c = Curve(points)
    if not (c and pcall(function() t:SetAlpha(of.Percent(c)) end)) then
        t:SetAlpha(0)
    end
end

---------------------------------------------------------------------------
-- Filling: the fill eased, the lead snapped (the gain shows past the fill
-- as it grows), the trail after (the loss shows past it as it shrinks):
-- never a comparison of the two, the bars' order does it
---------------------------------------------------------------------------
-- (a bar to a value, eased if asked; false when the value won't go)
local function To(bar, value, ease)
    if ease and SI and Try(bar.SetValue, bar, value, SI.ExponentialEaseOut) then return true end
    return Try(bar.SetValue, bar, value)
end

local function TrailTo(L, ease, empty)
    L.trail.at = nil
    for _, h in ipairs(L.halves) do
        if not To(h.trail, L.trail.value, ease) then h.trail:SetValue(empty) end
    end
end

-- (the line moved: the lead flashes, the spark flares (not too often))
local function Moved(L)
    for _, h in ipairs(L.halves) do
        h.flash:Stop()
        h.flash:Play()
    end
    local now = GetTime()
    if L.sparkAt and now - L.sparkAt < SPARK_GAP then return end
    L.sparkAt = now
    for _, h in ipairs(L.halves) do
        h.spark.flare:Stop()
        h.spark.flare:Play()
    end
end

-- (the heals coming to you, on the health's scale)
local function FillHeals(max)
    local coming = IncomingHeals()
    for _, h in ipairs(halves) do
        if not (Try(h.heal.SetMinMaxValues, h.heal, 0, max) and Try(h.heal.SetValue, h.heal, coming)) then
            h.heal:SetMinMaxValues(0, 1)
            h.heal:SetValue(0)
        end
    end
end

-- (the halves filled from your health as it is, the colours' strength;
-- eased: the trail follows after TRAIL_DELAY, else everything snaps)
local function Fill(ease)
    local value, max = HEALTH.Read()
    healthLine.trail.value = value
    for _, h in ipairs(halves) do
        local bar = h.bar
        if not (Try(bar.SetMinMaxValues, bar, 0, max) and To(bar, value, ease)) then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(1)
            healthLine.trail.value = 1
        end
        if not (Try(h.lead.SetMinMaxValues, h.lead, 0, max) and To(h.lead, value, false)) then
            h.lead:SetMinMaxValues(0, 1)
            h.lead:SetValue(0)
        end
        if not ease and not Try(h.trail.SetMinMaxValues, h.trail, 0, max) then
            h.trail:SetMinMaxValues(0, 1)
        end
        Shade(h.orange, ORANGE_POINTS)
        Shade(h.red, RED_POINTS)
        Shade(h.alarm, URGENT_POINTS)
    end
    FillHeals(max)
    if ease then
        healthLine.trail.at = GetTime() + TRAIL_DELAY
        Moved(healthLine)
    else
        TrailTo(healthLine, false, 1)
    end
end

-- (your power's kind, or nil (a secret))
local function PowerToken()
    if demo then return "MANA" end
    local ok, _, token = pcall(UnitPowerType, "player")
    if not ok or Secret(token) then return nil end
    return token
end

local function PowerColor(token)
    local c = PowerBarColor and PowerBarColor[token]
    return OWN_COLORS[token] or type(c) == "table" and c.r and { c.r, c.g, c.b } or POWER_COLOR
end

-- (the power's halves: its kind's colour on the fill, its value as it
-- is, eased on a change of it; its kind a secret: the last one kept)
local function FillPower(ease)
    local token = PowerToken() or powerHalves[1].token or "MANA"
    local value, max = POWER.Read()
    powerLine.trail.value = value
    for _, p in ipairs(powerHalves) do
        if p.token ~= token then
            p.token = token
            local color = PowerColor(token)
            Grade(p.bar:GetStatusBarTexture(), p.left, color)
            Fade(p.lead:GetStatusBarTexture(), p.left, Lit(color, 0.6), 1, 0.7)
            Fade(p.tint, p.left, color, TINT, 0.5)
            local cap = Lit(color, 0.5)
            p.cap:SetColorTexture(cap[1], cap[2], cap[3], 1)
            local spark = Lit(color, 0.4)
            p.spark:SetVertexColor(spark[1], spark[2], spark[3])
            local stripe = Lit(color, 0.5)
            p.costRibbon.stripes:SetVertexColor(stripe[1], stripe[2], stripe[3], 0.7)
        end
        local bar = p.bar
        if not (Try(bar.SetMinMaxValues, bar, 0, max) and To(bar, value, ease)) then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            powerLine.trail.value = 0
        end
        if not (Try(p.lead.SetMinMaxValues, p.lead, 0, max) and To(p.lead, value, false)) then
            p.lead:SetMinMaxValues(0, 1)
            p.lead:SetValue(0)
        end
        if not ease and not Try(p.trail.SetMinMaxValues, p.trail, 0, max) then
            p.trail:SetMinMaxValues(0, 1)
        end
        if not Try(p.cost.SetMinMaxValues, p.cost, 0, max) then p.cost:SetMinMaxValues(0, 1) end
        -- (low mana pulses, and its shine shows short of full; the other
        -- kinds run low by design)
        if token == "MANA" then
            Shade(p.low, LOW_POINTS, POWER)
            Shade(p.shineClip, FULL_POINTS, POWER)
        else
            p.low:SetAlpha(0)
            p.shineClip:SetAlpha(0)
        end
    end
    if ease then
        powerLine.trail.at = GetTime() + TRAIL_DELAY
        Moved(powerLine)
    else
        TrailTo(powerLine, false, 0)
    end
end

---------------------------------------------------------------------------
-- A spell's cost while you cast it, and mana coming back
---------------------------------------------------------------------------
local MANA_TYPE = Enum.PowerType and Enum.PowerType.Mana or 0

-- (a spell's cost in your power's kind, as it is (maybe secret); nil:
-- none known)
local function SpellCost(spellID, token)
    if not (spellID and C_Spell and C_Spell.GetSpellPowerCost) then return nil end
    local ok, cost = pcall(function()
        for _, c in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
            if c.name == token or (token == "MANA" and c.type == MANA_TYPE) then return c.cost end
        end
    end)
    -- (never tested for truth: it may be a secret)
    if ok then return cost end
    return nil
end

-- (the cast being shown; the last time a spell took mana)
local casting = {}
local spentAt = 0

-- (none: pass `false`; a cost, as it is, secret or not: never compared,
-- the bar takes it or doesn't)
local function ShowCost(cost)
    local some = Secret(cost) or type(cost) == "number"
    for _, p in ipairs(powerHalves) do
        if some and Try(p.cost.SetValue, p.cost, cost) then
            p.costClip:Show()
            if not p.costRibbon.drift:IsPlaying() then p.costRibbon.drift:Play() end
        else
            p.cost:SetValue(0)
            p.costClip:Hide()
        end
    end
end

local function CastStart(castGUID, spellID)
    -- (kept only as a plain string: a secret one ends on any cast's end)
    casting.guid = (not Secret(castGUID) and type(castGUID) == "string") and castGUID or true
    ShowCost(SpellCost(spellID, PowerToken() or powerHalves[1].token or "MANA"))
end

-- (the cast over: its cost gone, or taken)
local function CastEnd(castGUID)
    if not casting.guid then return end
    if type(casting.guid) == "string" and not Secret(castGUID) and type(castGUID) == "string"
        and castGUID ~= casting.guid then
        return
    end
    casting.guid = nil
    ShowCost(false)
end

-- (a spell went off: it took mana when it costs some)
local function Spent(spellID)
    local cost = SpellCost(spellID, "MANA")
    if Secret(cost) or (type(cost) == "number" and cost > 0) then spentAt = GetTime() end
end

-- (the mana's last whole read: out of a fight, a gain is told from it)
local lastMana
local function Gained()
    local value = POWER.Read()
    if Secret(value) or type(value) ~= "number" then
        lastMana = nil
        -- (in a fight: a change that isn't a spell's cost is mana coming back)
        return GetTime() - spentAt > 0.5
    end
    local up = lastMana ~= nil and value > lastMana
    lastMana = value
    return up
end

local function Shine()
    if (powerHalves[1].token or PowerToken()) ~= "MANA" then return end
    if not Gained() then return end
    for _, p in ipairs(powerHalves) do
        if not p.shine:IsPlaying() then p.shine:Play() end
    end
end

---------------------------------------------------------------------------
-- Probe: does Forever pause mana coming back after a spell (the five
-- second rule)? Out of a fight, each mana spell and each change of mana,
-- timed, into IF.db.manaLog (a fresh log per session). Remove once read.
---------------------------------------------------------------------------
local manaLog
local function Log(text)
    if not IF.db then return end
    if not manaLog then
        manaLog = { date("%Y-%m-%d %H:%M:%S") }
        IF.db.manaLog = manaLog
    end
    if #manaLog < 400 then
        manaLog[#manaLog + 1] = string.format("%.2f %s", GetTime() % 1000, text)
    end
end

local logged
local function LogMana(event, spellID)
    if demo or IF.InCombat() then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local cost = SpellCost(spellID, "MANA")
        if not Secret(cost) and type(cost) == "number" and cost > 0 then
            Log("cast " .. tostring(spellID) .. " cost " .. cost)
        end
        return
    end
    local value = UnitPower("player", MANA_TYPE)
    if Secret(value) or type(value) ~= "number" or value == logged then return end
    logged = value
    Log("mana " .. value)
end

---------------------------------------------------------------------------
-- Showing: the lines peek
---------------------------------------------------------------------------
-- (wanted: in a fight or not at rest (read whole out of one))
local function PowerWanted()
    if demo or IF.InCombat() then return true end
    local value, max = POWER.Read()
    if Secret(value) or Secret(max) or type(value) ~= "number" or type(max) ~= "number" then return true end
    if max <= 0 then return false end
    local token = PowerToken()
    if not token then return true end
    if RESTS_EMPTY[token] then return value > 0 end
    return value < max
end

local function Wanted()
    if demo then return true end
    if Flag(UnitIsDeadOrGhost, "player") then return false end
    -- (the health's line always on while alive; the power's peeks)
    return PlayerHealth.health or (PlayerHealth.power and PowerWanted()) or false
end

-- (the power's own fade: with the health's line always on, it peeks alone)
local function PowerGoal()
    return (not PlayerHealth.health or PowerWanted()) and 1 or 0
end

holder:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    if healthLine.trail.at and now >= healthLine.trail.at then TrailTo(healthLine, true, 1) end
    if powerLine.trail.at and now >= powerLine.trail.at then TrailTo(powerLine, true, 0) end
    local goal = (self.wanted or (self.holdUntil and now < self.holdUntil)) and 1 or 0
    local a = self:GetAlpha()
    if a ~= goal then
        a = goal > a and math.min(goal, a + elapsed / FADE) or math.max(goal, a - elapsed / FADE)
        self:SetAlpha(a)
    end
    local pa, pg = power:GetAlpha(), PowerGoal()
    if pa ~= pg then
        power:SetAlpha(pg > pa and math.min(pg, pa + elapsed / FADE) or math.max(pg, pa - elapsed / FADE))
    end
    if a <= 0 and goal == 0 then
        beat:Stop()
        powerBeat:Stop()
        self:Hide()
    end
end)

-- (each line: true eases it, false snaps it, nil leaves it be, so one
-- line's change never snaps the other's ease and trail away)
local function Update(health, mp)
    if not PlayerHealth.on then return end
    -- (unseen: snap, so it doesn't ease from a stale value as it shows)
    local unseen = not holder:IsShown() or holder:GetAlpha() <= 0
    if health and unseen then health = false end
    if mp and (unseen or power:GetAlpha() <= 0) then mp = false end
    if PlayerHealth.health and health ~= nil then Fill(health) end
    if PlayerHealth.power and mp ~= nil then FillPower(mp) end
    local was = holder.wanted
    holder.wanted = Wanted()
    if holder.wanted then
        holder.holdUntil = nil
        holder:Show()
        if PlayerHealth.health and not beat:IsPlaying() then beat:Play() end
        if PlayerHealth.power and not powerBeat:IsPlaying() then powerBeat:Play() end
    elseif Flag(UnitIsDeadOrGhost, "player") then
        holder.holdUntil = nil
    elseif was then
        -- (whole and at rest again: held a moment, the trail done, then faded)
        holder.holdUntil = GetTime() + HOLD
    end
end

local POWER_CHANGE = { UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true }
local POWER_SNAP = { UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }
local powerAt
local CAST_END = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_SUCCEEDED = true }
local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_HEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
-- (an event this client hasn't: left out, not an error)
for _, e in ipairs(UF.POWER_EVENTS) do pcall(events.RegisterUnitEvent, events, e, "player") end
pcall(events.RegisterUnitEvent, events, "UNIT_HEAL_PREDICTION", "player")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }) do
    events:RegisterUnitEvent(e, "player")
end
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:SetScript("OnEvent", function(_, event, _, castGUID, spellID)
    if event == "UNIT_SPELLCAST_START" then
        if PlayerHealth.power then CastStart(castGUID, spellID) end
        return
    elseif CAST_END[event] then
        CastEnd(castGUID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            Spent(spellID)
            LogMana(event, spellID)
        end
        return
    elseif event == "UNIT_HEAL_PREDICTION" then
        if PlayerHealth.on and PlayerHealth.health then FillHeals((select(2, HEALTH.Read()))) end
        return
    end
    if POWER_CHANGE[event] then
        -- (the two power events come together for one change: taken once)
        local now = GetTime()
        if now == powerAt then return end
        powerAt = now
        LogMana(event)
        if PlayerHealth.on and PlayerHealth.power and holder:IsShown() then Shine() end
        Update(nil, true)
    elseif event == "UNIT_HEALTH" then
        Update(true, nil)
    elseif event == "UNIT_MAXHEALTH" then
        Update(false, nil)
    elseif POWER_SNAP[event] then
        Update(nil, false)
    else
        -- (a fight's start or end, a load, dying or coming back: both snap)
        Update(false, false)
    end
end)

---------------------------------------------------------------------------
-- On while a setting is: the power on the edge, the health over it
-- sharing its top border (alone: on the edge)
---------------------------------------------------------------------------
local function Place(health, mp)
    line:SetShown(health)
    power:SetShown(mp)
    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, mp and POWER_H + 2 or 0)
    line:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, mp and POWER_H + 2 or 0)
    power:ClearAllPoints()
    power:SetPoint("BOTTOMLEFT")
    power:SetPoint("BOTTOMRIGHT")
    local h = (health and LINE_H or 0) + (mp and POWER_H or 0) + (health and mp and 2 or 0)
    holder:SetHeight(math.max(h, 1))
    if not health then beat:Stop() end
    if not mp then
        powerBeat:Stop()
        casting.guid = nil
        ShowCost(false)
    end
end

local function Watch()
    if not IF.db then return end
    local s = IN.Settings()
    local edit = UF.EditMode()
    local health, mp = s.hpLine and not edit or false, s.mpLine and not edit or false
    if health == PlayerHealth.health and mp == PlayerHealth.power then return end
    PlayerHealth.health, PlayerHealth.power = health, mp
    PlayerHealth.on = health or mp
    Place(health, mp)
    if PlayerHealth.on then
        Update(false, false)
    else
        holder.wanted, holder.holdUntil = false, nil
        healthLine.trail.at, powerLine.trail.at = nil, nil
        beat:Stop()
        powerBeat:Stop()
        holder:SetAlpha(0)
        holder:Hide()
    end
end

IN.Watcher("health line", 0.25, Watch)

function PlayerHealth.Apply()
    Watch()
end

---------------------------------------------------------------------------
-- /if linetest: the lines run through made-up values, a step every second
-- or two, each said in the chat with what to look for
---------------------------------------------------------------------------
local run = 0
local HP, MP = 1000, 1000

local function DemoStop(quiet)
    run = run + 1
    if not demo then return end
    demo = nil
    casting.guid = nil
    ShowCost(false)
    Update(false, false)
    if not quiet then IF.Print("Line test: done, the real values are back.") end
end

-- (a step: the values it sets, eased; what it shows; what it does after)
local function Set(hp, mp, heal)
    local easeH = hp ~= nil and hp ~= demo.hp
    local easeP = mp ~= nil and mp ~= demo.mp
    demo.hp, demo.mp = hp or demo.hp, mp or demo.mp
    if heal ~= nil then demo.heal = heal end
    if easeP then Shine() end
    Update(easeH or nil, easeP or nil)
    if heal ~= nil then FillHeals(demo.hpMax) end
end

local STEPS = {
    { 0, "full: two lines, the bright cap at each end, notches at 25/50/75%",
        function() Set(HP, MP, 0); Update(false, false) end },
    { 2, "mana -40%: a pale trail where it was, easing in after; a spark on the edge",
        function() Set(nil, 600) end },
    { 3, "casting (cost 25%): a striped ribbon drifting in at the end of the mana",
        function() casting.guid = true; ShowCost(250) end },
    { 2.5, "cast done: the cost taken",
        function() casting.guid = nil; ShowCost(false); Set(nil, 350) end },
    { 1.5, "mana coming back x3: the gain flashes past the fill, a shine runs along it",
        function() Set(nil, 400) end },
    { 1.2, nil, function() Set(nil, 450) end },
    { 1.2, nil, function() Set(nil, 500) end },
    { 2, "low mana (15%): the mana line pulses",
        function() Set(nil, 150) end },
    { 3, "hit to 45% health: orange, a pale trail; a heal coming (30%): a green striped ribbon past the fill",
        function() Set(450, nil, 300) end },
    { 3, "the heal lands: the gain flashes, the ribbon gone",
        function() Set(750, nil, 0) end },
    { 2.5, "health 20%: red, pulsing",
        function() Set(200) end },
    { 2.5, "casting with too little mana (cost 40% > 15%): the ribbon over the whole mana fill",
        function() casting.guid = true; ShowCost(400) end },
    { 3, nil, function() DemoStop() end },
}

local function DemoStep(i, id)
    if id ~= run or not demo then return end
    local step = STEPS[i]
    if not step then return end
    if step[2] then IF.Print(("Line test %d: %s"):format(i, step[2])) end
    step[3]()
    local nextStep = STEPS[i + 1]
    if nextStep then C_Timer.After(nextStep[1], function() DemoStep(i + 1, id) end) end
end

function PlayerHealth.Test(arg)
    if arg == "stop" then return DemoStop() end
    if not PlayerHealth.on then
        IF.Print("Line test: turn the Health line or Power line on first (Interface tab).")
        return
    end
    DemoStop(true)
    demo = { hp = HP, hpMax = HP, mp = MP, mpMax = MP, heal = 0 }
    lastMana = nil
    IF.Print("Line test: about 30 seconds. /if linetest stop to end it.")
    DemoStep(1, run)
end

IF.AddCommand("linetest", function(args) PlayerHealth.Test(args and args[1]) end,
    "[stop]: run the health and power lines through made-up values (trail, flash, cost, heals, low)")
