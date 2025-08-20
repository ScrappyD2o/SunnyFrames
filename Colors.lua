local ADDON, S = ...
S.UIColors = {
    background   = {0.05, 0.05, 0.06, 0.98}, -- main window bg
    panel        = {0.07, 0.07, 0.08, 1.00}, -- inner body bg
    panelAlt     = {0.08, 0.08, 0.10, 1.00}, -- header / alt panels
    border       = {0.00, 0.00, 0.00, 1.00}, -- standard border

    accent       = {0.25, 0.55, 1.00, 0.90}, -- primary accent blue
    accentHover  = {0.35, 0.65, 1.00, 0.90}, -- accent on hover

    navIdleBG    = {0.08, 0.08, 0.10, 0.60}, -- nav item idle bg
    navHoverBG   = {0.10, 0.10, 0.12, 0.90}, -- nav item hover bg
    navSelBG     = {0.10, 0.10, 0.12, 1.00}, -- nav item selected bg

    textNormal   = {0.85, 0.85, 0.87, 1.00},
    textHover    = {0.95, 0.95, 0.98, 1.00},
    textSelected = {1.00, 1.00, 1.00, 1.00},
}

-- tiny helper
function S.UIColor(name)
    local c = S.UIColors and S.UIColors[name]
    if not c then return 1,1,1,1 end
    return c[1], c[2], c[3], c[4]
end
