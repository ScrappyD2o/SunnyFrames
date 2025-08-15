local ADDON, S = ...

S.cells = S.cells or {}
S.cellForUnit = S.cellForUnit or {}

function S.CreateCell(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.6)
    f:SetBackdropBorderColor(0, 0, 0, 0.9)

    local base = f:GetFrameLevel() or 0
    if base < 0 then base = 0 end
    if base > 65530 then base = 65530 end

    local hb = CreateFrame("StatusBar", nil, f)
    hb:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    hb:SetFrameLevel(base)
    f.health = hb

    local name = f:CreateFontString(nil, "OVERLAY")
    name:SetJustifyH("CENTER")
    S.ApplyNameFont(name, S.PGet("cellHeight"))
    name:SetText("?")
    f.name = name

    local hpct = f:CreateFontString(nil, "OVERLAY")
    hpct:SetJustifyH("CENTER")
    S.ApplyNameFont(hpct, S.PGet("cellHeight"))
    f.healthPct = hpct

    if S.DB().showHealthText then
        local ht = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ht:SetPoint("RIGHT", -2, 0)
        ht:SetJustifyH("RIGHT")
        f.healthText = ht
    end

    local pb = CreateFrame("StatusBar", nil, f)
    pb:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    pb:SetFrameLevel(base)
    local bg = pb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 1)
    pb.bg = bg
    pb:Hide()
    f.power = pb

    f.unit = nil

    if S.Cell_PositionTexts then S.Cell_PositionTexts(f) end
    if S.Cell_LayoutBars then S.Cell_LayoutBars(f, false, "INSIDE_BOTTOM", 3) end

    return f
end
