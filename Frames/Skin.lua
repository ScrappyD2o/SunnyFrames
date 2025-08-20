local ADDON, S = ...
S.Frames = S.Frames or {}
local SK = {}
S.Frames.Skin = SK

local function getClassColor(unit)
    local _, class = UnitClass(unit or "")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.7, 0.7, 0.7
end

local function getAwareColor(pct, f)
    -- thresholds from profile.frames (low/med/high)
    -- We interpret:
    --   pct < LowThreshold  -> Low color
    --   pct < HighThreshold -> Medium color
    --   else -> High color
    local lowT  = (f.healthAwareColorLowThreshold or 25) / 100
    local highT = (f.healthAwareColorHighThreshold or 75) / 100
    if pct <= lowT then
        local c = f.healthAwareColorLow or {1,0,0,1}
        return c[1],c[2],c[3],c[4] or 1
    elseif pct <= highT then
        local c = f.healthAwareColorMedium or {1,1,0,1}
        return c[1],c[2],c[3],c[4] or 1
    else
        local c = f.healthAwareColorHigh or {0,1,0,1}
        return c[1],c[2],c[3],c[4] or 1
    end
end

function SK.ApplyTexture(btn, framesCfg)
    local tex = framesCfg.healthTex or "Interface\\TargetingFrame\\UI-StatusBar"
    btn.Health:SetStatusBarTexture(tex)
    local bg = framesCfg.healthBackgroundColor or {0.1,0.1,0.1,1}
    btn.HealthBG:SetColorTexture(bg[1] or 0.1, bg[2] or 0.1, bg[3] or 0.1, bg[4] or 1)
end

function SK.ApplyFont(btn, framesCfg)
    local fs = btn.NameText
    local size = framesCfg.fontSize or 10
    local ok, font = pcall(GameFontHighlightSmall.GetFont, GameFontHighlightSmall)
    if ok and font then
        fs:SetFont(font, size, "")
    else
        -- fallback
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    end
end

function SK.ApplyStatic(btn, framesCfg)
    SK.ApplyTexture(btn, framesCfg)
    SK.ApplyFont(btn, framesCfg)
end

function SK.ApplyColor(btn, framesCfg)
    local unit = btn.unit
    if not unit then return end
    local max = UnitHealthMax(unit)
    local cur = UnitHealth(unit)
    if max and max > 0 then
        local pct = cur / max
        local r,g,b,a
        if framesCfg.useClassColors then
            r,g,b = getClassColor(unit)
            a = 1
        elseif framesCfg.healthAwareColor then
            r,g,b,a = getAwareColor(pct, framesCfg)
        else
            local c = framesCfg.healthColor or {1,0,0,1}
            r,g,b,a = c[1],c[2],c[3],c[4] or 1
        end
        btn.Health:SetStatusBarColor(r,g,b,a or 1)
    end
end
