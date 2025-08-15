local ADDON, S = ...

-- Name anchoring helper
local function NameAnchorPoints(anchor)
    if anchor == "TOP" then
        return "TOP", 0, -1
    elseif anchor == "BOTTOM" then
        return "BOTTOM", 0, 1
    else
        return "CENTER", 0, 0
    end
end

-- Public: position name and health% based on active profile
function S.Cell_PositionTexts(cell)
    if not cell or not cell.name or not cell.healthPct then return end
    local nameAnchor = S.PGet("nameAnchor") or "CENTER"
    local mode = S.PGet("healthPctMode") or "UNDER"
    local showPct = S.PGet("showHealthPct") and true or false

    local name = cell.name
    local pct  = cell.healthPct

    name:Show()
    pct:Hide()
    name:ClearAllPoints()
    pct:ClearAllPoints()

    local p, ox, oy = NameAnchorPoints(nameAnchor)

    if not showPct or mode == "REPLACE" then
        if showPct and mode == "REPLACE" then
            name:Hide()
            pct:SetPoint(p, cell, p, ox, oy)
            pct:Show()
        else
            name:SetPoint(p, cell, p, ox, oy)
        end
        return
    end

    if mode == "ABOVE" then
        if nameAnchor == "TOP" then
            pct:SetPoint("TOP", cell, "TOP", 0, -1)
            name:SetPoint("TOP", pct, "BOTTOM", 0, -1)
        elseif nameAnchor == "BOTTOM" then
            name:SetPoint("BOTTOM", cell, "BOTTOM", 0, 1)
            pct:SetPoint("BOTTOM", name, "TOP", 0, 0)
        else
            name:SetPoint("CENTER", cell, "CENTER", 0, 0)
            pct:SetPoint("BOTTOM", name, "TOP", 0, 0)
        end
        pct:Show()
    else -- "UNDER"
        if nameAnchor == "BOTTOM" then
            pct:SetPoint("BOTTOM", cell, "BOTTOM", 0, 1)
            name:SetPoint("BOTTOM", pct, "TOP", 0, 0)
        elseif nameAnchor == "TOP" then
            name:SetPoint("TOP", cell, "TOP", 0, -1)
            pct:SetPoint("TOP", name, "BOTTOM", 0, -1)
        else
            name:SetPoint("CENTER", cell, "CENTER", 0, 0)
            pct:SetPoint("TOP", name, "BOTTOM", 0, -1)
        end
        pct:Show()
    end
end

-- Health/Power bars layout
function S.Cell_LayoutBars(cell, showPower, powerPlace, powerH)
    local hbar = cell.health
    local pbar = cell.power

    if hbar.SetOrientation then
        hbar:SetOrientation((S.PGet("barFillOrientation") == "VERTICAL") and "VERTICAL" or "HORIZONTAL")
    end

    hbar:ClearAllPoints()
    if showPower and (powerPlace == "INSIDE_TOP" or powerPlace == "INSIDE_BOTTOM") then
        if powerPlace == "INSIDE_TOP" then
            hbar:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -(1 + powerH))
            hbar:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
        else
            hbar:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -1)
            hbar:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, (1 + powerH))
        end
    else
        hbar:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -1)
        hbar:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
    end

    if pbar then
        if showPower then
            pbar:Show()
            pbar:ClearAllPoints()
            pbar:SetHeight(powerH)

            if powerPlace == "INSIDE_TOP" then
                pbar:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -1)
                pbar:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -1, -1)
            elseif powerPlace == "INSIDE_BOTTOM" then
                pbar:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 1, 1)
                pbar:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
            elseif powerPlace == "ABOVE" then
                pbar:SetPoint("BOTTOMLEFT", cell, "TOPLEFT", 1, 1)
                pbar:SetPoint("BOTTOMRIGHT", cell, "TOPRIGHT", -1, 1)
            elseif powerPlace == "BELOW" then
                pbar:SetPoint("TOPLEFT", cell, "BOTTOMLEFT", 1, -1)
                pbar:SetPoint("TOPRIGHT", cell, "BOTTOMRIGHT", -1, -1)
            end
        else
            pbar:Hide()
        end
    end
end
