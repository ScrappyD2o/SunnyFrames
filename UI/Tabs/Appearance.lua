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
-- Color swatch helper (Retail+Classic, above our panel)
-- ============================================================
local function MakeColorPicker(parent, label, getter, setter, x, y, extraPad)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(label)

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetPoint("TOPLEFT", x, y - 18)
    btn:SetSize(28, 18)
    btn:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
    btn:SetBackdropBorderColor(C("border"))
    local swatch = btn:CreateTexture(nil, "ARTWORK"); swatch:SetAllPoints(btn)

    local function getRGBA()
        local r,g,b,a = 1,1,1,1
        if getter then
            local R,G,B,A = getter()
            if R then r=R end; if G then g=G end; if B then b=B end; if A ~= nil then a=A end
        end
        return r,g,b,a
    end
    local function applyRGBA(r,g,b,a)
        swatch:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
        if setter then setter(r or 1, g or 1, b or 1, a or 1) end
    end
    do local r,g,b,a = getRGBA(); swatch:SetColorTexture(r,g,b,a) end

    local function BringPickerToFront()
        local top = _G.SunnyFramesConfigUI
        ColorPickerFrame:SetParent(UIParent)
        ColorPickerFrame:SetToplevel(true)
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        local base = (top and top:GetFrameLevel()) or 1000
        ColorPickerFrame:SetFrameLevel(math.min(65535, base + 50))
        ColorPickerFrame:Raise()
    end

    local function OpenPicker()
        local r,g,b,a = getRGBA()
        local opacity = 1 - (a or 1)
        BringPickerToFront()
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            local info = {
                r=r,g=g,b=b, hasOpacity=true, opacity=opacity,
                previousValues={r,g,b,opacity},
                swatchFunc=function()
                    local nr,ng,nb = ColorPickerFrame:GetColorRGB()
                    local na = 1 - (ColorPickerFrame.opacity or 0)
                    applyRGBA(nr,ng,nb,na)
                end,
                opacityFunc=function()
                    local nr,ng,nb = ColorPickerFrame:GetColorRGB()
                    local na = 1 - (ColorPickerFrame.opacity or 0)
                    applyRGBA(nr,ng,nb,na)
                end,
                cancelFunc=function(prev)
                    local pr,pg,pb,po = unpack(prev)
                    local pa = 1 - (po or 0)
                    applyRGBA(pr,pg,pb,pa)
                end,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            local info = {
                hasOpacity=true, opacity=opacity, previousValues={r,g,b,opacity},
                swatchFunc=function()
                    local nr,ng,nb = ColorPickerFrame:GetColorRGB()
                    local na = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
                    applyRGBA(nr,ng,nb,na)
                end,
                opacityFunc=function()
                    local nr,ng,nb = ColorPickerFrame:GetColorRGB()
                    local na = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
                    applyRGBA(nr,ng,nb,na)
                end,
                cancelFunc=function(prev)
                    local pr,pg,pb,po = unpack(prev)
                    local pa = 1 - (po or 0)
                    applyRGBA(pr,pg,pb,pa)
                end,
            }
            BringPickerToFront()
            OpenColorPicker(info)
        end
    end
    btn:SetScript("OnClick", OpenPicker)

    local ctrl = { button=btn, label=fs, swatch=swatch }
    function ctrl:SetEnabled(enabled)
        if enabled then btn:Enable(); btn:SetAlpha(1); fs:SetFontObject(GameFontNormal)
        else btn:Disable(); btn:SetAlpha(0.4); fs:SetFontObject(GameFontDisable) end
    end

    return ctrl, y - (U.DROPDOWN_BLOCK_H + (extraPad or 0))
end

-- ============================================================
-- Helpers
-- ============================================================
local function SetShown(widget, show) if widget then if show then widget:Show() else widget:Hide() end end end

-- Compute widths/positions for a group:
-- returns fullW, halfW, xLeft, xRightStart (right control starts at column center)
local function CalcWidths(box)
    local boxW = box:GetWidth()
    if not boxW or boxW <= 0 then boxW = 400 end  -- conservative fallback
    local usable = math.max(2*MAX_HALF + GAP, boxW - LEFT_PAD - RIGHT_PAD)

    -- Half width (cap), with a central gutter GAP
    local halfW = math.min(MAX_HALF, math.floor((usable - GAP) / 2))

    -- Full width (cap)
    local fullW = math.min(MAX_FULL, usable)

    -- Left control starts at LEFT_PAD
    local xLeft = LEFT_PAD

    -- Right control starts at the column center + half the gap
    -- (so the gap straddles the center line)
    local xRight = math.floor(usable/2)

    return fullW, halfW, xLeft, xRight
end

-- ============================================================
-- Shared sub-page builder (Party / Raid20 / Raid40)
-- ============================================================
local function Build_ProfileLayoutPage(parent, profileKey)
    -- profileKey: "PARTY" | "RAID20" | "RAID40"
    local state = { orientation = "HORIZONTAL", combine = true }

    -- Two columns container
    local grid, colL, colR = U.CreateTwoColumnGrid(parent)
    local lastL, lastR

    -- ========== Group: Position & Anchor ==========
    do
        local g, y = U.BeginGroup(colL, "Position & Anchor", lastL)
        local FULL, HALF, xLeft, xRight = CalcWidths(g)

        -- Row 1: window position sliders (side-by-side)
        local s1; s1, _ = U.MakeSlider(g, "Horizontal Position", -500, 500, 1, xLeft,  y, nil, 0, HALF)
        local s2; s2, y = U.MakeSlider(g, "Vertical Position",   -500, 500, 1, xRight, y, nil, 0, HALF)

        -- Row 2: two anchor dropdowns (side-by-side)
        local dd1; dd1, _ = U.MakeDropdown(g, "Layout Anchor", {
        {text="Top Left",value="TOPLEFT"},{text="Top",value="TOP"},{text="Top Right",value="TOPRIGHT"},
        {text="Left",value="LEFT"},{text="Center",value="CENTER"},{text="Right",value="RIGHT"},
        {text="Bottom Left",value="BOTTOMLEFT"},{text="Bottom",value="BOTTOM"},{text="Bottom Right",value="BOTTOMRIGHT"},
    }, function() return "TOPLEFT" end, function(_) end, xLeft,  y, HALF, 8)

        local dd2; dd2, y = U.MakeDropdown(g, "Group Anchor", {
        {text="Top Left",value="TOPLEFT"},{text="Top",value="TOP"},{text="Top Right",value="TOPRIGHT"},
        {text="Left",value="LEFT"},{text="Center",value="CENTER"},{text="Right",value="RIGHT"},
        {text="Bottom Left",value="BOTTOMLEFT"},{text="Bottom",value="BOTTOM"},{text="Bottom Right",value="BOTTOMRIGHT"},
    }, function() return "TOPLEFT" end, function(_) end, xRight, y, HALF, 8)

        -- Row 3: Groups Orientation (full width)
        local dd3; dd3, y = U.MakeDropdown(g, "Groups Orientation", {
        {text="Horizontal", value="HORIZONTAL"},
        {text="Vertical",   value="VERTICAL"},
    }, function() return state.orientation end,
            function(val) state.orientation = val end,
            LEFT_PAD, y, FULL, 10)

        lastL = U.EndGroup(g, y)
    end

    -- ========== Group: Frame Sizing & Layout ==========
    do
        local g, y = U.BeginGroup(colL, "Frame Sizing & Layout", lastL)
        local FULL, HALF, xLeft, xRight = CalcWidths(g)

        local isRaid  = (profileKey ~= "PARTY")
        local raidMax = (profileKey == "RAID40") and 40 or 20
        local nextY   = y

        if not isRaid then
            -- Party: Frames per Row/Column (full width)
            local pr; pr, nextY = U.MakeSlider(g, "Frames per Row/Column", 1, 5, 1,
                LEFT_PAD, nextY, nil, 10, FULL)
        else
            -- Raid: Combine groups + conditional slider
            local fprc, colsrows
            local cbCombine; cbCombine, nextY = U.MakeCheckbox(g, "Combine Groups", LEFT_PAD, nextY, function(checked)
            state.combine = not not checked
            SetShown(fprc,     state.combine)
            SetShown(colsrows, not state.combine)
        end, nil, 6)

            fprc, nextY = U.MakeSlider(g, "Frames per Row/Column", 1, raidMax, 1,
                    LEFT_PAD, nextY, nil, 10, FULL)

            local limit = (profileKey == "RAID40") and 8 or 4
            colsrows, nextY = U.MakeSlider(g, "Columns / Rows", 1, limit, 1,
                    LEFT_PAD, nextY, nil, 10, FULL)

            state.combine = true
            SetShown(fprc, true)
            SetShown(colsrows, false)
        end

        -- Row: Frame Width / Height (side-by-side, right starts at center)
        local sW; sW, _ = U.MakeSlider(g, "Frame Width",  10, 300, 1, xLeft,  nextY, nil, 0, HALF)
        local sH; sH, y = U.MakeSlider(g, "Frame Height", 10, 200, 1, xRight, nextY, nil, 0, HALF)

        lastL = U.EndGroup(g, y)
    end

    -- ========== Group: Sorting & Role Priority ==========
    do
        local g, y = U.BeginGroup(colR, "Sorting & Role Priority", lastR)
        local FULL, HALF, xLeft, xRight = CalcWidths(g)

        local sortDD; sortDD, y = U.MakeDropdown(g, "Sorting Order", {
        {text="Unsorted", value="UNSORTED"},
        {text="A - Z",    value="AZ"},
        {text="Z - A",    value="ZA"},
    }, function() return "UNSORTED" end, function(_) end,
            xLeft, y, FULL, 8)

        if profileKey ~= "PARTY" then
            local cbT; cbT, y = U.MakeCheckbox(g, "Show Tanks Separately",   xLeft, y, function(_) end, nil, 4)
            local cbH; cbH, y = U.MakeCheckbox(g, "Show Healers Separately", xLeft, y, function(_) end, nil, 0)
        end

        lastR = U.EndGroup(g, y)
    end

    -- ========== Group: Visibility & Conditions ==========
    do
        local g, y = U.BeginGroup(colR, "Visibility & Conditions", lastR)
        local FULL, HALF, xLeft, xRight = CalcWidths(g)

        local showOptions = {
            { text="Always",  value="ALWAYS"  },
            { text="Never",   value="NEVER"   },
            { text="Grouped", value="GROUPED" },
            { text="Raid",    value="RAID"    },
        }
        local dd; dd, y = U.MakeDropdown(g, "Show Frames", showOptions,
            function() return "ALWAYS" end, function(_) end,
            xLeft, y, FULL, 8)

        local cb; cb, y = U.MakeCheckbox(g, "Hide in Pet Battles", xLeft, y, function(_) end, nil, 0)

        lastR = U.EndGroup(g, y)
    end

    -- ========== Group: Visuals ==========
    do
        local g, y = U.BeginGroup(colR, "Visuals", lastR)
        local FULL, HALF, xLeft, xRight = CalcWidths(g)

        -- Row 1: toggles (Border / Background) using center-start for the right
        local cbBorder; cbBorder, _ = U.MakeCheckbox(g, "Border",     xLeft,  y, function(_) end, nil, 0)
        local cbBg;     cbBg,     y = U.MakeCheckbox(g, "Background", xRight, y, function(_) end, nil, 0)

        -- Row 2: color pickers aligned under checkbox text starts
        local borderPicker;     borderPicker,     _ = MakeColorPicker(g, "Border Color",
            function() return 0,0,0,1 end,   function(r,g,b,a) end, xLeft  + TEXT_PAD, y, 0)
        local backgroundPicker; backgroundPicker, y = MakeColorPicker(g, "Background Color",
            function() return 0,0,0,0.8 end, function(r,g,b,a) end, xRight + TEXT_PAD, y, 0)

        local function updateBorderEnabled()     borderPicker:SetEnabled(cbBorder:GetChecked() and true or false) end
        local function updateBackgroundEnabled() backgroundPicker:SetEnabled(cbBg:GetChecked() and true or false) end
        cbBorder:HookScript("OnClick", updateBorderEnabled)
        cbBg:HookScript("OnClick",     updateBackgroundEnabled)
        updateBorderEnabled(); updateBackgroundEnabled()

        lastR = U.EndGroup(g, y)
    end

    parent:SetHeight(1100)
end

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
    tabParty:SetPoint("LEFT", top, "LEFT", 6, 0)
    tabR20:SetPoint("LEFT", tabParty, "RIGHT", 6, 0)
    tabR40:SetPoint("LEFT", tabR20, "RIGHT", 6, 0)

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
        Build_ProfileLayoutPage(f, key)
        pages[key] = f
        return f
    end

    local function ShowSub(btn, key)
        for _, b in ipairs({tabParty, tabR20, tabR40}) do
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

    tabParty:SetScript("OnClick", function() ShowSub(tabParty, "PARTY")  end)
    tabR20:SetScript("OnClick",   function() ShowSub(tabR20,   "RAID20") end)
    tabR40:SetScript("OnClick",   function() ShowSub(tabR40,   "RAID40") end)

    ShowSub(tabParty, "PARTY")
    page:SetHeight(1100)
end
