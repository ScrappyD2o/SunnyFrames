local ADDON, S = ...
S             = _G[ADDON] or S or {}
_G[ADDON]     = S
S.Tooltips     = S.Tooltips or {}

local T        = S.Tooltips
local DO       = S.DebugOverlay -- optional; logs if present

-- ---------------------------------------------------------------------------
-- Profile helpers
-- ---------------------------------------------------------------------------
local function P() return (S.Profile and S.Profile.general) or {} end

local function tooltipsEnabled()
    local Gen = P()
    return Gen.enableTooltips ~= false -- default ON
end

local function hideInCombat()
    local Gen = P()
    return Gen.hideToolTipsInCombat and true or false
end

local function rawAnchor()
    local Gen = P()
    return (Gen.tooltipAnchorPosition or "DEFAULT")
end

local function dlog(fmt, ...)
    if DO and DO.Log then DO.Log(fmt, ...) end
end

-- ---------------------------------------------------------------------------
-- Anchor normalization & placement
-- ---------------------------------------------------------------------------
-- Normalize many user strings to canonical keys
local function normAnchor()
    local a = tostring(rawAnchor()):upper():gsub("%s+", "")
    if a == "DEFAULT" then return "DEFAULT" end
    if a == "CURSOR" or a == "ANCHOR_CURSOR" or a == "ANCHORCURSOR" then return "CURSOR" end

    if a == "TOPLEFT"      or a == "ANCHOR_TOPLEFT"      or a == "ANCHORTOPLEFT"      then return "TL" end
    if a == "TOPRIGHT"     or a == "ANCHOR_TOPRIGHT"     or a == "ANCHORTOPRIGHT"     then return "TR" end
    if a == "BOTTOMLEFT"   or a == "ANCHOR_BOTTOMLEFT"   or a == "ANCHORBOTTOMLEFT"   then return "BL" end
    if a == "BOTTOMRIGHT"  or a == "ANCHOR_BOTTOMRIGHT"  or a == "ANCHORBOTTOMRIGHT"  then return "BR" end

    -- Also accept "Top Left"/"Bottom Right", etc.
    if a == "TOPLEFT"  or a == "TOPLEFT"  then return "TL" end
    if a == "TOPRIGHT" or a == "TOPRIGHT" then return "TR" end
    if a == "BOTTOMLEFT"  then return "BL" end
    if a == "BOTTOMRIGHT" then return "BR" end

    return "DEFAULT"
end

-- Exact corner mapping you requested:
--   TL: tooltip BOTTOMRIGHT -> owner TOPLEFT
--   TR: tooltip BOTTOMLEFT  -> owner TOPRIGHT
--   BL: tooltip TOPRIGHT    -> owner BOTTOMLEFT
--   BR: tooltip TOPLEFT     -> owner BOTTOMRIGHT
local CORNER_POINTS = {
    TL = { "BOTTOMRIGHT", "TOPLEFT",     0,  0 },
    TR = { "BOTTOMLEFT",  "TOPRIGHT",    0,  0 },
    BL = { "TOPRIGHT",    "BOTTOMLEFT",  0,  0 },
    BR = { "TOPLEFT",     "BOTTOMRIGHT", 0,  0 },
}

local function setOwnerAndPlace(owner)
    local mode = normAnchor()
    if mode == "DEFAULT" then
        if GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(GameTooltip, owner or UIParent)
        else
            GameTooltip:SetOwner(owner or UIParent, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
        end
        dlog("Tooltip anchor=DEFAULT")
        return
    end

    if mode == "CURSOR" then
        GameTooltip:SetOwner(owner or UIParent, "ANCHOR_CURSOR")
        dlog("Tooltip anchor=CURSOR")
        return
    end

    local cfg = CORNER_POINTS[mode]
    if cfg then
        local tipPoint, ownerPoint, dx, dy = unpack(cfg)
        GameTooltip:SetOwner(owner or UIParent, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint(tipPoint, owner or UIParent, ownerPoint, dx, dy)
        dlog("Tooltip anchor=%s via %s -> %s (%d,%d)", mode, tipPoint, ownerPoint, dx, dy)
        return
    end

    -- Fallback
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, owner or UIParent)
    else
        GameTooltip:SetOwner(owner or UIParent, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
    end
    dlog("Tooltip anchor=fallback DEFAULT")
end

-- ---------------------------------------------------------------------------
-- Tooltip handlers
-- ---------------------------------------------------------------------------
local function resolveUnit(btn)
    if btn._sfTooltipUnit then return btn._sfTooltipUnit, "_sfTooltipUnit" end
    if btn.unit            then return btn.unit,            "btn.unit"      end
    if btn.GetAttribute then
        local u = btn:GetAttribute("unit")
        if u then return u, 'GetAttribute("unit")' end
    end
    return nil, "nil"
end

local function onEnter(self)
    if not tooltipsEnabled() then return end
    if hideInCombat() and InCombatLockdown and InCombatLockdown() then return end

    local unit, src = resolveUnit(self)
    dlog("OnEnter: unit=%s (src=%s); anchorRaw=%s norm=%s", tostring(unit), tostring(src), tostring(rawAnchor()), tostring(normAnchor()))
    if not unit or not UnitExists(unit) then return end

    setOwnerAndPlace(self)
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
    dlog("Tooltip shown for %s", unit)
end

local function onLeave(self)
    GameTooltip:Hide()
    dlog("OnLeave: tooltip hidden")
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function T.Apply(btn, unit)
    if not btn or not btn.IsObjectType or not btn:IsObjectType("Button") then
        dlog("Apply: not a Button")
        return
    end

    if btn.EnableMouse then btn:EnableMouse(true) end

    if unit then
        btn._sfTooltipUnit = unit
        btn.unit = unit
    end

    if not btn._sfTooltipHooked then
        btn:HookScript("OnEnter", onEnter)
        btn:HookScript("OnLeave", onLeave)
        btn._sfTooltipHooked = true
        dlog("Apply: hooked for %s", tostring(unit))
    end
end

function T.RefreshAll()
    if not S.Frames or not S.Frames.UnitMap then
        dlog("RefreshAll: no UnitMap")
        return
    end
    local n = 0
    for unit, btn in pairs(S.Frames.UnitMap) do
        T.Apply(btn, unit)
        n = n + 1
    end
    dlog("RefreshAll: applied to %d buttons", n)
end

-- Re-apply when general settings change
do
    local prev = S.NotifyProfileChanged
    S.NotifyProfileChanged = function(section)
        if type(prev) == "function" then pcall(prev, section) end
        if section == "general" then
            T.RefreshAll()
        end
    end
end
