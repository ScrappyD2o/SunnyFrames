local ADDON, S = ...
S.Frames               = S.Frames or {}
S.Frames.Elements      = S.Frames.Elements or {}
local N                = {}
S.Frames.Elements.Name = N

function S.Frames.Elements.Name.Attach(btn)
    if not btn or not btn:IsObjectType("Button") then return end

    -- Ensure a dedicated layer frame for text
    if not btn.NameLayer then
        local f = CreateFrame("Frame", nil, btn)
        f:SetAllPoints(btn)
        btn.NameLayer = f
    end

    -- Keep strata identical to the button to avoid cross-strata surprises
    local strata = btn:GetFrameStrata() or "MEDIUM"
    if btn.NameLayer.SetFrameStrata then
        btn.NameLayer:SetFrameStrata(strata)
    end

    -- If an older build created NameText on the BUTTON, migrate it to NameLayer
    if btn.NameText and btn.NameText.GetParent and btn.NameText:GetParent() ~= btn.NameLayer then
        -- carry over text/font, then re-parent and re-anchor
        local txt   = btn.NameText:GetText()
        local fnt, sz, flags = btn.NameText:GetFont()

        btn.NameText:ClearAllPoints()
        btn.NameText:SetParent(btn.NameLayer)
        btn.NameText:SetPoint("CENTER")

        if fnt then btn.NameText:SetFont(fnt, sz or 12, flags) end
        if txt then btn.NameText:SetText(txt) end
    end

    -- Create if missing (new installs)
    if not btn.NameText then
        local fs = btn.NameLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER")
        fs:SetText("")
        btn.NameText = fs
    end

    -- Ensure sane visual defaults
    if btn.NameText.SetDrawLayer then
        -- (sublevel arg is ignored for FontStrings on some builds; that's fine)
        btn.NameText:SetDrawLayer("OVERLAY")
    end
    if btn.NameText.SetTextColor then
        btn.NameText:SetTextColor(1, 1, 1, 1)
    end
    btn.NameText:Show()

    -- Register the plane; Layers.Apply will push NameLayer above healthBar
    local Layers = S.Frames and S.Frames.Layers
    if Layers and Layers.RegisterPlane then
        Layers.RegisterPlane(btn, "nameText", btn.NameLayer, 0)
    end
end

local function truncate(name, maxLen)
    name = tostring(name or "")
    if #name > maxLen then
        return name:sub(1, maxLen) .. "…"
    end
    return name
end

function N.Update(unit)
    local map = S.Frames.UnitMap
    if not map then return end
    local btn = map[unit]
    if not btn or not btn.NameText then return end

    local Fp       = (S.Profile and S.Profile.frames) or {}
    local nameMax  = tonumber(Fp.maxNameLength) or 12
    local fontObj  = GameFontHighlightSmall
    local fnt, _, flags = fontObj:GetFont()
    local fontSize = tonumber(Fp.fontSize) or 12

    local nm = UnitExists(unit) and UnitName(unit) or unit
    btn.NameText:SetText(truncate(nm, nameMax))
    if fnt and btn.NameText.SetFont then
        btn.NameText:SetFont(fnt, fontSize, flags)
    end
end

function N.RefreshAll()
    if not S.Frames.UnitMap then return end
    for unit in pairs(S.Frames.UnitMap) do
        N.Update(unit)
    end
end

function N.EnsureEvents()
    if N._registered then return end
    local E = S.Frames.Events
    if not E or not E.Subscribe then return end
    E.Subscribe("PLAYER_ENTERING_WORLD", "Elements.Name", function() N.RefreshAll() end)
    E.Subscribe("GROUP_ROSTER_UPDATE",   "Elements.Name", function() N.RefreshAll() end)
    E.Subscribe("UNIT_NAME_UPDATE",      "Elements.Name", function(_, unit)
        if unit then N.Update(unit) else N.RefreshAll() end
    end)
    N._registered = true
end
