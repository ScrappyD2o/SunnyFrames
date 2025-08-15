local ADDON, S = ...

function S.UpdateCell(cell)
    if not cell then return end
    local db = S.P() -- active profile
    local unit = cell.unit
    local isTest = S.DB().testMode and (type(unit) == "string" and unit:match("^test%d+$"))

    S.ApplyNameFont(cell.name, cell:GetHeight())
    S.ApplyNameFont(cell.healthPct, cell:GetHeight())
    if S.Cell_PositionTexts then S.Cell_PositionTexts(cell) end

    local nameText, classToken, hp, hpMax, pCur, pMax, powerToken

    if isTest then
        local idx = tonumber(unit:match("^test(%d+)$")) or 1
        local td = S.TestData(idx)
        nameText   = td.name
        classToken = td.class
        hp, hpMax  = td.hp, td.hpMax
        pCur, pMax = td.pCur, td.pMax
        powerToken = td.powerToken
    else
        if not unit or not UnitExists(unit) then
            cell.health:SetMinMaxValues(0,1); cell.health:SetValue(0)
            cell.health:SetStatusBarColor(.2,.2,.2)
            S.FitNameText(cell, "?")
            cell.healthPct:SetText("")
            if cell.healthText then cell.healthText:SetText("") end
            if cell.power then cell.power:Hide() end
            return
        end
        nameText   = UnitName(unit) or "?"
        classToken = select(2, UnitClass(unit))
        hp, hpMax  = UnitHealth(unit), UnitHealthMax(unit)
        pCur, pMax = UnitPower(unit), UnitPowerMax(unit)
        powerToken = select(2, UnitPowerType(unit)) or "MANA"
    end

    hpMax = (hpMax and hpMax > 0) and hpMax or 1
    local missing = hpMax - (hp or 0)

    local shownValue = db.missingHealthMode and missing or hp
    cell.health:SetMinMaxValues(0, hpMax)
    cell.health:SetValue(shownValue)

    local pct = (hp or 0) / hpMax
    local r, g, b
    if isTest then r, g, b = S.ClassColorForClass(classToken) else r, g, b = S.ClassColor(unit) end
    local dim = 0.55 + 0.45 * pct
    cell.health:SetStatusBarColor(r*dim, g*dim, b*dim)

    if cell.health.SetOrientation then
        cell.health:SetOrientation((db.barFillOrientation == "VERTICAL") and "VERTICAL" or "HORIZONTAL")
    end

    if db.showHealthPct and db.healthPctMode == "REPLACE" then
        cell.healthPct:SetText(("%d%%"):format(math.floor(pct*100+0.5)))
        cell.name:SetText("")
    else
        S.FitNameText(cell, nameText)
        if db.showHealthPct then
            cell.healthPct:SetText(("%d%%"):format(math.floor(pct*100+0.5)))
        else
            cell.healthPct:SetText("")
        end
    end

    if cell.healthText then
        cell.healthText:SetText(("%d/%d"):format(hp, hpMax))
    end

    if cell.power then
        local showPower
        if isTest then
            local mode = db.resourceMode or "ALL"
            showPower = (mode ~= "NONE") and (mode ~= "MANA" or powerToken == "MANA")
        else
            showPower = S.ShouldShowResource(unit)
        end

        if showPower then
            local pr, pg, pb
            if isTest then pr, pg, pb = S.PowerColorForToken(powerToken) else local _; _, pr, pg, pb = S.PowerTypeAndColor(unit) end

            local place = db.resourceAnchor or "INSIDE_BOTTOM"

            local cellH = cell:GetHeight() or (db.cellHeight or 18)
            local pHeight
            if db.resourceSizeMode == "PIXELS" then
                pHeight = math.max(1, math.floor(tonumber(db.resourceSizePx) or 3))
            else
                local pctH = math.max(1, math.min(90, tonumber(db.resourceSizePct) or 10))
                pHeight = math.max(1, math.floor(cellH * (pctH / 100)))
            end

            if S.Cell_LayoutBars then S.Cell_LayoutBars(cell, true, place, pHeight) end

            cell.power:SetStatusBarColor(pr, pg, pb)
            cell.power:SetMinMaxValues(0, (pMax and pMax > 0) and pMax or 1)
            cell.power:SetValue(pCur or 0)
        else
            if S.Cell_LayoutBars then S.Cell_LayoutBars(cell, false, "INSIDE_BOTTOM", 0) end
        end
    end
end

function S.UpdateAllNameFonts()
    for _, cell in ipairs(S.cells) do
        if cell and cell.name and cell.healthPct then
            S.ApplyNameFont(cell.name, cell:GetHeight())
            S.ApplyNameFont(cell.healthPct, cell:GetHeight())
            S.FitNameText(cell, cell.name:GetText() or "?")
            if S.Cell_PositionTexts then S.Cell_PositionTexts(cell) end
        end
    end
end
