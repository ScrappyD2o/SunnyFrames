local ADDON, S = ...
S.Frames                 = S.Frames or {}
S.Frames.Elements        = S.Frames.Elements or {}
local H                  = {}
S.Frames.Elements.Health = H

-- Create bar + bg (bg sits on the health frame at BACKGROUND; bar texture = ARTWORK)
function S.Frames.Elements.Health.Attach(btn)
    if not btn or not btn:IsObjectType("Button") then return end

    -- Create / wire health bar
    if not btn.Health then
        local health = CreateFrame("StatusBar", nil, btn)
        health:SetPoint("TOPLEFT", 1, -1)
        health:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.Health = health
    else
        btn.Health:ClearAllPoints()
        btn.Health:SetPoint("TOPLEFT", 1, -1)
        btn.Health:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- Ensure children do NOT eat mouse (important for tooltip hover)
    if btn.Health.EnableMouse then btn.Health:EnableMouse(false) end  -- <<< NEW

    -- Keep the plane’s strata identical to the button
    local strata = btn:GetFrameStrata() or "MEDIUM"
    if btn.Health.SetFrameStrata then btn.Health:SetFrameStrata(strata) end

    -- Background lives on the same frame as the bar, at BACKGROUND
    if not btn.HealthBG then
        local bg = btn.Health:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn.Health)
        btn.HealthBG = bg
    else
        if btn.HealthBG:GetParent() ~= btn.Health then
            btn.HealthBG:ClearAllPoints()
            btn.HealthBG:SetParent(btn.Health)
            btn.HealthBG:SetAllPoints(btn.Health)
        end
        btn.HealthBG:SetDrawLayer("BACKGROUND")
    end

    -- Bar texture draws above the bg (within the health frame)
    local tex = btn.Health:GetStatusBarTexture()
    if tex and tex.SetDrawLayer then
        tex:SetDrawLayer("ARTWORK")
    end

    -- Register plane (don’t apply levels here; Layers.Apply will be called after all planes attach)
    local Layers = S.Frames.Layers
    if Layers and Layers.RegisterPlane then
        Layers.RegisterPlane(btn, "healthBar", btn.Health, 0)
    end

    S.Frames.Elements.Health.ApplyVisuals(btn)
end

function H.ApplyVisuals(btn)
    if not btn or not btn.Health or not btn.HealthBG then return end
    local Fp      = (S.Profile and S.Profile.frames) or {}
    local texPath = Fp.healthTex or "Interface\\TargetingFrame\\UI-StatusBar"
    btn.Health:SetStatusBarTexture(texPath)

    local bg = Fp.healthBackgroundColor or { 0.10, 0.10, 0.10, 1 }
    btn.HealthBG:SetColorTexture(bg[1] or 0.1, bg[2] or 0.1, bg[3] or 0.1, bg[4] ~= nil and bg[4] or 1)
end

local function colorFor(unit, frac)
    local Fp = (S.Profile and S.Profile.frames) or {}

    if Fp.useClassColors and UnitExists(unit) then
        local _, class = UnitClass(unit)
        local rc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if rc then return rc.r, rc.g, rc.b, 1 end
    end

    if Fp.healthAwareColor then
        local lowT  = (Fp.healthAwareColorLowThreshold  or 35) / 100
        local medT  = (Fp.healthAwareColorMedThreshold  or 70) / 100
        local highT = (Fp.healthAwareColorHighThreshold or 100) / 100
        if frac <= lowT then
            local c = Fp.healthAwareColorLow or { 0.85, 0.15, 0.15, 1 }
            return c[1], c[2], c[3], c[4] or 1
        elseif frac <= medT then
            local c = Fp.healthAwareColorMed or { 0.95, 0.80, 0.20, 1 }
            return c[1], c[2], c[3], c[4] or 1
        elseif frac <= highT then
            local c = Fp.healthAwareColorMed or { 0.95, 0.80, 0.20, 1 }
            return c[1], c[2], c[3], c[4] or 1
        else
            local c = Fp.healthAwareColorHigh or { 0.20, 0.80, 0.20, 1 }
            return c[1], c[2], c[3], c[4] or 1
        end
    end

    local c = Fp.healthColor or { 0.15, 0.80, 0.15, 1 }
    return c[1], c[2], c[3], c[4] or 1
end

function H.Update(unit)
    if not unit then return end
    local map = S.Frames.UnitMap
    if not map then return end
    local btn = map[unit]
    if not btn or not btn.Health then return end

    local maxv = UnitHealthMax(unit) or 0
    local cur  = UnitHealth(unit) or 0
    local frac = (maxv > 0) and (cur / maxv) or 0

    btn.Health:SetMinMaxValues(0, 1)
    btn.Health:SetValue(frac)

    local r, g, b, a = colorFor(unit, frac)
    btn.Health:SetStatusBarColor(r, g, b, a)
end

function H.RefreshAll()
    if not S.Frames.UnitMap then return end
    for unit, btn in pairs(S.Frames.UnitMap) do
        H.ApplyVisuals(btn)
        H.Update(unit)
    end
end

function H.EnsureEvents()
    if H._registered then return end
    local E = S.Frames.Events
    if not E or not E.Subscribe then return end

    E.Subscribe("PLAYER_ENTERING_WORLD", "Elements.Health", function() H.RefreshAll() end)
    E.Subscribe("UNIT_HEALTH",    "Elements.Health", function(_, unit) if unit then H.Update(unit) end end)
    E.Subscribe("UNIT_MAXHEALTH", "Elements.Health", function(_, unit) if unit then H.Update(unit) end end)

    H._registered = true
end

return H
