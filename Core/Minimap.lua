local ADDON, S = ...
S                = _G[ADDON] or S or {}
_G[ADDON]        = S
S.Minimap         = S.Minimap or {}

-- ===========================================================================
-- Saved Variables (USE EXISTING)
--   - Account:       SunnyFramesDB
--   - Per-character: SunnyFramesDBChar
-- We store minimap data at SunnyFramesDBChar.minimap
--   { minimapPos = number (deg), hide = boolean }
-- ===========================================================================
_G.SunnyFramesDB     = _G.SunnyFramesDB     or {}
_G.SunnyFramesDBChar = _G.SunnyFramesDBChar or {}

local function EnsureDB()
    local C = _G.SunnyFramesDBChar
    C.minimap = C.minimap or {}            -- DO NOT clobber if present
    local DB = C.minimap
    if DB.minimapPos == nil then DB.minimapPos = 210 end
    if DB.hide       == nil then DB.hide       = false end
    return DB
end

local DB = EnsureDB()

-- ---------------------------------------------------------------------------
-- Profile helper
-- ---------------------------------------------------------------------------
local function WantShownFromProfile()
    local Gen = S.Profile and S.Profile.general
    if Gen and Gen.showMinimapIcon ~= nil then
        return Gen.showMinimapIcon and true or false
    end
    -- Fall back to DB.hide when profile key is absent
    return not DB.hide
end

-- ---------------------------------------------------------------------------
-- UI helpers
-- ---------------------------------------------------------------------------
local function OpenOptions()
    if type(_G.SunnyFrames_ToggleConfig) == "function" then
        _G.SunnyFrames_ToggleConfig()
        return
    end
    if _G.Settings and _G.Settings.OpenToCategory and S.UI and S.UI.CategoryID then
        _G.Settings.OpenToCategory(S.UI.CategoryID); return
    end
    if _G.InterfaceOptionsFrame_OpenToCategory and S.UI and S.UI.CategoryFrame then
        _G.InterfaceOptionsFrame_OpenToCategory(S.UI.CategoryFrame)
        _G.InterfaceOptionsFrame_OpenToCategory(S.UI.CategoryFrame)
        return
    end
    print("|cffffd200SunnyFrames:|r open the options from the AddOns menu.")
end

local function Tooltip(tt)
    if not tt or not tt.AddLine then return end
    tt:AddLine("SunnyFrames", 1,1,1)
    tt:AddLine("Click to open options", 0.9,0.9,0.9)
end

-- ---------------------------------------------------------------------------
-- LDB / DBIcon (preferred if available)
-- ---------------------------------------------------------------------------
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDI = LibStub and LibStub("LibDBIcon-1.0", true)
local dataObj

-- ---------------------------------------------------------------------------
-- Fallback native minimap button
-- ---------------------------------------------------------------------------
local FallbackBtn

local function Fallback_UpdatePosition(angle)
    if not FallbackBtn or not Minimap then return end
    local rad = math.rad(angle or 0)
    local x   = 80 * math.cos(rad)
    local y   = 80 * math.sin(rad)
    FallbackBtn:ClearAllPoints()
    FallbackBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function Fallback_Create()
    if FallbackBtn or not Minimap then return end
    local b = CreateFrame("Button", "SunnyFrames_MinimapButton", Minimap)
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    b:SetHighlightTexture(136477) -- highlight ring
    b:RegisterForClicks("AnyUp")

    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(136430) -- tracking border
    overlay:SetSize(54,54)
    overlay:SetPoint("TOPLEFT")

    local icon = b:CreateTexture(nil, "ARTWORK")
    local ICON_PATH = "Interface\\AddOns\\"..ADDON.."\\Media\\icon"
    icon:SetTexture(ICON_PATH)
    icon:SetMask(136430)
    icon:SetSize(18,18)
    icon:SetPoint("CENTER", -1, 0)
    b.icon = icon

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        Tooltip(GameTooltip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Drag: update DB.minimapPos continuously so it persists across reloads
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            cx, cy       = cx/scale, cy/scale
            local ang    = math.deg(math.atan2(cy - my, cx - mx))
            DB.minimapPos = (ang + 360) % 360
            Fallback_UpdatePosition(DB.minimapPos)
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        -- DB.minimapPos already updated during drag.
    end)

    -- Any click opens options
    b:SetScript("OnClick", function() OpenOptions() end)

    -- Make sure we apply saved position when the button first shows
    b:SetScript("OnShow", function() Fallback_UpdatePosition(DB.minimapPos or 210) end)

    FallbackBtn = b
    Fallback_UpdatePosition(DB.minimapPos or 210)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
function S.Minimap.SetShown(shown)
    shown = shown and true or false
    DB.hide = not shown
    if LDI then
        if shown then LDI:Show(ADDON) else LDI:Hide(ADDON) end
    else
        if not FallbackBtn then Fallback_Create() end
        if shown then FallbackBtn:Show() else FallbackBtn:Hide() end
    end
end

function S.Minimap.UpdateVisibility()
    local want = WantShownFromProfile()
    DB.hide = not want                       -- keep DB in sync so it saves
    S.Minimap.SetShown(want)
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
local function InitWithLibs()
    if not LDB then return false end
    dataObj = LDB:NewDataObject(ADDON, {
        type = "launcher",
        icon = "Interface\\AddOns\\"..ADDON.."\\Media\\icon",
        OnClick = function() OpenOptions() end,
        OnTooltipShow = Tooltip,
        label = "SunnyFrames",
        text  = "SunnyFrames",
    })

    if LDI and dataObj then
        -- Use our per-character DB table; LibDBIcon will read/write
        -- DB.minimapPos and DB.hide for position and visibility.
        LDI:Register(ADDON, dataObj, DB)

        -- Apply state after registration so it uses the saved values.
        if DB.hide then
            LDI:Hide(ADDON)
        else
            LDI:Show(ADDON)
        end
        -- Some LDI versions expose :Refresh(name) to force re-apply.
        if LDI.Refresh then pcall(LDI.Refresh, LDI, ADDON) end

        return true
    end
    return false
end

local function InitFallback()
    Fallback_Create()
    S.Minimap.UpdateVisibility()
end

local f = CreateFrame("Frame")
-- VARIABLES_LOADED guarantees SavedVariables are available.
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
    DB = EnsureDB()  -- rebind in case other code initialized SVs later
    if not InitWithLibs() then
        InitFallback()
    end
end)

-- React to profile changes (general.showMinimapIcon)
do
    local prev = S.NotifyProfileChanged
    S.NotifyProfileChanged = function(section)
        if type(prev) == "function" then pcall(prev, section) end
        if section == "general" then
            S.Minimap.UpdateVisibility()
        end
    end
end
