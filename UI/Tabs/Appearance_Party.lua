local ADDON, S = ...
S.UI = S.UI or {}
local U = S.UI
U.widgets = U.widgets or {}
U.widgets.party = U.widgets.party or {}
local W = U.widgets.party
local function C(name)
    local c = S.UIColors[name]
    if not c then
        return 1, 0, 1, 1
    end
    return c[1], c[2], c[3], c[4]
end

function U.BuildAppearancePartySub(parent)
    local state = function()
        return S.Profile.party
    end
    local grid, colL, colR = U.CreateTwoColumnGrid(parent)
    local lastL, lastR

    local LEFT_PAD = 16
    local RIGHT_PAD = 16
    local GAP = 32
    local MAX_FULL = 140
    local MAX_HALF = 140
    local TEXT_PAD = 30

    local pr, cP, cB1



    -- ========== Group: Position & Anchor ==========
    do
        local g, y = U.BeginGroup(colL, "Position & Anchor", lastL)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)

        local minX, maxX, minY, maxY, step = -1000, 1000, -500, 500, 1
        if U.CalcPartyOffsetLimits then
            minX, maxX, minY, maxY, step = U.CalcPartyOffsetLimits()
        end

        -- Row 1: window position sliders (side-by-side)
        -- Horizontal
        local s1;
        s1, _ = U.MakeBoundSlider(
                g, "Horizontal Position",
                minX, maxX, step, xLeft, y, HALF, 0,
                { path = "party.xPos", section = "party" },
                { live = true, refresh = true, default = 0 })

        -- Vertical
        local s2;
        s2, y = U.MakeBoundSlider(
                g, "Vertical Position",
                minY, maxY, step, xRight, y, HALF, 0,
                { path = "party.yPos", section = "party" },
                { live = true, refresh = true, default = 0 })

        -- Store for sync/range updates
        U.widgets = U.widgets or {}
        U.widgets.party = U.widgets.party or {}
        U.widgets.party.xSlider = s1
        U.widgets.party.ySlider = s2

        if S.UI and S.UI.SyncPartyFromDB then
            S.UI.SyncPartyFromDB()
        end

        -- Row 2: Groups Orientation (full width) — bound dropdown
        local dd3;
        dd3, y = U.MakeBoundDropdown(
                g, "Groups Orientation",
                {
                    { text = "Horizontal", value = "HORIZONTAL" },
                    { text = "Vertical", value = "VERTICAL" },
                },
                LEFT_PAD, y, FULL, 10,
                { path = "party.orientation", section = "party" },
                { refresh = true, default = "HORIZONTAL" }
        )

        -- Keep the “Frames per …” slider header + value in sync when orientation flips
        dd3:RegisterCallback("ValueChanged", function(self, value)
            local header = (value == "HORIZONTAL") and "Frames per Row" or "Frames per Column"
            if pr and pr.SetLabel then
                pr:SetLabel(header)
            end
            if pr and pr.Rebuild then
                pr:Rebuild()
            end   -- switch reads between framesPerRow/framesPerColumn
        end, g)

        lastL = U.EndGroup(g, y)
    end

    -- ========== Group: Frame Sizing & Layout ==========
    do
        local g, y = U.BeginGroup(colL, "Frame Sizing & Layout", lastL)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)
        local nextY = y

        local sliderHeader = (state().orientation == "HORIZONTAL") and "Frames per Row" or "Frames per Column"

        -- Frames per Row/Column (single slider, bound via custom get/set)
        pr, nextY = U.MakeBoundSlider(
                g, sliderHeader,
                1, 5, 1, LEFT_PAD, nextY, FULL, 10,
                {
                    -- custom binding that switches target by orientation
                    get = function()
                        if state().orientation == "HORIZONTAL" then
                            return state().framesPerRow
                        else
                            return state().framesPerColumn
                        end
                    end,
                    set = function(val)
                        if state().orientation == "HORIZONTAL" then
                            state().framesPerRow = val
                        else
                            state().framesPerColumn = val
                        end
                    end,
                    section = "party",
                },
                { live = true, refresh = true }   -- commit-only to avoid heavy rebuild while dragging
        )

        -- Row: Frame Width / Height (side-by-side)
        local sW;
        sW, _ = U.MakeBoundSlider(
                g, "Frame Width",
                10, 300, 1, xLeft, nextY, HALF, 0,
                { path = "party.frameWidth", section = "party" },
                { live = true, refresh = true })

        local sH;
        sH, y = U.MakeBoundSlider(
                g, "Frame Height",
                10, 200, 1, xRight, nextY, HALF, 0,
                { path = "party.frameHeight", section = "party" },
                { live = true, refresh = true })

        local sS;
        sS, _ = U.MakeBoundSlider(
                g, "Frame Spacing",
                0, 20, 1, xLeft, y, HALF, 0,
                { path = "party.frameSpacing", section = "party" },
                { live = true, refresh = true })
        
        local sFB;
        sFB, y = U.MakeBoundSlider(
                g, "Frame Border",
                0, 20, 1, xRight, y, HALF, 0,
                { path = "party.frameBorder", section = "party" },
                { live = true, refresh = true })

        
        U.widgets.party.perSlider = pr
        U.widgets.party.widthSlider = sW
        U.widgets.party.heightSlider = sH
        U.widgets.party.spacingSlider = sS

        lastL = U.EndGroup(g, y)
    end

    -- ========== Group: Sorting & Role Priority ==========
    do
        local g, y = U.BeginGroup(colR, "Sorting & Role Priority", lastR)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)

        local sortDD;
        sortDD, y = U.MakeBoundDropdown(g,
                "Sorting Order",
                {
                    { text = "Unsorted", value = "UNSORTED" },
                    { text = "A - Z", value = "AZ" },
                    { text = "Z - A", value = "ZA" },
                    { text = "Tanks-Healers-DPS", value = "THD" },
                    { text = "Healers-Tanks-DPS", value = "HTD" },
                },
                xLeft, y, FULL, 8,
                { path = "party.sortingOrder", section = "party" },
                { refresh = true, default = "UNSORTED" })

        lastR = U.EndGroup(g, y)
    end

    -- ========== Group: Visibility & Conditions ==========
    do
        local g, y = U.BeginGroup(colR, "Visibility & Conditions", lastR)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)

        local cb;
        cb, y = U.MakeBoundCheckbox(
                g, "Hide in Pet Battles",
                xLeft, y, 0,
                { path = "party.hideInPetBattle", section = "party" },
                { refresh = true, default = false })

        local cP1;
        cP1, y = U.MakeBoundCheckbox(
                g, "Show Pets",
                xLeft, y, 0,
                { path = "party.showPets", section = "party" },
                { refresh = true, default = false })
        
        lastR = U.EndGroup(g, y)
    end

    if S.UI and S.UI.UpdatePartyPositionSliderRanges then
        S.UI.UpdatePartyPositionSliderRanges()
    end
end
