local ADDON, S = ...
local U = S.UI

-- Shortcuts for editing the currently selected profile in the UI
local function PGet(k) return S.EGet(k) end
local function PSet(k,v) S.ESet(k,v); S.ApplyConfig() end

function U.BuildTab_Temp(parent, controls)
    local y = -10
    local x = U.COL_X

    -- ===== General (profile) =====
    controls.useClassColors, y = U.MakeCheckbox(parent, "Use Class Colours", x, y, function(v)
        PSet("useClassColors", not not v)
    end, "Colour health bars by class")

    controls.orientationDD, y = U.MakeDropdown(
            parent, "Grid Orientation",
            { {text="Horizontal", value="HORIZONTAL"}, {text="Vertical", value="VERTICAL"} },
            function() return PGet("orientation") or "HORIZONTAL" end,
            function(v) PSet("orientation", v) end,
            x, y, U.DD_WIDTH, 16
    )

    controls.perLine, y = U.MakeSlider(parent, "Frames per line", 1, 5, 1, x, y, function(v)
        PSet("perLine", v)
    end, 16)

    -- ===== Names (profile) =====
    controls.nameAnchorDD, y = U.MakeDropdown(
            parent, "Name Anchor",
            {
                {text="Top", value="TOP"},
                {text="Center", value="CENTER"},
                {text="Bottom", value="BOTTOM"},
            },
            function() return PGet("nameAnchor") or "CENTER" end,
            function(v) PSet("nameAnchor", v) end,
            x, y, U.DD_WIDTH, 12
    )

    controls.showPct, y = U.MakeCheckbox(parent, "Show Health %", x, y, function(v)
        PSet("showHealthPct", not not v)
        if controls.healthPctModeDD then controls.healthPctModeDD:SetShown(PGet("showHealthPct")) end
    end, nil, 6)

    controls.healthPctModeDD, y = U.MakeDropdown(
            parent, "Health % Mode",
            {
                {text="Above Name",  value="ABOVE"},
                {text="Under Name",  value="UNDER"},
                {text="Replace Name",value="REPLACE"},
            },
            function() return PGet("healthPctMode") or "UNDER" end,
            function(v) PSet("healthPctMode", v) end,
            x, y, U.DD_WIDTH, 16
    )

    controls.autoFit, y = U.MakeCheckbox(parent, "Auto fit name font", x, y, function(v)
        PSet("nameAutoFit", not not v)
    end, "Shrink name text to fit width; otherwise keep size and truncate", 16)

    controls.fontSize, y = U.MakeSlider(parent, "Name Font Size (max)", 4, 24, 1, x, y, function(v)
        PSet("nameFontSize", v)
    end, 12)

    controls.maxChars, y = U.MakeSlider(parent, "Max name characters", 4, 36, 1, x, y, function(v)
        PSet("nameMaxChars", v)
    end, 16)

    -- ===== Bars (profile) =====
    controls.barFillDD, y = U.MakeDropdown(
            parent, "Health Bar Fill",
            {
                {text="Horizontal", value="HORIZONTAL"},
                {text="Vertical",   value="VERTICAL"},
            },
            function() return PGet("barFillOrientation") or "HORIZONTAL" end,
            function(v) PSet("barFillOrientation", v) end,
            x, y, U.DD_WIDTH, 12
    )

    controls.missingMode, y = U.MakeCheckbox(parent, "Missing Health Mode", x, y, function(v)
        PSet("missingHealthMode", not not v)
    end, "Bar represents missing health instead of current", 12)

    controls.resourceDD, y = U.MakeDropdown(
            parent, "Resource Bar Mode",
            {
                {text="All",       value="ALL"},
                {text="Mana Only", value="MANA"},
                {text="None",      value="NONE"},
            },
            function() return PGet("resourceMode") or "ALL" end,
            function(v) PSet("resourceMode", v) end,
            x, y, U.DD_WIDTH, 16
    )

    controls.resourceAnchorDD, y = U.MakeDropdown(
            parent, "Resource Anchor",
            {
                {text="Inside Top",    value="INSIDE_TOP"},
                {text="Inside Bottom", value="INSIDE_BOTTOM"},
                {text="Above",         value="ABOVE"},
                {text="Beneath",       value="BELOW"},
            },
            function() return PGet("resourceAnchor") or "INSIDE_BOTTOM" end,
            function(v) PSet("resourceAnchor", v) end,
            x, y, U.DD_WIDTH, 10
    )

    controls.resourceSizeModeDD, y = U.MakeDropdown(
            parent, "Resource Size Mode",
            {
                {text="Percent of Height", value="PERCENT"},
                {text="Exact Pixels",      value="PIXELS"},
            },
            function() return PGet("resourceSizeMode") or "PERCENT" end,
            function(v) PSet("resourceSizeMode", v); if controls.UpdateSizeControl then controls.UpdateSizeControl() end end,
            x, y, U.DD_WIDTH, 10
    )

    controls.resourceSize, y = U.MakeSlider(parent, "Resource Size", 1, 90, 1, x, y, function(v)
        if PGet("resourceSizeMode") == "PIXELS" then
            PSet("resourceSizePx", v)
        else
            PSet("resourceSizePct", v)
        end
    end, 10)

    function controls.UpdateSizeControl()
        local mode = PGet("resourceSizeMode") or "PERCENT"
        if mode == "PIXELS" then
            controls.resourceSize.title:SetText("Resource Size (pixels)")
            controls.resourceSize:SetMinMaxValues(1, 30)
            local val = tonumber(PGet("resourceSizePx")) or 3
            controls.resourceSize:SetValue(val)
            controls.resourceSize.value:SetText(tostring(val))
        else
            controls.resourceSize.title:SetText("Resource Size (% of height)")
            controls.resourceSize:SetMinMaxValues(1, 90)
            local val = tonumber(PGet("resourceSizePct")) or 10
            controls.resourceSize:SetValue(val)
            controls.resourceSize.value:SetText(tostring(val))
        end
    end

    -- ===== Layout (profile) =====
    controls.width, y = U.MakeSlider(parent, "Cell Width", 10, 300, 1, x, y, function(v)
        PSet("cellWidth", v)
    end, 12)

    controls.height, y = U.MakeSlider(parent, "Cell Height", 10, 100, 1, x, y, function(v)
        PSet("cellHeight", v)
    end, 12)

    controls.spacing, y = U.MakeSlider(parent, "Cell Spacing", 0, 50, 1, x, y, function(v)
        PSet("spacing", v)
    end, 16)

    -- ===== Global controls =====
    controls.lockFrame, y = U.MakeCheckbox(parent, "Lock Frame (global)", x, y, function(v)
        S.DB().lockFrame = not not v; S.ApplyConfig()
    end, "Disable dragging; use the handle to open options", 6)

    controls.testMode, y = U.MakeCheckbox(parent, "Enable Test Mode (global)", x, y, function(v)
        S.DB().testMode = not not v; S.ApplyConfig()
        if controls.testPresetDD then U.SetDropdownEnabled(controls.testPresetDD, S.DB().testMode) end
    end, "Show simulated units so you can configure without grouping", 6)

    controls.testPresetDD, y = U.MakeDropdown(
            parent, "Test Size (global)",
            {
                {text="Party",   value="PARTY"},
                {text="Raid 20", value="RAID20"},
                {text="Raid 40", value="RAID40"},
            },
            function() return S.DB().testPreset or "PARTY" end,
            function(v) S.DB().testPreset = v; S.ApplyConfig() end,
            x, y, U.DD_WIDTH, 16
    )

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(140, 22)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetText("Reset Position")
    btn:SetScript("OnClick", function()
        if S.ResetPosition then S.ResetPosition() end
    end)
    controls.resetPos = btn
    y = y - (22 + 12)

    -- Refresher to sync UI to DB
    return function()
        local ep = S.EP()

        -- General
        controls.useClassColors:SetChecked(ep.useClassColors ~= false)
        controls.orientationDD:Rebuild()
        controls.perLine:SetValue(ep.perLine or 5); controls.perLine.value:SetText(ep.perLine or 5)

        -- Names
        controls.nameAnchorDD:Rebuild()
        controls.showPct:SetChecked(ep.showHealthPct and true or false)
        controls.healthPctModeDD:Rebuild()
        controls.healthPctModeDD:SetShown(ep.showHealthPct and true or false)
        controls.autoFit:SetChecked(ep.nameAutoFit ~= false)
        controls.fontSize:SetValue(ep.nameFontSize or 12); controls.fontSize.value:SetText(ep.nameFontSize or 12)
        controls.maxChars:SetValue(ep.nameMaxChars or 20); controls.maxChars.value:SetText(ep.nameMaxChars or 20)

        -- Bars
        controls.barFillDD:Rebuild()
        controls.missingMode:SetChecked(ep.missingHealthMode and true or false)
        controls.resourceDD:Rebuild()
        controls.resourceAnchorDD:Rebuild()
        controls.resourceSizeModeDD:Rebuild()
        controls.UpdateSizeControl()

        -- Layout
        controls.width:SetValue(ep.cellWidth or 90);   controls.width.value:SetText(ep.cellWidth or 90)
        controls.height:SetValue(ep.cellHeight or 18); controls.height.value:SetText(ep.cellHeight or 18)
        controls.spacing:SetValue(ep.spacing or 4);    controls.spacing.value:SetText(ep.spacing or 4)

        -- Global
        controls.lockFrame:SetChecked(S.DB().lockFrame and true or false)
        controls.testMode:SetChecked(S.DB().testMode and true or false)
        controls.testPresetDD:Rebuild()
        U.SetDropdownEnabled(controls.testPresetDD, S.DB().testMode)
    end
end
