local ADDON, S = ...
S.UI = S.UI or {}
local U = S.UI

local function C(name)
    local c = S.UIColors and S.UIColors[name]
    if not c then return 1,0,1,1 end
    return c[1], c[2], c[3], c[4]
end

-- Main panel
local panel = CreateFrame("Frame", "SunnyFramesConfigUI", UIParent, "BackdropTemplate")
panel:SetFrameStrata("FULLSCREEN_DIALOG")
panel:SetToplevel(true)
panel:SetFrameLevel(1000)
panel:SetClampedToScreen(true)
panel:SetSize(900, 620)
panel:SetPoint("CENTER")
panel:Hide()

panel:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
panel:SetBackdropColor(C("background"))
panel:SetBackdropBorderColor(C("border"))

panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetMovable(true)
panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
panel:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
close:SetFrameLevel(panel:GetFrameLevel() + 2)

-- Header
local header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
header:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
header:SetHeight(44)
header:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
header:SetBackdropColor(C("panelAlt"))
header:SetBackdropBorderColor(C("border"))

local accent = header:CreateTexture(nil, "ARTWORK")
accent:SetColorTexture(C("accent"))
accent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -1)
accent:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -1)
accent:SetHeight(2)

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("LEFT", header, "LEFT", 12, -1)
title:SetText("SunnyFrames Configuration")

panel:SetScript("OnShow", function(self)
    local w = math.floor(UIParent:GetWidth()  * 0.5)
    local h = math.floor(UIParent:GetHeight() * 0.5)
    self:SetSize(math.max(700, w), math.max(520, h))
end)

-- Body split
local body = CreateFrame("Frame", nil, panel, "BackdropTemplate")
body:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -52)
body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
body:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
body:SetBackdropColor(C("panel"))
body:SetBackdropBorderColor(C("border"))

local left = CreateFrame("Frame", nil, body, "BackdropTemplate")
left:SetPoint("TOPLEFT", body, "TOPLEFT", 1, -1)
left:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 1, 1)
left:SetWidth(220)
left:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
left:SetBackdropColor(C("panelAlt"))
left:SetBackdropBorderColor(C("border"))

local right = CreateFrame("Frame", nil, body, "BackdropTemplate")
right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
right:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -1, 1)
right:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
right:SetBackdropColor(C("background"))
right:SetBackdropBorderColor(C("border"))

-- Scroll area
local function CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 4)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local sb = self.ScrollBar or _G[self:GetName() and (self:GetName().."ScrollBar") or ""]
        if not sb then return end
        local step = 40
        sb:SetValue(sb:GetValue() - delta * step)
    end)
    return scroll, content
end

local scroll, content = CreateScrollArea(right)

-- Keep visible page width in sync with right pane
right:SetScript("OnSizeChanged", function()
    for _, p in pairs(SunnyFramesConfigUI._pages or {}) do
        if p and p:IsShown() then p:SetWidth(right:GetWidth() - 16) end
    end
end)

-- Left tabs (stylized)
local tabs = {
    { key = "general",    text = "General" },
    { key = "appearance", text = "Appearance" },
    { key = "names",      text = "Names" },
    { key = "bars",       text = "Bars" },
    { key = "layout",     text = "Layout" },
    { key = "partyraid",  text = "Party/Raid" },
    { key = "temp",       text = "Temp" },
}

local nav = CreateFrame("Frame", nil, left)
nav:SetPoint("TOPLEFT", 8, -8)
nav:SetPoint("BOTTOMRIGHT", -8, 8)
nav.buttons = {}
nav.selectedKey = nil

local function SetTabStyle(btn, state)
    if state == "selected" then
        btn.bg:SetColorTexture(C("navSelBG"))
        btn.leftBar:SetColorTexture(C("accent"))
        btn.leftBar:Show()
        btn.text:SetTextColor(C("textSelected"))
    elseif state == "hover" then
        btn.bg:SetColorTexture(C("navHoverBG"))
        btn.leftBar:SetColorTexture(C("accentHover"))
        btn.leftBar:Show()
        btn.text:SetTextColor(C("textHover"))
    else
        btn.bg:SetColorTexture(C("navIdleBG"))
        btn.leftBar:Hide()
        btn.text:SetTextColor(C("textNormal"))
    end
end

local function NewNavItem(parent, label)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetHeight(28); f:SetPoint("LEFT"); f:SetPoint("RIGHT")
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(true); f.bg = bg
    local bar = f:CreateTexture(nil, "ARTWORK");  bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); bar:SetWidth(3); f.leftBar = bar
    local border = f:CreateTexture(nil, "BORDER"); border:SetColorTexture(C("border")); border:SetPoint("TOPLEFT"); border:SetPoint("BOTTOMRIGHT"); border:SetDrawLayer("BORDER", 1); border:SetAlpha(0.8)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); text:SetPoint("LEFT", 10, 0); text:SetJustifyH("LEFT"); text:SetText(label); f.text = text
    f:SetScript("OnEnter", function(self) if nav.selectedKey ~= self._key then SetTabStyle(self, "hover") end end)
    f:SetScript("OnLeave", function(self) if nav.selectedKey ~= self._key then SetTabStyle(self, "idle") end end)
    return f
end

-- Build pages on click via per-tab builder files
panel._pages = {}

local y = -2
for _, it in ipairs(tabs) do
    local b = NewNavItem(nav, it.text)
    b:SetPoint("TOPLEFT", 0, y); y = y - 30
    b._key = it.key
    nav.buttons[it.key] = b

    b:SetScript("OnClick", function(self)
        nav.selectedKey = self._key
        for k, btn in pairs(nav.buttons) do SetTabStyle(btn, k == self._key and "selected" or "idle") end

        for _, f in pairs(panel._pages) do f:Hide() end
        local page = panel._pages[self._key]
        if not page then
            page = CreateFrame("Frame", nil, content)
            page:SetSize(1, 1)
            page:SetWidth(right:GetWidth() - 16)  -- ensure real width for layouts
            panel._pages[self._key] = page
            -- Delegate to tab builders
            if self._key == "general"    and U.Build_General    then U.Build_General(page)
            elseif self._key == "appearance" and U.Build_Appearance then U.Build_Appearance(page)
            else
                U.Build_Placeholder(page, self._key)
            end
        end
        page:Show()
        scroll:SetScrollChild(page)
        scroll:SetVerticalScroll(0)
    end)

    SetTabStyle(b, "idle")
end

-- Public toggle
local refreshers = {}
U.RequestRefresh = function()
    if not panel:IsShown() then return end
    for _, fn in ipairs(refreshers) do if type(fn) == "function" then fn() end end
end

function SunnyFrames_ToggleConfig()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
        local firstKey = tabs[1].key
        if nav and nav.buttons and nav.buttons[firstKey] then
            nav.buttons[firstKey]:Click()
        end
    end
end
