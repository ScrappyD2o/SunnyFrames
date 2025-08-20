local ADDON, S = ...
S                 = _G[ADDON] or S or {}
_G[ADDON]         = S
S.DebugOverlay    = S.DebugOverlay or {}

local DO          = S.DebugOverlay
local MAX_LINES   = 12

-- ------------------------------------------------------------
-- Overlay frame
-- ------------------------------------------------------------
local function newOverlay()
    local f = CreateFrame("Frame", "SunnyFramesDebugOverlay", UIParent, "BackdropTemplate")
    f:SetSize(420, 160)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.75)
    f:SetBackdropBorderColor(0.7, 0.7, 0.7, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("SunnyFrames — Debug")

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 10, -28)
    body:SetPoint("BOTTOMRIGHT", -10, 10)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText("…")
    f.body = body

    f:Hide()
    return f
end

local function ensure()
    if not DO._frame then
        DO._frame = newOverlay()
        DO._lines = {}
    end
    return DO._frame
end

local function refresh()
    local f = ensure()
    local text = table.concat(DO._lines or {}, "\n")
    f.body:SetText(text == "" and "…" or text)
end

-- ------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------
function DO.SetEnabled(on)
    local f = ensure()
    if on then f:Show() else f:Hide() end
end

function DO.Toggle()
    local f = ensure()
    if f:IsShown() then f:Hide() else f:Show() end
end

function DO.Log(fmt, ...)
    local f = ensure()
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    local t = date("%H:%M:%S")
    msg = string.format("[%s] %s", t, msg)

    DO._lines = DO._lines or {}
    table.insert(DO._lines, 1, msg)
    if #DO._lines > MAX_LINES then
        for i = #DO._lines, MAX_LINES + 1, -1 do
            table.remove(DO._lines, i)
        end
    end

    if f:IsShown() then refresh() end
end

-- Bind overlay visibility to profile.general.debugOverlay
local function currentFlag()
    local Gen = S.Profile and S.Profile.general
    return Gen and Gen.debugOverlay and true or false
end

function DO.ApplyFromProfile()
    DO.SetEnabled(currentFlag())
    DO.Log("Debug overlay: %s (profile sync)", currentFlag() and "ON" or "OFF")
end

-- Hook profile changes (non-destructive)
do
    local prev = S.NotifyProfileChanged
    S.NotifyProfileChanged = function(section)
        if type(prev) == "function" then pcall(prev, section) end
        if section == "general" then
            DO.ApplyFromProfile()
        end
    end
end

-- Slash to toggle overlay quickly (also updates profile)
SLASH_SUNNYFRAMESDEBUG1 = "/sfdebug"
SlashCmdList.SUNNYFRAMESDEBUG = function()
    local Gen = S.Profile and S.Profile.general
    if not Gen then return end
    Gen.debugOverlay = not not (not Gen.debugOverlay)
    DO.ApplyFromProfile()
end

-- Initialize when variables are loaded
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- Ensure we have the boolean in profile (default: false)
    S.Profile = S.Profile or {}
    S.Profile.general = S.Profile.general or {}
    if S.Profile.general.debugOverlay == nil then
        S.Profile.general.debugOverlay = false
    end
    DO.ApplyFromProfile()
end)
