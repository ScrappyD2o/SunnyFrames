-- Core/Handle.lua
local ADDON, S = ...
S = _G[ADDON] or S or {}
_G[ADDON] = S
S.Handle = S.Handle or {}
S.Frames = S.Frames or {}

function SunnyFrames_Refresh()
    if S and S.Frames and S.Frames.BuildPartySimple then
        S.Frames.BuildPartySimple()
    end
end

S.Refresh = SunnyFrames_Refresh
S.Rebuild = SunnyFrames_Refresh

local function style(h)
    h:SetBackdrop({
        bgFile  = "Interface/Buttons/WHITE8x8",
        edgeFile= "Interface/Buttons/WHITE8x8",
        edgeSize= 1,
    })
    h:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    h:SetBackdropBorderColor(0, 0, 0, 1)
end

function S.Handle.Ensure()
    local c = _G.SunnyFramesPartyContainer
    if not c then return nil end

    local h = _G.SunnyFramesHandle
    if h and h:IsObjectType("Button") then
        -- keep a reference for SetLocked
        S.Handle._frame = h
        return h
    end

    -- Create handle
    h = CreateFrame("Button", "SunnyFramesHandle", c, "BackdropTemplate")
    h:SetSize(25, 10)
    h:SetFrameStrata("HIGH")
    h:SetFrameLevel(c:GetFrameLevel() + 5)
    h:RegisterForClicks("AnyUp")
    h:EnableMouse(true)

    -- Styling (use your existing style() if present)
    if type(style) == "function" then
        style(h)
    else
        h:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8", edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
        h:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
        h:SetBackdropBorderColor(0, 0, 0, 1)
    end

    -- Drag scripts (guarded by lock)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function(self)
        local locked = S.Profile and S.Profile.general and S.Profile.general.lockFrames
        if locked then return end
        local target = _G.SunnyFramesPartyContainer
        if target and target.StartMoving then
            target:StartMoving()
            self._dragTarget = target
        end
    end)

    h:SetScript("OnDragStop", function(self)
        local target = self._dragTarget or _G.SunnyFramesPartyContainer
        if target and target.StopMovingOrSizing then
            target:StopMovingOrSizing()
        end
        self._dragTarget = nil
        if S.SavePosition then S.SavePosition() end -- persists + rebuilds + slider sync
    end)

    -- Right-click → open config
    h:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" and type(_G.SunnyFrames_ToggleConfig) == "function" then
            _G.SunnyFrames_ToggleConfig()
        end
    end)

    -- Tooltip (dynamic: shows Locked when frames are locked)
    h:SetScript("OnEnter", function(self)
        local locked = S.Profile and S.Profile.general and S.Profile.general.lockFrames
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("SunnyFrames", 1, 1, 1)
        if locked then
            GameTooltip:AddLine("Frames locked", 0.9, 0.3, 0.3)
        else
            GameTooltip:AddLine("Left-drag to move", 0.9, 0.9, 0.9)
        end
        GameTooltip:AddLine("Right-click: options", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Remember for SetLocked
    S.Handle._frame = h

    -- Respect current lock immediately
    local locked = S.Profile and S.Profile.general and S.Profile.general.lockFrames
    if locked then
        h:RegisterForDrag() -- clears drags
        h:SetAlpha(0.8)
    else
        h:RegisterForDrag("LeftButton")
        h:SetAlpha(1.0)
    end

    return h
end

function S.Handle.Position()
    local c = _G.SunnyFramesPartyContainer
    local h = S.Handle.Ensure()
    if not c or not h then return end

    local pos = (S.Profile and S.Profile.general and S.Profile.general.handleAnchorPosition) or "TOPLEFT"
    pos = string.upper(pos)

    h:ClearAllPoints()
    if     pos == "TOPLEFT" then
        h:SetPoint("BOTTOMLEFT",  c, "TOPLEFT",     0,  8)
    elseif pos == "TOPRIGHT" then
        h:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT",    0,  8)
    elseif pos == "BOTTOMLEFT" then
        h:SetPoint("TOPLEFT",     c, "BOTTOMLEFT",  0, -8)
    elseif pos == "BOTTOMRIGHT" then
        h:SetPoint("TOPRIGHT",    c, "BOTTOMRIGHT", 0, -8)
    else
        -- fallback
        h:SetPoint("BOTTOMLEFT",  c, "TOPLEFT",     0,  8)
    end

    h:Show()

    -- Re-apply lock visuals in case Position() was called standalone
    local locked = S.Profile and S.Profile.general and S.Profile.general.lockFrames
    if locked then
        h:RegisterForDrag()
        h:SetAlpha(0.8)
    else
        h:RegisterForDrag("LeftButton")
        h:SetAlpha(1.0)
    end

    if S.dprintf then S.dprintf("Handle: anchored %s", pos) end
end

function S.Handle.SetLocked(locked)
    S.Profile         = S.Profile or {}
    S.Profile.general = S.Profile.general or {}
    S.Profile.general.lockFrames = not not locked

    local h = S.Handle._frame or _G.SunnyFramesHandle
    if not h then return end

    if locked then
        h:RegisterForDrag() -- clears drags
        h:SetAlpha(0.8)
    else
        h:RegisterForDrag("LeftButton")
        h:SetAlpha(1.0)
    end
end
