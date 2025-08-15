local ADDON, S = ...

local function EnsureGrid()
    if S.grid then return end
    local g = CreateFrame("Frame", "SunnyFramesGrid", S.root)
    g:SetPoint("TOPLEFT", S.root, "TOPLEFT", 0, 0)
    g.cells = {}
    S.grid = g
end

function S.RefreshAll()
    if not S.grid or not S.grid.cells then return end
    for _, cell in ipairs(S.grid.cells) do
        S.UpdateCell(cell)
    end
end

function S.Layout(units)
    EnsureGrid()
    local g = S.grid
    local p = S.P()

    local cw = p.cellWidth or 90
    local ch = p.cellHeight or 18
    local sp = p.spacing or 4
    local per = p.perLine or 5
    local horiz = (p.orientation ~= "VERTICAL")

    local needed = #units
    local have = #g.cells

    for i = have + 1, needed do
        local cell = S.CreateCell(g)
        g.cells[i] = cell
    end
    for i = needed + 1, have do
        if g.cells[i] then g.cells[i]:Hide() end
    end

    local x, y = 0, 0
    local col, row = 0, 0

    for i = 1, needed do
        local cell = g.cells[i]
        cell:Show()
        cell:SetSize(cw, ch)
        cell.unit = units[i]

        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", g, "TOPLEFT", x, -y)

        if horiz then
            col = col + 1
            if col >= per then
                col, row = 0, row + 1
                x = 0
                y = row * (ch + sp)
            else
                x = x + cw + sp
            end
        else
            row = row + 1
            if row >= per then
                row, col = 0, col + 1
                y = 0
                x = col * (cw + sp)
            else
                y = y + ch + sp
            end
        end

        S.UpdateCell(cell)
    end

    -- size grid to contents
    local usedCols, usedRows
    if horiz then
        usedCols = math.min(per, needed)
        local usedRows = math.ceil(math.max(1, needed) / per)
        local totalW = (usedCols * cw) + math.max(0, usedCols - 1) * sp
        local totalH = (usedRows * ch) + math.max(0, usedRows - 1) * sp
        g:SetSize(totalW, totalH)
    else
        usedRows = math.min(per, needed)
        local usedCols = math.ceil(math.max(1, needed) / per)
        local totalW = (usedCols * cw) + math.max(0, usedCols - 1) * sp
        local totalH = (usedRows * ch) + math.max(0, usedRows - 1) * sp
        g:SetSize(totalW, totalH)
    end
end
