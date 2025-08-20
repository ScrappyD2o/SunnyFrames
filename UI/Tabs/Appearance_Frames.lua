local ADDON, S = ...
local U = S.UI
local function C(name)
    local c = S.UIColors[name]
    if not c then
        return 1, 0, 1, 1
    end
    return c[1], c[2], c[3], c[4]
end

function U.BuildAppearanceFramesSub(parent)
    local state = function() return S.Profile.frames end
    local grid, colL, colR = U.CreateTwoColumnGrid(parent)
    local lastL, lastR

    local barTextures = {
        { text = "UI-StatusBar",  value = "Interface\\TargetingFrame\\UI-StatusBar" },
        { text = "Flat",          value = "Interface\\Buttons\\WHITE8x8" },
        { text = "Raid-Bar-Hp",   value = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    }

    local Elements = (S.Frames and S.Frames.Elements) or {}
    local function repaint()
        if Elements.Health and Elements.Health.RefreshAll then Elements.Health.RefreshAll() end
        if Elements.Name   and Elements.Name.RefreshAll   then Elements.Name.RefreshAll()   end
    end

    -- LEFT COLUMN ---------------------------------------------------------------
    do
        local g, y = U.BeginGroup(colL, "Visuals", lastL)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)
        local startY = y

        -- Use Class Colors (left)  +  Health Color (right)
        local cB; cB, _ = U.MakeBoundCheckbox(
            g, "Use Class Colors",
            xLeft, y, 0,
            { path = "frames.useClassColors", section = "frames" },
            { live = true, refresh = false, default = false }
    )

        local cP; cP, _ = U.MakeBoundColorPicker(
            g, "Health Color",
            xRight, y, { visible = not state().useClassColors },
            { path = "frames.healthColor", section = "frames" },
            { refresh = true, default = {0.15, 0.8, 0.15, 1}, live = true })
        
        cP:RegisterCallback("ValueChanged", repaint, g)

        -- put checkbox + color picker on the same row
        U.PairRow(cB, cP)

        -- Healthbar Texture (full width)
        local ddTex; ddTex, y = U.MakeBoundTextureDropdown(
            g, "Healthbar Texture", barTextures,
            xLeft, y, FULL, 0,
            { path = "frames.healthTex", section = "frames" },
            { live = true, refresh = false, default = "Interface\\TargetingFrame\\UI-StatusBar" }
    )
        ddTex:RegisterCallback("ValueChanged", repaint, g)

        -- Use Health Aware Colors
        local cB1; cB1, y = U.MakeBoundCheckbox(
            g, "Use Health Aware Colors",
            xLeft, y, { visible = not state().useClassColors },
            { path = "frames.healthAwareColor", section = "frames" },
            { live = true, refresh = false, default = false }
    )
        cB1:RegisterCallback("ValueChanged", repaint, g)

        -- Low / Med / High colors + thresholds (paired rows)
        local showAware = (not state().useClassColors) and (state().healthAwareColor == true)

        local cP1; cP1, _ = U.MakeBoundColorPicker(
            g, "Low", xLeft, y, { visible = showAware },
            { path = "frames.healthAwareColorLow", section = "frames" },
            { live = true, refresh = false, default = { 0.85, 0.20, 0.20, 1 } }
    )
        cP1:RegisterCallback("ValueChanged", repaint, g)

        local cI1; cI1, _ = U.MakeBoundInputField(
            g, "", xLeft + 40, y, 20, { visible = showAware },
            { path = "frames.healthAwareColorLowThreshold", section = "frames" },
            { numeric = true, integer = true, min = 1, max = 99, default = 35, live = true, refresh = false }
    )
        cI1:RegisterCallback("ValueChanged", repaint, g)

        local cP2; cP2, _ = U.MakeBoundColorPicker(
            g, "Med", xLeft + 70, y, { visible = showAware },
            { path = "frames.healthAwareColorMed", section = "frames" },
            { live = true, refresh = false, default = { 0.90, 0.80, 0.20, 1 } }
    )
        cP2:RegisterCallback("ValueChanged", repaint, g)

        local cI2; cI2, _ = U.MakeBoundInputField(
            g, "", xLeft + 110, y, 20, { visible = showAware },
            { path = "frames.healthAwareColorHighThreshold", section = "frames" },
            { numeric = true, integer = true, min = 1, max = 99, default = 75, live = true, refresh = false }
    )
        cI2:RegisterCallback("ValueChanged", repaint, g)

        local cP3; cP3, _ = U.MakeBoundColorPicker(
            g, "High", xLeft + 140, y, { visible = showAware },
            { path = "frames.healthAwareColorHigh", section = "frames" },
            { live = true, refresh = false, default = { 0.20, 0.75, 0.20, 1 } }
    )
        cP3:RegisterCallback("ValueChanged", repaint, g)

        U.PairRow(cP1, cI1, cP2, cI2, cP3)

        -- Background Color (always visible)
        local cP4; cP4, y = U.MakeBoundColorPicker(
            g, "Background Color",
            xLeft, y, 0,
            { path = "frames.healthBackgroundColor", section = "frames" },
            { live = true, refresh = false, default = { 0.10, 0.10, 0.10, 1 } }
    )
        cP4:RegisterCallback("ValueChanged", repaint, g)

        -- Visibility wiring (and force Rebuild() when showing so values load correctly)
        local function show(ctrl, vis)
            if not ctrl then return end
            ctrl:SetVisible(vis)
            if vis and ctrl.Rebuild then ctrl:Rebuild() end
        end

        local function applyVisibility()
            local usingClass = state().useClassColors == true
            local aware = (state().healthAwareColor == true) and (not usingClass)

            show(cP,  not usingClass)
            show(cB1, not usingClass)

            show(cP1, aware); show(cI1, aware)
            show(cP2, aware); show(cI2, aware)
            show(cP3, aware)

            if U.RelayoutGroup then U.RelayoutGroup(g, nil, startY) end
        end

        cB:RegisterCallback("ValueChanged", function() applyVisibility(); repaint() end, g)
        cB1:RegisterCallback("ValueChanged", function() applyVisibility(); repaint() end, g)
        applyVisibility()

        lastL = U.EndGroup(g, y)
        U.RelayoutGroup(g, nil, startY)
    end

    -- RIGHT COLUMN --------------------------------------------------------------
    do
        local g, y = U.BeginGroup(colR, "Names & Font", lastR)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)

        local sN; sN, _ = U.MakeBoundSlider(
            g, "Max name length",
            1, 20, 1, xLeft, y, HALF, 0,
            { path = "frames.maxNameLength", section = "frames" },
            { live = true, refresh = false, default = 12 }
    )
        sN:RegisterCallback("ValueChanged", repaint, g)

        local sN1; sN1, y = U.MakeBoundSlider(
            g, "Font Size",
            5, 32, 1, xRight, y, HALF, 0,
            { path = "frames.fontSize", section = "frames" },
            { live = true, refresh = false, default = 12 }
    )
        sN1:RegisterCallback("ValueChanged", repaint, g)

        lastR = U.EndGroup(g, y)
    end

    
end


