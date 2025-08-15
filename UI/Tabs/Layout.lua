local ADDON, S = ...
local U = S.UI

local function PGet(k) return S.EGet(k) end
local function PSet(k,v) S.ESet(k,v); S.ApplyConfig() end

function U.BuildTab_Layout(parent, controls)
  local y = -10
  local x = U.COL_X

  controls.width, y = U.MakeSlider(parent, "Cell Width", 10, 300, 1, x, y, function(v)
    PSet("cellWidth", v)
  end, 12)

  controls.height, y = U.MakeSlider(parent, "Cell Height", 10, 100, 1, x, y, function(v)
    PSet("cellHeight", v)
  end, 12)

  controls.spacing, y = U.MakeSlider(parent, "Cell Spacing", 0, 50, 1, x, y, function(v)
    PSet("spacing", v)
  end, 0)

  return function()
    local ep = S.EP()
    controls.width:SetValue(ep.cellWidth or 90);   controls.width.value:SetText(ep.cellWidth or 90)
    controls.height:SetValue(ep.cellHeight or 18); controls.height.value:SetText(ep.cellHeight or 18)
    controls.spacing:SetValue(ep.spacing or 4);    controls.spacing.value:SetText(ep.spacing or 4)
  end
end
