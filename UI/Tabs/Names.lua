local ADDON, S = ...
local U = S.UI

local function PGet(k) return S.EGet(k) end
local function PSet(k,v) S.ESet(k,v); S.ApplyConfig() end

function U.BuildTab_Names(parent, controls)
  local y = -10
  local x = U.COL_X

  controls.nameAnchorDD, y = U.MakeDropdown(
    parent, "Name Anchor",
    {
      {text="Top", value="TOP"},
      {text="Center", value="CENTER"},
      {text="Bottom", value="BOTTOM"},
    },
    function() return PGet("nameAnchor") or "CENTER" end,
    function(v) PSet("nameAnchor", v) end,
    x, y, U.DD_WIDTH, 12
  )

  controls.showPct, y = U.MakeCheckbox(parent, "Show Health %", x, y, function(v)
    PSet("showHealthPct", not not v)
    if controls.healthPctModeDD then controls.healthPctModeDD:SetShown(PGet("showHealthPct")) end
  end, nil, 6)

  controls.healthPctModeDD, y = U.MakeDropdown(
    parent, "Health % Mode",
    {
      {text="Above Name",  value="ABOVE"},
      {text="Under Name",  value="UNDER"},
      {text="Replace Name",value="REPLACE"},
    },
    function() return PGet("healthPctMode") or "UNDER" end,
    function(v) PSet("healthPctMode", v) end,
    x, y, U.DD_WIDTH, 16
  )

  controls.autoFit, y = U.MakeCheckbox(parent, "Auto fit name font", x, y, function(v)
    PSet("nameAutoFit", not not v)
  end, "Shrink name text to fit width; otherwise keep size and truncate", 16)

  controls.fontSize, y = U.MakeSlider(parent, "Name Font Size (max)", 4, 24, 1, x, y, function(v)
    PSet("nameFontSize", v)
  end, 12)

  controls.maxChars, y = U.MakeSlider(parent, "Max name characters", 4, 36, 1, x, y, function(v)
    PSet("nameMaxChars", v)
  end, 0)

  return function()
    local ep = S.EP()
    controls.nameAnchorDD:Rebuild()
    controls.showPct:SetChecked(ep.showHealthPct and true or false)
    controls.healthPctModeDD:Rebuild()
    controls.healthPctModeDD:SetShown(ep.showHealthPct and true or false)
    controls.autoFit:SetChecked(ep.nameAutoFit ~= false)
    controls.fontSize:SetValue(ep.nameFontSize or 12); controls.fontSize.value:SetText(ep.nameFontSize or 12)
    controls.maxChars:SetValue(ep.nameMaxChars or 20); controls.maxChars.value:SetText(ep.nameMaxChars or 20)
  end
end
