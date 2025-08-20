-- Frames/Manager.lua
local ADDON, S = ...
S.Frames = S.Frames or {}
local M = {}
S.Frames.Manager = M

local Factory = S.Frames.Factory

local partyContainer

-- Click-targeting helpers
S.Frames = S.Frames or {}

function S.Frames.ApplyClickTargeting(btn)
    if not btn or not btn.SetAttribute then return end
    local enabled = S.Profile and S.Profile.general and S.Profile.general.enableClickTargeting

    if InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            S.Frames.ApplyClickTargeting(btn)
        end)
        return
    end

    -- Make sure the button can receive mouse
    if btn.EnableMouse then btn:EnableMouse(enabled and true or false) end

    -- If we know the unit but the attribute differs/missing, set it
    if btn.unit and btn.GetAttribute and (btn:GetAttribute("unit") ~= btn.unit) then
        btn:SetAttribute("unit", btn.unit)
    end

    if enabled then
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetAttribute("*type1", "target")
        btn:SetAttribute("*type2", "menu")
        if S.Profile and S.Profile.general and S.Profile.general.debug then
            btn:SetScript("PostClick", function(self, which)
                if S.dprintf then
                    S.dprintf("Clicked %s (%s) -> unit=%s", self:GetName() or "<?>", which, tostring(self:GetAttribute("unit")))
                end
            end)
        else
            btn:SetScript("PostClick", nil)
        end
    else
        btn:RegisterForClicks()
        btn:SetAttribute("*type1", nil)
        btn:SetAttribute("*type2", nil)
        btn:SetScript("PostClick", nil)
    end
end

function S.Frames.UpdateClickTargeting()
    local F = S.Frames.Factory
    local active = F and F.Active and F.Active()
    if not active then return end
    for _, btn in pairs(active) do
        S.Frames.ApplyClickTargeting(btn)
    end
end

function S.Frames.BuildPartySimple()
    if not S or not S.Profile then return end
    local P   = S.Profile.party   or {}
    local Gen = S.Profile.general or {}

    -- Container --------------------------------------------------------------
    local c = _G.SunnyFramesPartyContainer
    if not c or not c:IsObjectType("Frame") then
        c = CreateFrame("Frame", "SunnyFramesPartyContainer", UIParent, "BackdropTemplate")
        c:SetSize(2, 2)
        c:SetMovable(true)
        c:SetClampedToScreen(true)
        if c.EnableMouse then c:EnableMouse(false) end
        if c.EnableMouseWheel then c:EnableMouseWheel(false) end
    end

    -- Global scale (pixel-perfect) ------------------------------------------
    local scalePercent = tonumber(Gen.globalFrameScale) or 100
    if scalePercent < 1   then scalePercent = 1   end
    if scalePercent > 200 then scalePercent = 200 end
    local scale = scalePercent / 100
    c:SetScale(scale)

    -- Position: SNAP TO PARENT PIXELS so children inherit a clean origin -----
    local dx = tonumber(P.xPos) or 0
    local dy = tonumber(P.yPos) or 0

    local parent = UIParent
    local ps = (parent and parent.GetEffectiveScale and parent:GetEffectiveScale()) or 1
    if ps <= 0 then ps = 1 end
    local pixel = 1 / ps
    local function snap_parent(v)
        if v >= 0 then return math.floor(v / pixel + 0.5) * pixel
        else           return math.ceil (v / pixel - 0.5) * pixel end
    end
    local sdx, sdy = snap_parent(dx), snap_parent(dy)

    c:ClearAllPoints()
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(c, "CENTER", parent, "CENTER", sdx, sdy)
    else
        c:SetPoint("CENTER", parent, "CENTER", sdx, sdy)
    end
    c:Show()

    -- Roster -----------------------------------------------------------------
    local R = S.Frames.Roster
    local units = (R and R.BuildPartyList and R.BuildPartyList()) or { "player" }

    -- Pool / map -------------------------------------------------------------
    local F = S.Frames.Factory
    F.EnsurePool(c, #units)
    S.Frames.UnitMap = S.Frames.UnitMap or {}
    for k in pairs(S.Frames.UnitMap) do S.Frames.UnitMap[k] = nil end

    local buttons = {}
    local Health  = S.Frames.Elements and S.Frames.Elements.Health
    local Name    = S.Frames.Elements and S.Frames.Elements.Name

    if Health and Health.EnsureEvents then Health.EnsureEvents() end
    if Name   and Name.EnsureEvents   then Name.EnsureEvents()   end

    for i, unit in ipairs(units) do
        local btn = F.Acquire(i, c)

        -- Attach planes
        if Health and Health.Attach then Health.Attach(btn) end
        if Name   and Name.Attach   then Name.Attach(btn)   end

        -- Click targeting
        if S.Frames.Click and S.Frames.Click.Apply then
            S.Frames.Click.Apply(btn, unit)
        end

        -- Tooltips (NEW)
        if S.Tooltips and S.Tooltips.Apply then
            S.Tooltips.Apply(btn, unit)
        end

        -- Apply layering AFTER all planes register
        local Layers = S.Frames and S.Frames.Layers
        if Layers and Layers.Apply then Layers.Apply(btn) end

        -- Paint/update
        if Health and Health.Update then Health.Update(unit) end
        if Name   and Name.Update   then Name.Update(unit)   end

        S.Frames.UnitMap[unit] = btn
        buttons[i] = btn
    end

    -- Hide any extra pooled buttons
    do
        local i = #units + 1
        while true do
            local btn = F.Get and F.Get(i)
            if not btn then break end
            btn:Hide()
            i = i + 1
        end
    end

    -- Layout -----------------------------------------------------------------
    local L = S.Frames.Layout
    if L and L.Apply then
        L.Apply(c, buttons, P)
    end

    -- Handle (drag anchor etc.)
    if S.Handle and S.Handle.Ensure    then S.Handle.Ensure()    end
    if S.Handle and S.Handle.Position  then S.Handle.Position()  end
    if S.Handle and S.Handle.SetLocked then S.Handle.SetLocked(Gen.lockFrames) end

    -- UI ranges and debug
    if S.UI and S.UI.UpdatePartyPositionSliderRanges then
        S.UI.UpdatePartyPositionSliderRanges()
    end

    if S.dprintf then
        S.dprintf("BuildPartySimple: scale=%.2f, offset=(%.2f, %.2f) snapped=(%.2f, %.2f), units=%d",
                scale, dx, dy, sdx, sdy, #buttons)
    end
end

local function Refresh()
    if S and S.Refresh then
        S.Refresh()
    elseif S and S.Frames and S.Frames.BuildPartySimple then
        S.Frames.BuildPartySimple()
    end
end

local function roundToPixel(v)
    local s = UIParent:GetEffectiveScale()
    if s == 0 then
        return v
    end
    local px = v * s
    px = (px >= 0) and math.floor(px + 0.5) or math.ceil(px - 0.5)
    return px / s
end

local function SnapSize(f, w, h)
    if not f or type(f) ~= "table" or not f.SetSize then
        return
    end
    w, h = roundToPixel(w or 1), roundToPixel(h or 1)
    -- Prefer PixelUtil only if both it and the region exist
    if PixelUtil and PixelUtil.SetSize then
        local ok = pcall(PixelUtil.SetSize, f, w, h)
        if ok then
            return
        end
    end
    f:SetSize(w, h)
end

local function SnapPoint(f, point, rel, relPoint, x, y)
    if not f or type(f) ~= "table" or not f.SetPoint then
        return
    end
    x, y = roundToPixel(x or 0), roundToPixel(y or 0)
    if PixelUtil and PixelUtil.SetPoint then
        local ok = pcall(PixelUtil.SetPoint, f, point, rel, relPoint, x, y)
        if ok then
            return
        end
    end
    f:ClearAllPoints()
    f:SetPoint(point, rel, relPoint, x, y)
end

local function EnsurePartyContainer()
    if S.dprintf then
        S.dprintf("EnsurePartyContainer")
    end
    if partyContainer and partyContainer:IsObjectType("Frame") then
        return partyContainer
    end
    partyContainer = CreateFrame("Frame", "SunnyFramesPartyContainer", UIParent, "BackdropTemplate")
    partyContainer:SetSize(2, 2)
    partyContainer:ClearAllPoints()
    SnapPoint(c, "CENTER", UIParent, "CENTER", 0, 0)
    partyContainer:SetMovable(true)
    partyContainer:SetClampedToScreen(true)
    partyContainer:Show()
    return partyContainer
end

-- Read current DB and apply screen offset from sliders (CENTER + xPos,yPos)
local function ApplyContainerPosition()
    local p = (S.Profile and S.Profile.party) or {}
    local x = tonumber(p.xPos) or 0
    local y = tonumber(p.yPos) or 0
    local c = EnsurePartyContainer()
    SnapPoint(c, "CENTER", UIParent, "CENTER", x, y)
end

-- Build roster (player + partyN)
local function BuildUnits()
    local list = {}
    if UnitExists("player") then
        table.insert(list, "player")
    end
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then
            table.insert(list, u)
        end
    end
    if #list == 0 then
        list[1] = "player"
    end
    return list
end

-- Basic sorting per config (UNSORTED, AZ, ZA, THD, HTD)
local function SortUnits(units, order)
    order = (order or "UNSORTED"):upper()
    if order == "UNSORTED" then
        return units
    end

    local function roleRank(u, pref)
        local r = UnitGroupRolesAssigned(u)
        local mapTHD = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
        local mapHTD = { HEALER = 1, TANK = 2, DAMAGER = 3, NONE = 4 }
        local m = (pref == "THD") and mapTHD or mapHTD
        return m[r or "NONE"] or 4
    end

    local sorted = { unpack(units) }
    if order == "AZ" or order == "ZA" then
        table.sort(sorted, function(a, b)
            local na, nb = UnitName(a) or "", UnitName(b) or ""
            if order == "AZ" then
                return na < nb
            else
                return na > nb
            end
        end)
    elseif order == "THD" or order == "HTD" then
        table.sort(sorted, function(a, b)
            local ra, rb = roleRank(a, order), roleRank(b, order)
            if ra ~= rb then
                return ra < rb
            end
            local na, nb = UnitName(a) or "", UnitName(b) or ""
            return na < nb
        end)
    end
    return sorted
end

-- Lay out frames by orientation & framesPer*
local function Layout(container, frames, party)
    local fw = tonumber(party.frameWidth) or 80
    local fh = tonumber(party.frameHeight) or 18
    local ori = tostring(party.orientation or "HORIZONTAL"):upper()
    local per = (ori == "VERTICAL") and (tonumber(party.framesPerColumn) or 5)
            or (tonumber(party.framesPerRow) or 5)
    if per < 1 then
        per = 1
    end

    local col, row = 1, 1
    local usedCols, usedRows = 0, 0

    for _, f in ipairs(frames) do
        SnapSize(f, fw, fh)
        f:ClearAllPoints()
        SnapPoint(f, "TOPLEFT", container, "TOPLEFT", (col - 1) * fw, -(row - 1) * fh)

        if ori == "HORIZONTAL" then
            usedCols = math.max(usedCols, col);
            usedRows = math.max(usedRows, row)
            col = col + 1;
            if col > per then
                col = 1;
                row = row + 1
            end
        else
            usedCols = math.max(usedCols, col);
            usedRows = math.max(usedRows, row)
            row = row + 1;
            if row > per then
                row = 1;
                col = col + 1
            end
        end
    end

    if #frames == 0 then
        SnapSize(container, fw, fh)
    else
        SnapSize(container, math.max(1, usedCols) * fw, math.max(1, usedRows) * fh)
    end
end

-- Securely assign a unit to a unit button
local function SetUnitSecure(btn, unit)
    if not btn or not unit then return end

    -- If we can’t change secure attributes in combat, defer until after
    if InCombatLockdown() then
        if S.dprintf then S.dprintf("SetUnitSecure deferred for %s -> %s", btn:GetName() or "<?>", tostring(unit)) end
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            SetUnitSecure(btn, unit)
        end)
        return
    end

    -- Store our idea of the unit, then set the secure attribute
    btn.unit = unit

    -- Clear any parent/unitsuffix inheritance (just in case)
    if btn.SetAttribute then
        btn:SetAttribute("useparent-unit", nil)
        btn:SetAttribute("unitsuffix", nil)

        -- Set the actual unit attribute
        btn:SetAttribute("unit", unit)
    end

    -- Make sure click map matches current toggle
    if S.Frames and S.Frames.ApplyClickTargeting then
        S.Frames.ApplyClickTargeting(btn)
    end

    if S.dprintf then
        S.dprintf("  bound %s to %s (attr now %s)",
                btn:GetName() or "<?>", tostring(unit),
                btn.GetAttribute and tostring(btn:GetAttribute("unit")) or "<?>")
    end
end

local function UpdateHealth(btn)
    local u = btn.unit;
    if not u then
        return
    end
    local cur = UnitHealth(u) or 0
    local max = UnitHealthMax(u) or 1
    if btn.Health and btn.Health.SetMinMaxValues then
        btn.Health:SetMinMaxValues(0, max)
        btn.Health:SetValue(cur)
    end
    if S.Frames and S.Frames.Skin and S.Profile then
        local fcfg = (S.Profile and S.Profile.frames) or {}
        if S.Frames.Skin.ApplyHealthColor then
            S.Frames.Skin.ApplyHealthColor(btn, cur, max, fcfg)
        end
    end
end

local function UpdateName(btn)
    local u = btn.unit;
    if not u then
        return
    end
    if btn.NameText then
        local name = UnitName(u) or ""
        local maxLen = (S.Profile and S.Profile.frames and S.Profile.frames.maxNameLength) or 10
        if #name > maxLen then
            name = string.sub(name, 1, maxLen)
        end
        btn.NameText:SetText(name)
    end
end

local function AttachEvents(btn)
    if btn._eventsAttached or not btn.unit then
        return
    end
    btn:RegisterUnitEvent("UNIT_HEALTH", btn.unit)
    btn:RegisterUnitEvent("UNIT_MAXHEALTH", btn.unit)
    btn:RegisterUnitEvent("UNIT_NAME_UPDATE", btn.unit)
    btn:SetScript("OnEvent", function(self, event)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            UpdateHealth(self)
        elseif event == "UNIT_NAME_UPDATE" then
            UpdateName(self)
        end
    end)
    btn._eventsAttached = true
end

local function EnsurePartyContainer()
    if S.dprintf then
        S.dprintf("EnsurePartyContainer")
    end
    if partyContainer and partyContainer:IsObjectType("Frame") then
        return partyContainer
    end
    local c = CreateFrame("Frame", "SunnyFramesPartyContainer", S.root or UIParent, "BackdropTemplate")
    c:SetSize(300, 100)
    c:Show()
    partyContainer = c
    partyContainer:EnableMouse(false)
    partyContainer:EnableMouseWheel(false)
    return c
end

function M.BuildPartySimple()
    if S.dprintf then
        S.dprintf("BuildPartySimple: start")
    end
    local parent = EnsurePartyContainer()
    local units = (S.Frames and S.Frames.Roster and S.Frames.Roster.BuildPartyList and S.Frames.Roster.BuildPartyList()) or { "player" }
    if S.Frames and S.Frames.Factory and S.Frames.Factory.EnsurePool then
        S.Frames.Factory.EnsurePool(parent, #units)
    end

    local buttons = {}
    for i, unit in ipairs(units) do
        local btn = S.Frames.Factory.Acquire(i, parent)
        SetUnitSecure(btn, unit);
        if S.dprintf then
            S.dprintf("  bound #%d to %s", i, unit)
        end
        UpdateName(btn)
        UpdateHealth(btn)
        AttachEvents(btn)
        table.insert(buttons, btn)
    end

    if S.Frames and S.Frames.Factory and S.Frames.Factory.HideUnused then
        S.Frames.Factory.HideUnused(#units + 1)
    end

    if S.Frames and S.Frames.Layout and S.Frames.Layout.Apply then
        local cfg = (S.Profile and S.Profile.frames) or {}
        if S.dprintf then
            S.dprintf("Layout.Apply: %d buttons", #buttons)
        end
        S.Frames.Layout.Apply(parent, buttons, cfg)
    end

    if S.Frames and S.Frames.Layout and S.Frames.Layout.PositionPartyContainer then
        local pcfg = (S.Profile and S.Profile.party) or {}
        if S.dprintf then
            S.dprintf("PositionPartyContainer: anchor=%s, x=%.1f, y=%.1f", tostring(pcfg.layoutAnchor), tonumber(pcfg.xPos or 0), tonumber(pcfg.yPos or 0))
        end
        S.Frames.Layout.PositionPartyContainer(parent, pcfg)
    end

    if S.UI and S.UI.UpdatePartyPositionSliderRanges then
        S.UI.UpdatePartyPositionSliderRanges()
    end
end

local function HideBlizzardPartyFrames(enable)
    if S.dprintf then
        S.dprintf("HideBlizzardPartyFrames: %s", tostring(enable))
    end
    if not enable then
        return
    end
    if InCombatLockdown() then
        if S.CombatQueue and S.CombatQueue.RunOrDefer then
            S.CombatQueue:RunOrDefer("hideblizz", function()
                HideBlizzardPartyFrames(enable)
            end)
        end
        return
    end
    if CompactPartyFrame then
        CompactPartyFrame:UnregisterAllEvents();
        CompactPartyFrame:Hide()
    end
    if CompactRaidFrameManager then
        CompactRaidFrameManager:UnregisterAllEvents();
        CompactRaidFrameManager:Hide()
    end
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer:UnregisterAllEvents();
        CompactRaidFrameContainer:Hide()
    end
end

-- Hook refresh to hide Blizzard frames when enabled
local prevRefresh = Refresh
local function WrappedRefresh()
    local enableHide = S.Profile and S.Profile.general and S.Profile.general.hideBlizzardPartyFrames
    HideBlizzardPartyFrames(enableHide)
    if prevRefresh then
        prevRefresh()
    end
end
Refresh = WrappedRefresh

-- Update on login / roster
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:SetScript("OnEvent", function()
        Refresh()
    end)
end

-- Slash
SLASH_SUNNYFRAMES1 = "/sframes"
SlashCmdList["SUNNYFRAMES"] = function(msg)
    msg = tostring(msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "debug" then
        S.Profile = S.Profile or {}
        S.Profile.general = S.Profile.general or {}
        local new = not S.Profile.general.debug
        S.Profile.general.debug = new
        print("|cffFFD200SunnyFrames|r Debug " .. (new and "ON" or "OFF"))
        return
    end
    Refresh()
end

SLASH_SFMO1 = "/sfmo"
SlashCmdList.SFMO = function()
    if UnitExists("mouseover") then
        local n = UnitName("mouseover")
        print("mouseover unit:", n or "<?>")
    else
        print("no mouseover unit")
    end
end

return M
