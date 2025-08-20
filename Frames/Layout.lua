local ADDON, S = ...
S.Frames        = S.Frames or {}
S.Frames.Layout = S.Frames.Layout or {}

-- -----------------------------------------------------------------------------
-- Pixel helpers (do grid math as integer pixels in the *container* space)
-- -----------------------------------------------------------------------------
local function PixelSize(frame)
    local s = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or (UIParent and UIParent:GetEffectiveScale()) or 1
    if s <= 0 then s = 1 end
    return 1 / s
end

local function round(v)  -- unbiased rounding
    if v >= 0 then return math.floor(v + 0.5) else return math.ceil(v - 0.5) end
end

-- Convert a UI length to an integer pixel count for a given anchor frame
local function toPixels(anchor, lengthUI)
    local p = PixelSize(anchor)
    return round((lengthUI or 0) / p)  -- integer physical pixels
end

-- Convert integer pixels back to UI units
local function fromPixels(anchor, pxCount)
    local p = PixelSize(anchor)
    return (pxCount or 0) * p
end

-- -----------------------------------------------------------------------------
-- Layout
-- -----------------------------------------------------------------------------
-- Compute layout & apply points/sizes; returns container width/height
function S.Frames.Layout.Apply(container, buttons, P)
    if not container or not buttons then return 0, 0 end
    P = P or {}

    -- Raw inputs
    local wUI     = tonumber(P.frameWidth)   or 120
    local hUI     = tonumber(P.frameHeight)  or 28
    local padUI   = tonumber(P.frameSpacing) or 2
    local orient  = (P.orientation == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
    local per     = (orient == "HORIZONTAL") and (tonumber(P.framesPerRow)    or 5)
            or (tonumber(P.framesPerColumn) or 5)

    local total = #buttons
    if total <= 0 then
        container:SetSize(1, 1)
        return 1, 1
    end

    -- All grid math uses *container* pixels
    local Wpx   = toPixels(container, wUI)
    local Hpx   = toPixels(container, hUI)
    local PADpx = (padUI == 0) and 0 or toPixels(container, padUI)  -- force exact 0 if user set 0

    local rows, cols
    if orient == "HORIZONTAL" then
        cols = math.min(per, total)
        rows = math.ceil(total / per)
    else
        rows = math.min(per, total)
        cols = math.ceil(total / per)
    end

    -- Container size (exact pixels)
    local contWpx = (orient == "HORIZONTAL")
            and math.max(1, cols * Wpx + (cols - 1) * PADpx)
            or  math.max(1, cols * Wpx + (cols - 1) * PADpx)
    local contHpx = (orient == "HORIZONTAL")
            and math.max(1, rows * Hpx + (rows - 1) * PADpx)
            or  math.max(1, rows * Hpx + (rows - 1) * PADpx)

    local contP = PixelSize(container)
    container:SetSize(contWpx * contP, contHpx * contP)

    -- Precomputed UI sizes *from the same pixel counts*
    local btnW = Wpx   * contP
    local btnH = Hpx   * contP
    local offX = PADpx * contP
    local offY = PADpx * contP

    -- Helper to index a button by row/col in our logical grid
    local function gridIndex(r, c)
        if orient == "HORIZONTAL" then
            return r * per + c + 1
        else
            return c * per + r + 1
        end
    end

    -- Place buttons by anchoring to neighbors (removes sub-pixel slivers)
    for idx, btn in ipairs(buttons) do
        btn:SetSize(btnW, btnH)
        btn:ClearAllPoints()

        local r, c
        if orient == "HORIZONTAL" then
            r = math.floor((idx - 1) / per)
            c = (idx - 1) % per
        else
            c = math.floor((idx - 1) / per)
            r = (idx - 1) % per
        end

        if r == 0 and c == 0 then
            -- First cell -> container's TOPLEFT
            btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        elseif r > 0 then
            -- Not first row: anchor to the button directly above
            local aboveIdx = gridIndex(r - 1, c)
            local aboveBtn = buttons[aboveIdx]
            btn:SetPoint("TOPLEFT", aboveBtn, "BOTTOMLEFT", 0, -offY)
        else
            -- First row, not first column: anchor to the button to the left
            local leftIdx = gridIndex(r, c - 1)
            local leftBtn = buttons[leftIdx]
            btn:SetPoint("TOPLEFT", leftBtn, "TOPRIGHT", offX, 0)
        end
    end

    return contWpx * contP, contHpx * contP
end
