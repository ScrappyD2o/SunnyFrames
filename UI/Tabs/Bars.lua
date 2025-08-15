local ADDON, S = ...
local U = S.UI

local function PGet(k) return S.EGet(k) end
local function PSet(k,v) S.ESet(k,v); S.ApplyConfig() end

function U.BuildTab_Bars(parent, controls)
  local y = -10
  local x = U.COL_X

  controls.barFillDD, y = U.MakeDropdown(
    parent, "Health Bar Fill",
    {
      {text="Horizontal", value="HORIZONTAL"},
      {text="Vertical",   value="VERTICAL"},
    },
    function() return PGet("barFillOrientation") or "HORIZONTAL" end,
    function(v) PSet("barFillOrientation", v) end,
    x, y, U.DD_WIDTH, 12
  )

  controls.missingMode, y = U.MakeCheckbox(parent, "Missing Health Mode", x, y, function(v)
    PSet("missingHealthMode", not not v)
  end, "Bar represents missing health instead of current", 12)

  controls.resourceAnchorDD, y = U.MakeDropdown(
    parent, "Resource Anchor",
    {
      {text="Inside Top",    value="INSIDE_TOP"},
      {text="Inside Bottom", value="INSIDE_BOTTOM"},
      {text="Above",         value="ABOVE"},
      {text="Beneath",       value="BELOW"},
    },
    function() return PGet("resourceAnchor") or "INSIDE_BOTTOM" end,
    function(v) PSet("resourceAnchor", v) end,
    x, y, U.DD_WIDTH, 16
  )

  controls.resourceSizeModeDD, y = U.MakeDropdown(
    parent, "Resource Size Mode",
    {
      {text="Percent of Height", value="PERCENT"},
      {text="Exact Pixels",      value="PIXELS"},
    },
    function() return PGet("resourceSizeMode") or "PERCENT" end,
    function(v) PSet("resourceSizeMode", v); if controls.UpdateSizeControl then controls.UpdateSizeControl() end end,
    x, y, U.DD_WIDTH, 10
  )

  controls.resourceSize, y = U.MakeSlider(parent, "Resource Size", 1, 90, 1, x, y, function(v)
    if PGet("resourceSizeMode") == "PIXELS" then
      PSet("resourceSizePx", v)
    else
      PSet("resourceSizePct", v)
    end
  end, 0)

  function controls.UpdateSizeControl()
    local mode = PGet("resourceSizeMode") or "PERCENT"
    if mode == "PIXELS" then
      controls.resourceSize.title:SetText("Resource Size (pixels)")
      controls.resourceSize:SetMinMaxValues(1, 30)
      local val = tonumber(PGet("resourceSizePx")) or 3
      controls.resourceSize:SetValue(val)
      controls.resourceSize.value:SetText(tostring(val))
    else
      controls.resourceSize.title:SetText("Resource Size (% of height)")
      controls.resourceSize:SetMinMaxValues(1, 90)
      local val = tonumber(PGet("resourceSizePct")) or 10
      controls.resourceSize:SetValue(val)
      controls.resourceSize.value:SetText(tostring(val))
    end
  end

  return function()
    local ep = S.EP()
    controls.barFillDD:Rebuild()
    controls.missingMode:SetChecked(ep.missingHealthMode and true or false)
    controls.resourceAnchorDD:Rebuild()
    controls.resourceSizeModeDD:Rebuild()
    controls.UpdateSizeControl()
  end
end
