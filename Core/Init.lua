local ADDON, S = ...
SunnyFramesDB = SunnyFramesDB or {}

------------------------------------------------------------
-- Defaults (profile-scoped vs global)
------------------------------------------------------------
local PROFILE_DEFAULTS = {
    -- visuals / names
    useClassColors = true,
    nameFontSize   = 12,
    nameAutoFit    = true,
    nameMaxChars   = 20,
    nameAnchor     = "CENTER",
    showHealthPct  = false,
    healthPctMode  = "UNDER",   -- "ABOVE"|"UNDER"|"REPLACE"

    -- bars
    cellWidth   = 90,
    cellHeight  = 18,
    spacing     = 4,
    barFillOrientation = "HORIZONTAL",
    missingHealthMode  = false,

    -- layout
    orientation = "HORIZONTAL",
    perLine     = 5,

    -- resource (power) bar
    resourceMode     = "ALL",
    resourceAnchor   = "INSIDE_BOTTOM",
    resourceSizeMode = "PERCENT", -- "PERCENT"|"PIXELS"
    resourceSizePct  = 10,        -- 1..90
    resourceSizePx   = 3,         -- 1..30
}

local GLOBAL_DEFAULTS = {
    -- runtime / ui / glue
    throttle    = 0.10,
    showPlayer  = true,
    useRaid     = true,
    lockFrame   = false,
    anchorPoint = "TOPLEFT",

    -- position
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },

    -- TEST MODE (global)
    testMode   = false,
    testPreset = "PARTY", -- "PARTY"|"RAID20"|"RAID40"

    -- UI: which profile is being edited in the config window
    uiEditingProfile = "PARTY",

    -- legacy flags
    showHealthText = false,
}

------------------------------------------------------------
-- DB plumbing
------------------------------------------------------------
local function copyInto(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyInto(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function S.DB()
    -- seed globals
    copyInto(SunnyFramesDB, GLOBAL_DEFAULTS)
    -- seed profiles
    SunnyFramesDB.profiles = SunnyFramesDB.profiles or {}
    SunnyFramesDB.profiles.PARTY  = SunnyFramesDB.profiles.PARTY  or {}
    SunnyFramesDB.profiles.RAID20 = SunnyFramesDB.profiles.RAID20 or {}
    SunnyFramesDB.profiles.RAID40 = SunnyFramesDB.profiles.RAID40 or {}
    copyInto(SunnyFramesDB.profiles.PARTY,  PROFILE_DEFAULTS)
    copyInto(SunnyFramesDB.profiles.RAID20, PROFILE_DEFAULTS)
    copyInto(SunnyFramesDB.profiles.RAID40, PROFILE_DEFAULTS)

    -- migrate legacy showHealthPctUnderName
    if SunnyFramesDB.showHealthPctUnderName ~= nil then
        for _, key in ipairs({"PARTY","RAID20","RAID40"}) do
            local p = SunnyFramesDB.profiles[key]
            if SunnyFramesDB.showHealthPctUnderName then
                p.showHealthPct = true
                p.healthPctMode = p.healthPctMode or "UNDER"
            end
        end
        SunnyFramesDB.showHealthPctUnderName = nil
    end

    return SunnyFramesDB
end

------------------------------------------------------------
-- Active/Editing profile logic
------------------------------------------------------------
function S.ActiveProfileKey()
    local db = S.DB()
    if db.testMode then
        local t = db.testPreset or "PARTY"
        if t == "RAID40" then return "RAID40"
        elseif t == "RAID20" then return "RAID20"
        else return "PARTY" end
    end
    local inRaid = IsInRaid()
    if not inRaid then return "PARTY" end
    local n = GetNumGroupMembers() or 0
    if n >= 21 then return "RAID40" end
    return "RAID20"
end

function S.EditingProfileKey()
    local k = S.DB().uiEditingProfile or "PARTY"
    if k ~= "PARTY" and k ~= "RAID20" and k ~= "RAID40" then k = "PARTY" end
    return k
end

function S.SetEditingProfile(key)
    if key ~= "PARTY" and key ~= "RAID20" and key ~= "RAID40" then return end
    S.DB().uiEditingProfile = key
end

function S.P() return S.DB().profiles[S.ActiveProfileKey()] end
function S.PGet(k) return S.P()[k] end
function S.PSet(k, v) S.P()[k] = v end

function S.EP() return S.DB().profiles[S.EditingProfileKey()] end
function S.EGet(k) return S.EP()[k] end
function S.ESet(k, v) S.EP()[k] = v end

------------------------------------------------------------
-- Root frame + position helpers
------------------------------------------------------------
S.root = CreateFrame("Frame", "SunnyFramesRoot", UIParent)
S.root:SetSize(1, 1)

function S.LoadPosition()
    local pos = S.DB().position or GLOBAL_DEFAULTS.position
    local p   = pos.point or "CENTER"
    local rp  = pos.relativePoint or p
    local x   = tonumber(pos.x) or 0
    local y   = tonumber(pos.y) or 0
    S.root:ClearAllPoints()
    S.root:SetPoint(p, UIParent, rp, x, y)
end

function S.SavePosition()
    local p, rel, rp, x, y = S.root:GetPoint()
    S.DB().position = {
        point = p or "CENTER",
        relativePoint = rp or (p or "CENTER"),
        x = tonumber(x) or 0, y = tonumber(y) or 0,
    }
end

function S.ResetPosition()
    S.DB().position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    S.LoadPosition()
    S.SavePosition()
end

------------------------------------------------------------
-- Public apply
------------------------------------------------------------
function S.ApplyConfig()
    if S.ApplyMovableState then S.ApplyMovableState() end
    local units = S.UnitList()
    S.Layout(units)
    S.RefreshAll()
    if S.UpdateAllNameFonts then S.UpdateAllNameFonts() end
end

------------------------------------------------------------
-- Disable Blizzard party/raid frames (Retail)
------------------------------------------------------------
local function SafeHide(f)
    if not f then return end
    if f.UnregisterAllEvents then f:UnregisterAllEvents() end
    f:Hide()
end

function S.DisableDefaultFrames()
    if _G.PartyFrame then SafeHide(_G.PartyFrame) end
    if _G.CompactRaidFrameManager then SafeHide(_G.CompactRaidFrameManager) end
    if _G.CompactRaidFrameContainer then SafeHide(_G.CompactRaidFrameContainer) end
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "showPartyFrames", "0")
        pcall(C_CVar.SetCVar, "useCompactPartyFrames", "0")
    elseif C_Console and C_Console.SetCVar then
        pcall(C_Console.SetCVar, "showPartyFrames", "0")
        pcall(C_Console.SetCVar, "useCompactPartyFrames", "0")
    end
end

------------------------------------------------------------
-- Events & OnUpdate
------------------------------------------------------------
local elapsed = 0
S.time = 0

S.root:SetScript("OnUpdate", function(_, dt)
    S.time = S.time + dt
    elapsed = elapsed + dt
    if elapsed >= (S.DB().throttle or 0.1) then
        elapsed = 0
        S.RefreshAll()
    end
end)

S.root:RegisterEvent("ADDON_LOADED")
S.root:RegisterEvent("GROUP_ROSTER_UPDATE")
S.root:RegisterEvent("PLAYER_ENTERING_WORLD")
S.root:RegisterEvent("UNIT_HEALTH")
S.root:RegisterEvent("UNIT_MAXHEALTH")
S.root:RegisterEvent("UNIT_POWER_UPDATE")
S.root:RegisterEvent("UNIT_DISPLAYPOWER")
S.root:RegisterEvent("UNIT_NAME_UPDATE")
S.root:RegisterEvent("PLAYER_LOGOUT")

S.root:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        S.DB()
        S.LoadPosition()
        S.DisableDefaultFrames()
        if S.EnsureHandle then S.EnsureHandle() end
        S.ApplyConfig()
    elseif event == "PLAYER_ENTERING_WORLD" then
        S.DisableDefaultFrames()
        S.ApplyConfig()
    elseif event == "GROUP_ROSTER_UPDATE" then
        S.ApplyConfig()
    elseif event == "PLAYER_LOGOUT" then
        S.SavePosition()
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
        or event == "UNIT_NAME_UPDATE" or event == "UNIT_POWER_UPDATE"
        or event == "UNIT_DISPLAYPOWER")
        and arg1 and S.cellForUnit and S.cellForUnit[arg1] then
        S.UpdateCell(S.cellForUnit[arg1])
    end
end)

------------------------------------------------------------
-- Slash
------------------------------------------------------------
SLASH_SUNNYFRAMES1 = "/sunnyframes"
SlashCmdList["SUNNYFRAMES"] = function()
    if SunnyFrames_ToggleConfig then SunnyFrames_ToggleConfig() end
end
