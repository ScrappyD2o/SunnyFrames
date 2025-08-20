local ADDON, S = ...
S.Frames        = S.Frames or {}
S.Frames.Click  = S.Frames.Click or {}

-- Apply secure click-targeting based on profile
function S.Frames.Click.Apply(btn, unit)
    if not btn or not unit then return end
    btn.unit = unit

    local G = (S.Profile and S.Profile.general) or {}
    local enabled = (G.enableClickTargeting ~= false)

    if InCombatLockdown() then return end
    if not btn.SetAttribute then return end

    if enabled then
        btn:RegisterForClicks("AnyUp")
        btn:SetAttribute("unit", unit)
        btn:SetAttribute("type1", "target")     -- left: target
        btn:SetAttribute("type2", "togglemenu") -- right: menu
    else
        btn:RegisterForClicks()                 -- clear
        btn:SetAttribute("type1", nil)
        btn:SetAttribute("type2", nil)
        btn:SetAttribute("unit", nil)
    end
end

-- Compatibility wrappers (some code may call these)
function S.Frames.ApplyClickTargeting(btn)
    if not btn then return end
    local unit = btn.unit or (btn.GetAttribute and btn:GetAttribute("unit"))
    if not unit then return end
    S.Frames.Click.Apply(btn, unit)
end

function S.Frames.UpdateClickTargeting()
    local F = S.Frames.Factory
    if not F or not F.Active then return end
    local actives = F.Active()
    for _, btn in pairs(actives) do
        local unit = btn.unit or (btn.GetAttribute and btn:GetAttribute("unit"))
        if unit then S.Frames.Click.Apply(btn, unit) end
    end
end
