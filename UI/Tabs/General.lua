local ADDON, S = ...
local U = S.UI
local function C(name) local c=S.UIColors[name]; if not c then return 1,0,1,1 end return c[1],c[2],c[3],c[4] end

function U.Build_General(page)
  local x = 16
  local grid, colL, colR = U.CreateTwoColumnGrid(page)
  local lastL, lastR

  -- LEFT COLUMN
  do
    local g, y = U.BeginGroup(colL, "Frame Interaction", lastL)
    local cb; cb, y = U.MakeCheckbox(g, "Enable Click-Targeting", x, y, nil, "Click a frame to target that unit", 2)
    cb, y = U.MakeCheckbox(g, "Lock Frames", x, y, nil, "Disable dragging", 8)
    local dd; dd, y = U.MakeDropdown(g, "Frame Anchor Position",
          {
            {text="Top Left",     value="TOPLEFT"},
            {text="Top Right",    value="TOPRIGHT"},
            {text="Bottom Left",  value="BOTTOMLEFT"},
            {text="Bottom Right", value="BOTTOMRIGHT"},
            {text="Center",       value="CENTER"},
          },
          function() return "TOPLEFT" end,
          function(_) end,
          x, y, U.DD_WIDTH, 0)
    lastL = U.EndGroup(g, y)

    local g2, y2 = U.BeginGroup(colL, "Visibility & Scale", lastL)
    local cb2; cb2, y2 = U.MakeCheckbox(g2, "Only show when in a group", x, y2, nil, nil, 6)
    local s;   s,  y2 = U.MakeSlider(g2, "Global Frame Scale", 50, 150, 1, x, y2, nil, 0)
    lastL = U.EndGroup(g2, y2)
  end

  -- RIGHT COLUMN
  do
    local g, y = U.BeginGroup(colR, "Blizzard Frames", lastR)
    local cb; cb, y = U.MakeCheckbox(g, "Hide Blizzard Party Frames", x, y, nil, nil, 2)
    cb, y = U.MakeCheckbox(g, "Hide Blizzard Raid Frames",  x, y, nil, nil, 0)
    lastR = U.EndGroup(g, y)

    local g2, y2 = U.BeginGroup(colR, "Tooltips", lastR)
    local cb2; cb2, y2 = U.MakeCheckbox(g2, "Enable Tooltips", x, y2, nil, nil, 0)
    cb2, y2 = U.MakeCheckbox(g2, "Hide Tooltips in Combat", x, y2, nil, nil, 6)
    local dd; dd, y2 = U.MakeDropdown(g2, "Tooltip Anchor",
          {
            {text="Default (Blizzard)", value="DEFAULT"},
            {text="At Cursor",          value="CURSOR"},
            {text="Top Left of Cell",   value="TOPLEFT"},
            {text="Top Right of Cell",  value="TOPRIGHT"},
            {text="Bottom Left of Cell",value="BOTTOMLEFT"},
            {text="Bottom Right of Cell",value="BOTTOMRIGHT"},
          },
          function() return "DEFAULT" end,
          function(_) end,
          x, y2, U.DD_WIDTH, 0)
    lastR = U.EndGroup(g2, y2)
  end

  page:SetHeight(1000)
end
