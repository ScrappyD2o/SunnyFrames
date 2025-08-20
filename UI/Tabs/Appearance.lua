local ADDON, S = ...
local U = S.UI
local function C(name) local c=S.UIColors[name]; if not c then return 1,0,1,1 end return c[1],c[2],c[3],c[4] end

-- ============================================================
-- Layout constants (uniform look)
-- ============================================================
local LEFT_PAD  = 16
local RIGHT_PAD = 16
local GAP       = 32
local MAX_FULL  = 140
local MAX_HALF  = 140
local TEXT_PAD  = 30

-- ============================================================
-- Main builder for the "Appearance" vertical tab
-- ============================================================
function U.Build_Appearance(page)
    local function StyleTopTab(btn, state)
        if state == "selected" then
            btn.bg:SetColorTexture(C("navSelBG")); btn.underline:SetColorTexture(C("accent")); btn.underline:Show()
            btn.text:SetTextColor(C("textSelected"))
        elseif state == "hover" then
            btn.bg:SetColorTexture(C("navHoverBG")); btn.underline:Hide(); btn.text:SetTextColor(C("textHover"))
        else
            btn.bg:SetColorTexture(C("navIdleBG")); btn.underline:Hide(); btn.text:SetTextColor(C("textNormal"))
        end
    end
    local function NewTopTabButton(parent, label)
        local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(160, 28)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(true)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b.text:SetPoint("CENTER"); b.text:SetText(label)
        b.underline = b:CreateTexture(nil, "ARTWORK")
        PixelUtil.SetPoint(b.underline, "BOTTOMLEFT",  b, "BOTTOMLEFT",  2, 0)
        PixelUtil.SetPoint(b.underline, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 0)
        PixelUtil.SetHeight(b.underline, 1); b.underline:Hide()
        b:SetScript("OnEnter", function(self) if page._sel ~= self then StyleTopTab(self, "hover") end end)
        b:SetScript("OnLeave", function(self) if page._sel ~= self then StyleTopTab(self, "idle") end end)
        StyleTopTab(b, "idle")
        return b
    end

    local top = CreateFrame("Frame", nil, page, "BackdropTemplate")
    top:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -8)
    top:SetPoint("TOPRIGHT", page, "TOPRIGHT", -8, -8)
    top:SetHeight(34)
    top:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
    top:SetBackdropColor(C("panelAlt"))
    top:SetBackdropBorderColor(C("border"))

    local tabParty  = NewTopTabButton(top, "Party")
    local tabR20    = NewTopTabButton(top, "Raid 20")
    local tabR40    = NewTopTabButton(top, "Raid 40")
    local tabFrames = NewTopTabButton(top, "Frames")
    tabParty:SetPoint("LEFT", top, "LEFT", 6, 0)
    tabR20:SetPoint("LEFT", tabParty, "RIGHT", 6, 0)
    tabR40:SetPoint("LEFT", tabR20, "RIGHT", 6, 0)
    tabFrames:SetPoint("LEFT", tabR40, "RIGHT", 6, 0)

    local sub = CreateFrame("Frame", nil, page, "BackdropTemplate")
    sub:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -8)
    sub:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, -8)
    sub:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    sub:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
    sub:SetBackdropColor(C("background"))
    sub:SetBackdropBorderColor(C("border"))

    local pages = {}
    local function EnsureSub(key)
        if pages[key] then return pages[key] end
        local f = CreateFrame("Frame", nil, sub); f:SetAllPoints(sub); f:Hide()
        if key == "PARTY" then U.BuildAppearancePartySub(f) end
        if key == "FRAMES" then U.BuildAppearanceFramesSub(f) end
        pages[key] = f
        return f
    end

    local function ShowSub(btn, key)
        for _, b in ipairs({tabParty, tabR20, tabR40, tabFrames}) do
            if b == btn then
                page._sel = b; b.bg:SetColorTexture(C("navSelBG")); b.underline:SetColorTexture(C("accent")); b.underline:Show()
                b.text:SetTextColor(C("textSelected"))
            else
                b.bg:SetColorTexture(C("navIdleBG")); b.underline:Hide(); b.text:SetTextColor(C("textNormal"))
            end
        end
        for _, p in pairs(pages) do p:Hide() end
        EnsureSub(key):Show()
    end

    tabParty:SetScript("OnClick",  function() ShowSub(tabParty,  "PARTY")  end)
    tabR20:SetScript("OnClick",    function() ShowSub(tabR20,    "RAID20") end)
    tabR40:SetScript("OnClick",    function() ShowSub(tabR40,    "RAID40") end)
    tabFrames:SetScript("OnClick", function() ShowSub(tabFrames, "FRAMES") end)

    ShowSub(tabParty, "PARTY")
    page:SetHeight(1100)
end
