-- Core/Core.lua
local ADDON, S = ...
S = _G[ADDON] or S or {}
_G[ADDON] = S
S.Frames = S.Frames or {}

-- Lightweight debug logger (toggle via /sframes debug)
local function _debugEnabled()
    return S.Profile and S.Profile.general and S.Profile.general.debug == true
end
function S.dprintf(fmt, ...)
    if not _debugEnabled() then return end
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    if not ok then msg = tostring(fmt) end
    print("|cffFFD200SunnyFrames|r "..msg)
end

-- Returns: px (1 physical pixel in UI units for 'frame'), snapped(n) which is 'n' rounded to the nearest pixel.
function S.UI_GetPixel(frame)
    local f = frame or UIParent
    local scale = f:GetEffectiveScale()
    local px = 1 / scale
    return px, function(n)
        local p = math.max(0, n or 0)
        return math.floor(p/px + 0.5) * px
    end
end

-- Central notifier for profile -> UI
function S.NotifyProfileChanged(section)
    if not S then return end
    local U = S.UI

    if section == "party" and U and U.SyncPartyFromDB then
        U.SyncPartyFromDB()
        if S.Frames_RefreshAllBorders then
            S.Frames_RefreshAllBorders()
        end

    elseif section == "raid" and U and U.SyncRaidFromDB then
        U.SyncRaidFromDB()

    elseif section == "frames" then
        local E = S.Frames and S.Frames.Elements
        if E and E.Health and E.Health.RefreshAll then E.Health.RefreshAll() end
        if E and E.Name   and E.Name.RefreshAll   then E.Name.RefreshAll()   end
    end
end

-- Re-anchor the party container from DB (and keep the Handle snapped)
function S.ApplyPartyOffsets()
    local c = _G.SunnyFramesPartyContainer
    if not c or not S.Profile or not S.Profile.party then return end

    local dx = S.Profile.party.xPos or 0
    local dy = S.Profile.party.yPos or 0

    local rel = S.root or UIParent
    c:ClearAllPoints()
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(c, "CENTER", rel, "CENTER", dx, dy)
    else
        c:SetPoint("CENTER", rel, "CENTER", dx, dy)
    end

    if S.Handle and S.Handle.Position then
        S.Handle.Position()
    end
end

-- Central notifier for profile -> live UI/apply
function S.NotifyProfileChanged(section)
    if not S then return end
    local U = S.UI

    -- 1) Sync UI-derived state from the DB (no early return!)
    if section == "party" and U and U.SyncPartyFromDB then
        U.SyncPartyFromDB()
    elseif section == "raid" and U and U.SyncRaidFromDB then
        U.SyncRaidFromDB()
    end

    -- 2) Layout/position changes for party typically need a full refresh
    if section == "party" and S.Refresh then
        S.Refresh()
    end

    -- 3) Keep z-order correct (name text & border above bars)
    local L = S.Frames and S.Frames.Layers
    if L and L.ApplyAll then
        L.ApplyAll()
    end

    -- 4) Repaint elements so class colours / health-aware colours / textures update live
    local E = S.Frames and S.Frames.Elements
    if E then
        if E.Health  and E.Health.RefreshAll  then E.Health.RefreshAll()  end
        if E.Power   and E.Power.RefreshAll   then E.Power.RefreshAll()   end
        if E.Castbar and E.Castbar.RefreshAll then E.Castbar.RefreshAll() end
        if E.Name    and E.Name.RefreshAll    then E.Name.RefreshAll()    end
    end

    -- 5) Border thickness/color may change with party appearance settings
    if S.Frames_RefreshAllBorders then
        S.Frames_RefreshAllBorders()
    end
end

-- Root: keep at center; the party container is what moves
local function EnsureRoot()
    if S.root and S.root:IsObjectType("Frame") then return S.root end
    local f = CreateFrame("Frame", "SunnyFramesRoot", UIParent, "BackdropTemplate")
    f:SetSize(2, 2)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:Show()
    S.root = f
    S.dprintf("Created root frame: %s", "SunnyFramesRoot")
    return f
end

-- Public refresh used by the config UI
function SunnyFrames_Refresh()
    EnsureRoot()
    S.dprintf("Refresh triggered")
    if S.Frames and S.Frames.BuildPartySimple then
        S.Frames.BuildPartySimple()
    end
end
S.Refresh = SunnyFrames_Refresh
S.Rebuild = SunnyFrames_Refresh

-- Called by DB.lua lifecycle
function S.OnDBReady()        SunnyFrames_Refresh() end
function S.OnProfileChanged()  SunnyFrames_Refresh() end

function S.SavePosition()
    local c = _G.SunnyFramesPartyContainer
    if not c then return end

    local cx, cy = c:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and cy and ux and uy) then return end

    -- Pixel-perfect rounding based on UI scale (prevents ghosting)
    local scale = UIParent:GetEffectiveScale()
    local dx = (cx - ux) * scale
    local dy = (cy - uy) * scale
    dx = (dx >= 0) and math.floor(dx + 0.5) or math.ceil(dx - 0.5)
    dy = (dy >= 0) and math.floor(dy + 0.5) or math.ceil(dy - 0.5)
    dx = dx / scale
    dy = dy / scale

    S.Profile = S.Profile or {}
    S.Profile.party = S.Profile.party or {}
    S.Profile.party.xPos = dx
    S.Profile.party.yPos = dy

    S.dprintf("Saved party container pos: (%.1f, %.1f)", dx, dy)

    S.NotifyProfileChanged("party")

    -- Normalize the anchor to CENTER + x,y (also snapped) relative to S.root
    local rel = S.root or UIParent
    c:ClearAllPoints()
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(c, "CENTER", rel, "CENTER", dx, dy)
    else
        c:SetPoint("CENTER", rel, "CENTER", dx, dy)
    end
    
    if S.Refresh then S.Refresh() end
    if S.UI and S.UI.SyncPartyFromDB then S.UI.SyncPartyFromDB() end
end

-- Safety if DB loads first
C_Timer.After(0, function() if S.Profile then SunnyFrames_Refresh() end end)
