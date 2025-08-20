local ADDON, S = ...
S         = _G[ADDON] or S or {}
_G[ADDON] = S

local function getFlag()
    local Gen = S.Profile and S.Profile.general
    return Gen and Gen.debugOverlay and true or false
end

local function setFlag(val)
    S.Profile              = S.Profile or {}
    S.Profile.general      = S.Profile.general or {}
    S.Profile.general.debugOverlay = val and true or false

    if S.DebugOverlay and S.DebugOverlay.ApplyFromProfile then
        S.DebugOverlay.ApplyFromProfile()
    end
    if S.NotifyProfileChanged then
        S.NotifyProfileChanged("general")
    end
end

local function createPanel()
    local panel = CreateFrame("Frame", "SunnyFrames_General_Debug_Panel", UIParent, "BackdropTemplate")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ADDON .. " — General")

    local cb = CreateFrame("CheckButton", "SunnyFrames_DebugOverlay_Check", panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    cb.Text:SetText("Debug Overlay")
    cb.tooltipText = "Show a small on-screen panel with recent SunnyFrames debug messages (helpful for troubleshooting)."

    cb:SetScript("OnClick", function(self)
        setFlag(self:GetChecked())
    end)

    panel:SetScript("OnShow", function()
        cb:SetChecked(getFlag())
    end)

    return panel
end

local function registerRetailSettings(panel)
    local parentCategory = S.UI and S.UI.Category
    if parentCategory and Settings and Settings.RegisterCanvasLayoutSubcategory then
        local sub = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, "General")
        Settings.RegisterAddOnCategory(sub)
        S.UI.GeneralCategory = sub
        return true
    end

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, ADDON .. " - General")
        Settings.RegisterAddOnCategory(cat)
        S.UI = S.UI or {}
        S.UI.Category = S.UI.Category or cat
        return true
    end

    return false
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    S.Profile = S.Profile or {}
    S.Profile.general = S.Profile.general or {}
    if S.Profile.general.debugOverlay == nil then
        S.Profile.general.debugOverlay = false
    end

    local panel = createPanel()
    registerRetailSettings(panel)
end)
