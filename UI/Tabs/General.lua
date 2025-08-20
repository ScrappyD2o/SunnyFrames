local ADDON, S = ...
local U = S.UI
local function C(name) local c=S.UIColors[name]; if not c then return 1,0,1,1 end return c[1],c[2],c[3],c[4] end

function U.Build_General(page)
    local grid, colL, colR = U.CreateTwoColumnGrid(page)
    local lastL, lastR
    local state = function() return S.Profile.general end

    -- LEFT COLUMN
    do
        local g, y = U.BeginGroup(colL, "Frame Interaction", lastL)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)

        local cb; cb, y = U.MakeBoundCheckbox(
            g, "Enable Click-Targeting",
            xLeft, y, 0,
            { path = "general.enableClickTargeting", section = "general" },
            { refresh = true, default = true })

        cb:RegisterCallback("ValueChanged", function(self, val)
            if S.Frames and S.Frames.UpdateClickTargeting then
                S.Frames.UpdateClickTargeting()
            end
        end, page)
        
        cb, y = U.MakeBoundCheckbox(
                g, "Lock Frames",
                xLeft, y, 8,
                { path = "general.lockFrames", section = "general" },
                { refresh = true, default = false })

        local dd; dd, y = U.MakeBoundDropdown(
            g, "Handle Anchor Position",
            {
                { text="Top Left",     value="TOPLEFT"     },
                { text="Top Right",    value="TOPRIGHT"    },
                { text="Bottom Left",  value="BOTTOMLEFT"  },
                { text="Bottom Right", value="BOTTOMRIGHT" },
            },
            xLeft, y, U.DD_WIDTH, 0,
            { path = "general.handleAnchorPosition", section = "general" },
            { refresh = true, default = "TOPLEFT" })

        -- Also move the handle immediately (without waiting on a full rebuild)
        dd:RegisterCallback("ValueChanged", function()
            if S.Handle and S.Handle.Position then S.Handle.Position() end
        end, g)

        lastL = U.EndGroup(g, y)

        local g2, y2 = U.BeginGroup(colL, "Visibility & Scale", lastL)
        local FULL2, HALF2, xLeft2, xRight2 = U.CalcWidths(g2)

        local cb2; cb2, y2 = U.MakeBoundCheckbox(
            g2, "Show Minimap Icon",
            xLeft2, y2, 6,
            { path = "general.showMinimapIcon", section = "general" },
            { refresh = true, default = true })

        local s; s, y2 = U.MakeBoundSlider(
            g2, "Global Frame Scale",
            50, 150, 1, xLeft2, y2, HALF2, 0,
            { path = "general.globalFrameScale", section = "general" },
            { live = true, refresh = true, default = 100 })

        lastL = U.EndGroup(g2, y2)
    end

    -- RIGHT COLUMN
    do
        local g, y = U.BeginGroup(colR, "Blizzard Frames", lastR)
        local FULL, HALF, xLeft, xRight = U.CalcWidths(g)

        local cb; cb, y = U.MakeBoundCheckbox(
            g, "Hide Blizzard Party Frames",
            xLeft, y, 2,
            { path = "general.hideBlizzardPartyFrames", section = "general" },
            { refresh = true, default = true })

        cb, y = U.MakeBoundCheckbox(
                g, "Hide Blizzard Raid Frames",
                xLeft, y, 0,
                { path = "general.hideBlizzardRaidFrames", section = "general" },
                { refresh = true, default = true })

        lastR = U.EndGroup(g, y)

        local g2, y2 = U.BeginGroup(colR, "Tooltips", lastR)
        local FULL2, HALF2, xLeft2, xRight2 = U.CalcWidths(g2)

        local cb2; cb2, y2 = U.MakeBoundCheckbox(
            g2, "Enable Tooltips",
            xLeft2, y2, 0,
            { path = "general.enableTooltips", section = "general" },
            { live = true, refresh = true, default = true })

        cb2, y2 = U.MakeBoundCheckbox(
                g2, "Hide Tooltips in Combat",
                xLeft2, y2, 6,
                { path = "general.hideTooltipsInCombat", section = "general" },
                { refresh = true, default = false })

        local dd; dd, y2 = U.MakeBoundDropdown(
            g2, "Tooltip Anchor",
            {
                { text="Default (Blizzard)",    value="DEFAULT"    },
                { text="At Cursor",             value="CURSOR"     },
                { text="Top Left of Cell",      value="TOPLEFT"    },
                { text="Top Right of Cell",     value="TOPRIGHT"   },
                { text="Bottom Left of Cell",   value="BOTTOMLEFT" },
                { text="Bottom Right of Cell",  value="BOTTOMRIGHT"},
            },
            xLeft2, y2, U.DD_WIDTH, 0,
            { path = "general.tooltipAnchorPosition", section = "general" },
            { refresh = true, default = "DEFAULT" })

        lastR = U.EndGroup(g2, y2)
    end

    page:SetHeight(1000)
end
