local ADDON, S = ...
SunnyFramesDB = SunnyFramesDB or {}
SunnyFramesDBChar = SunnyFramesDBChar or {}  -- currently unused; fine to keep

local DEFAULT_PROFILE = {
    general = {
        debug = false,
        -- Frame Interaction
        enableClickTargeting = true,
        lockFrames = false,
        handleAnchorPosition = "TOPLEFT",
        -- Visibility & Scale
        showMinimapIcon = true,
        globalFrameScale = 100,
        -- Blizzard frames
        hideBlizzardPartyFrames = true,
        hideBlizzardRaidFrames = true,
        -- Tooltips
        enableTooltips = true,
        hideToolTipsInCombat = true,
        tooltipAnchorPosition = "DEFAULT",
    },

    frames = {
        -- Visuals
        useClassColors = true,
        healthColor = { 1, 0, 0, 1 },
        healthTex = "Interface\\TargetingFrame\\UI-StatusBar",
        healthAwareColor = false,
        healthAwareColorLow = { 0.33, 0, 0, 1 },
        healthAwareColorLowThreshold = 25,
        healthAwareColorMedium = { 0.66, 0, 0, 1 },
        healthAwareColorHighThreshold = 75,
        healthAwareColorHigh = { 1, 0, 0, 1 },
        healthBackgroundColor = { 0.16, 0.16, 0.16, 1 },

        -- Names & Font
        maxNameLength = 10,
        fontSize = 10,
    },

    party = {
        -- Position & Anchor
        xPos = 0,
        yPos = 0,
        orientation = "HORIZONTAL",
        -- Frame Sizing & Layout
        framesPerRow = 5,
        framesPerColumn = 5,
        frameWidth = 25,
        frameHeight = 20,
        frameSpacing = 2,
        frameBorder = 1,
        -- Sorting & Role Priority
        sortingOrder = "UNSORTED",
        -- Visibility & Conditions
        hideInPetBattle = true,
        showPets = false,
    },
}

------------------------------------------------------------
-- Utils
------------------------------------------------------------
local function TClone(src)
    local t = {}
    for k, v in pairs(src) do
        t[k] = (type(v) == "table") and TClone(v) or v
    end
    return t
end

local function TCopyMissing(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            TCopyMissing(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function UnitCharKey()
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then realm = GetRealmName() end
    return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

------------------------------------------------------------
-- DB shape
-- SunnyFramesDB = {
--   version = 1,
--   profiles = {
--     ["Default"]    = <profileTable>,
--     ["Name-Realm"] = <profileTable>,
--   },
--   charToProfile = {
--     ["Name-Realm"] = "Default" or "Name-Realm" or "Other-Char",
--   },
-- }
------------------------------------------------------------
local function EnsureRoot()
    SunnyFramesDB = SunnyFramesDB or {}
    SunnyFramesDB.version       = SunnyFramesDB.version or 1
    SunnyFramesDB.profiles      = SunnyFramesDB.profiles or {}
    SunnyFramesDB.charToProfile = SunnyFramesDB.charToProfile or {}
end

local function EnsureProfileExists(profileName)
    local p = SunnyFramesDB.profiles[profileName]
    if not p then
        p = TClone(DEFAULT_PROFILE)
        SunnyFramesDB.profiles[profileName] = p
    else
        -- Fill any newly added defaults without clobbering user values
        TCopyMissing(p, DEFAULT_PROFILE)
    end
    return p
end

local function ResolveActiveProfileNameForChar(charKey)
    local saved = SunnyFramesDB.charToProfile[charKey]
    if saved and SunnyFramesDB.profiles[saved] then
        return saved
    end
    return "Default"
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
S.Profiles = S.Profiles or {}
local P = S.Profiles

function P.GetActiveProfileName()
    return S.ActiveProfileName or "Default"
end

function P.GetActiveProfileTable()
    return S.Profile
end

function P.ListProfiles()
    local names = {}
    for name in pairs(SunnyFramesDB.profiles or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function P.ProfileExists(name)
    return SunnyFramesDB.profiles and SunnyFramesDB.profiles[name] ~= nil
end

-- Switch this character to use a specific profile (linking, not copying)
function P.SetActiveProfile(profileName, opts)
    if not profileName or profileName == "" then profileName = "Default" end
    EnsureProfileExists(profileName)

    local charKey = UnitCharKey()
    SunnyFramesDB.charToProfile[charKey] = profileName

    S.ActiveProfileName = profileName
    S.Profile = SunnyFramesDB.profiles[profileName]

    -- Notify the rest of the addon to re-apply UI / frames
    if not (opts and opts.silent) then
        if S.OnProfileChanged then pcall(S.OnProfileChanged, profileName) end
        if S.ApplyAll then pcall(S.ApplyAll) end
    end
end

-- Use the account-wide default profile for this character
function P.UseDefaultForThisChar()
    P.SetActiveProfile("Default")
end

-- Use a character-specific profile for *this* character (creates if missing)
function P.UseCharacterProfileForThisChar()
    local charKey = UnitCharKey()
    P.SetActiveProfile(charKey)
end

-- Link this character to some *other* character's profile (if it exists)
function P.UseOtherCharacterProfile(otherCharKey)
    if not SunnyFramesDB.profiles[otherCharKey] then
        return false, "Profile does not exist for: " .. tostring(otherCharKey)
    end
    P.SetActiveProfile(otherCharKey)
    return true
end

-- Copy (clone) src profile into dst profile (overwrites dst)
function P.CopyProfile(srcName, dstName, opts)
    if not srcName or not dstName then return false, "src/dst required" end
    if not SunnyFramesDB.profiles[srcName] then return false, "Source not found" end
    SunnyFramesDB.profiles[dstName] = TClone(SunnyFramesDB.profiles[srcName])
    if opts and opts.makeActive then
        P.SetActiveProfile(dstName, { silent = opts.silent })
    end
    return true
end

-- Delete a profile (protects Default and any profile that others use)
function P.DeleteProfile(name)
    if name == "Default" then return false, "Cannot delete the Default profile" end
    if not SunnyFramesDB.profiles[name] then return false, "Not found" end

    -- Prevent orphaning characters; move them to Default
    for charKey, prof in pairs(SunnyFramesDB.charToProfile) do
        if prof == name then
            SunnyFramesDB.charToProfile[charKey] = "Default"
        end
    end

    SunnyFramesDB.profiles[name] = nil

    -- If the character was using it, swap to Default now
    if (S.ActiveProfileName == name) then
        P.SetActiveProfile("Default")
    end

    return true
end

------------------------------------------------------------
-- Init on ADDON_LOADED
------------------------------------------------------------
local function OnAddonLoaded(_, evt, name)
    if name ~= ADDON then return end

    EnsureRoot()

    -- Ensure the two common profiles exist
    EnsureProfileExists("Default")
    EnsureProfileExists(UnitCharKey()) -- pre-create current char profile

    -- Resolve active profile for this character
    local charKey = UnitCharKey()
    local activeName = ResolveActiveProfileNameForChar(charKey)
    S.ActiveProfileName = activeName
    S.Profile = EnsureProfileExists(activeName)

    if S.dprintf then S.dprintf("DB ready. Active profile: %s", activeName) end

    -- Expose helper
    S.UnitCharKey = UnitCharKey

    if S.OnDBReady then pcall(S.OnDBReady) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoaded)
