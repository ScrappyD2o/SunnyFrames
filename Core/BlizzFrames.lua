-- Core/BlizzFrames.lua (hard-disable style like Cell/Grid2)
local ADDON, S = ...
S                   = _G[ADDON] or S or {}
_G[ADDON]           = S
S.BlizzFrames       = S.BlizzFrames or {}
local BF            = S.BlizzFrames

-- ============================================================
-- Hidden parent (sink)
-- ============================================================
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:SetAllPoints()
hiddenParent:Hide()

-- Utility: run when out of combat
local function outOfCombat(fn)
    if InCombatLockdown and InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            fn()
        end)
    else
        fn()
    end
end

-- Small helper to blindly unregister a frame (child) if it exists
local function Unreg(f) if f and f.UnregisterAllEvents then f:UnregisterAllEvents() end end

-- Aggressive hide for a classic Blizzard unit frame (like PartyMemberFrame)
local function HideUnitFrame(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:Hide()
    frame:SetParent(hiddenParent)

    -- Sub-bars / children (names vary by era)
    local health = frame.healthBar or frame.healthbar or frame.HealthBar
    if health then Unreg(health) end

    local power  = frame.manabar or frame.ManaBar
    if power then Unreg(power) end

    local spell  = frame.castBar or frame.spellbar or frame.CastBar
    if spell then Unreg(spell) end

    local alt    = frame.powerBarAlt or frame.AlternatePowerBar
    if alt then Unreg(alt) end

    local buffFrame = frame.BuffFrame
    if buffFrame then Unreg(buffFrame) end

    local petFrame = frame.PetFrame
    if petFrame then Unreg(petFrame) end
end

-- ============================================================
-- HARD DISABLE: PARTY
-- ============================================================
local function HardDisablePartyFrames()
    -- Compact party frame tries to re-show on roster updates
    if UIParent.UnregisterEvent then
        UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end

    -- Dragonflight/Retail PartyFrame + pooled members
    local pf = _G.PartyFrame
    if pf then
        pf:UnregisterAllEvents()
        pf:SetScript("OnShow", nil)
        -- Hide all active pooled member frames
        local pool = pf.PartyMemberFramePool
        if pool and pool.EnumerateActive then
            for frame in pool:EnumerateActive() do
                HideUnitFrame(frame)
            end
            -- Some addons: pool:ReleaseAll() — not strictly needed; we just sink them.
        end
        HideUnitFrame(pf)
    else
        -- Old style frames (pre-DF)
        for i = 1, 4 do
            HideUnitFrame(_G["PartyMemberFrame"..i])
            HideUnitFrame(_G["CompactPartyMemberFrame"..i])
        end
        HideUnitFrame(_G.PartyMemberBackground)
    end

    -- CompactPartyFrame (raid-style party)
    if _G.CompactPartyFrame then
        _G.CompactPartyFrame:UnregisterAllEvents()
        HideUnitFrame(_G.CompactPartyFrame)
    end
end

-- ============================================================
-- HARD DISABLE: RAID (Compact Raid Frames)
-- ============================================================
local function HardDisableRaidFrames()
    -- Compact frames love GROUP_ROSTER_UPDATE; cut it at the root (Cell/Grid2 do this)
    if UIParent.UnregisterEvent then
        UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end

    -- Load CRF addon if present on this client
    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_CompactRaidFrames")
    end

    local mgr = _G.CompactRaidFrameManager
    local con = _G.CompactRaidFrameContainer

    -- Stop the container from being re-shown
    if con then
        con:UnregisterAllEvents()
        -- Hide immediately
        con:Hide()
        con:SetParent(hiddenParent)
        -- Force-hide on attempts to show/set-shown
        hooksecurefunc(con, "Show", con.Hide)
        hooksecurefunc(con, "SetShown", function(frame, shown)
            if shown then frame:Hide() end
        end)
    end

    -- Force the manager off and stop it from reappearing
    if _G.CompactRaidFrameManager_SetSetting then
        _G.CompactRaidFrameManager_SetSetting("IsShown", "0")
    end

    if mgr then
        mgr:UnregisterAllEvents()
        mgr:SetParent(hiddenParent)
        mgr:Hide()
        -- Some UIs also hook update functions; hiding + sinking is enough here.
    end
end

-- ============================================================
-- PUBLIC: apply based on profile
-- ============================================================
local function wantHideParty()
    local Gen = (S.Profile and S.Profile.general) or {}
    return Gen.hideBlizzardPartyFrames and true or false
end
local function wantHideRaid()
    local Gen = (S.Profile and S.Profile.general) or {}
    return Gen.hideBlizzardRaidFrames and true or false
end

function S.BlizzFrames.ApplyFromProfile()
    outOfCombat(function()
        if wantHideParty() then HardDisablePartyFrames() end
        if wantHideRaid()  then HardDisableRaidFrames()  end
        if S.dprintf then
            S.dprintf("BlizzFrames(hard): hideParty=%s hideRaid=%s", tostring(wantHideParty()), tostring(wantHideRaid()))
        end
    end)
end

-- ============================================================
-- Driver (re-apply our wishes on safe lifecycle events)
-- Note: we NEVER force-show, so unchecking typically requires a /reload to restore stock frames.
-- ============================================================
local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("GROUP_ROSTER_UPDATE")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:SetScript("OnEvent", function()
    S.BlizzFrames.ApplyFromProfile()
end)

-- React to your checkboxes (non-destructive wrapper)
do
    local prev = S.NotifyProfileChanged
    S.NotifyProfileChanged = function(section)
        if type(prev) == "function" then pcall(prev, section) end
        if section == "general" or section == "party" or section == "raid" then
            S.BlizzFrames.ApplyFromProfile()
        end
    end
end
