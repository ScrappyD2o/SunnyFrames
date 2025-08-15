local ADDON, S = ...
S.UI = S.UI or {}
local U = S.UI

-- color helper
local function C(name)
  local c = S.UIColors and S.UIColors[name]
  if not c then return 1,0,1,1 end
  return c[1], c[2], c[3], c[4]
end

-- =================
-- Basic UI widgets
-- =================
U.ROW_H            = 24
U.SLIDER_BLOCK_H   = 56   -- a bit taller to fit the value box cleanly
U.DROPDOWN_BLOCK_H = 48
U.DD_WIDTH         = 220

function U.MakeLabel(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text or "")
  return fs
end

function U.MakeCheckbox(parent, label, x, y, onChange, tooltip, extraPad)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", x, y)
  cb:SetSize(24, 24)

  cb.Text:ClearAllPoints()
  cb.Text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
  cb.Text:SetText(label)
  cb:SetHitRectInsets(0, -8, 0, 0)

  if tooltip then cb.tooltip = tooltip end
  cb:SetScript("OnClick", function(self) if onChange then onChange(self:GetChecked()) end end)

  return cb, y - (U.ROW_H + (extraPad or 0))
end

-- revamp: shows numeric min/max; adds a small value editbox under the slider
function U.MakeSlider(parent, label, minVal, maxVal, step, x, y, onChange, extraPad, width)
  step = step or 1

  local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", x, y)
  title:SetText(label)

  local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", x, y - 16)
  slider:SetMinMaxValues(minVal, maxVal)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetWidth(width or 250)  -- <-- custom width supported

  -- Hide Blizzard defaults (works with/without a name)
  if slider.Low   then slider.Low:Hide()   end
  if slider.High  then slider.High:Hide()  end
  if slider.Text  then slider.Text:Hide()  end
  do
    local nm = slider:GetName()
    if nm then
      local low  = _G[nm.."Low"];  if low  then low:Hide()  end
      local high = _G[nm.."High"]; if high then high:Hide() end
      local text = _G[nm.."Text"]; if text then text:Hide() end
    end
  end

  -- Min / Max labels
  local lowFS  = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  local highFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lowFS:SetPoint("TOPLEFT",  slider, "BOTTOMLEFT",  0, -2)
  highFS:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
  lowFS:SetText(tostring(minVal))
  highFS:SetText(tostring(maxVal))

  -- Center value editbox (accepts negatives)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetNumeric(false)
  eb:SetSize(60, 18)
  eb:SetJustifyH("CENTER")
  eb:SetPoint("TOP", slider, "BOTTOM", 0, -2)

  local function clampStep(v)
    if not v then return nil end
    if v < minVal then v = minVal end
    if v > maxVal then v = maxVal end
    v = math.floor((v - minVal) / step + 0.5) * step + minVal
    if v < minVal then v = minVal end
    if v > maxVal then v = maxVal end
    return v
  end

  slider:SetScript("OnValueChanged", function(self, value)
    value = clampStep(value)
    if not value then return end
    if math.abs(self:GetValue() - value) > 1e-6 then
      self:SetValue(value)
      return
    end
    eb:SetText(tostring(value))
    if onChange then onChange(value) end
  end)

  local function commitFromEditBox()
    local txt = eb:GetText()
    if txt == "-" or txt == "" then
      eb:SetText(tostring(slider:GetValue()))
      eb:ClearFocus()
      return
    end
    local num = tonumber(txt)
    local value = clampStep(num)
    if value then slider:SetValue(value)
    else eb:SetText(tostring(slider:GetValue())) end
    eb:ClearFocus()
  end

  eb:SetScript("OnEnterPressed", commitFromEditBox)
  eb:SetScript("OnEditFocusLost", commitFromEditBox)
  eb:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(slider:GetValue()))
    self:ClearFocus()
  end)

  slider.title   = title
  slider.minText = lowFS
  slider.maxText = highFS
  slider.editBox = eb

  eb:SetText(tostring(slider:GetValue()))

  return slider, y - (U.SLIDER_BLOCK_H + (extraPad or 0))
end

function U.MakeDropdown(parent, label, items, getter, setter, x, y, width, extraPad)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(label)

  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", x - 16, y - 16)
  UIDropDownMenu_SetWidth(dd, width or U.DD_WIDTH)
  UIDropDownMenu_JustifyText(dd, "LEFT")

  UIDropDownMenu_Initialize(dd, function(self, level)
    for _, it in ipairs(items) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = it.text
      info.value = it.value
      info.checked = (getter() == it.value)
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dd, it.value)
        UIDropDownMenu_SetText(dd, it.text)
        if setter then setter(it.value) end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  function dd:Rebuild()
    local val = getter()
    UIDropDownMenu_SetSelectedValue(dd, val)
    for _, it in ipairs(items) do
      if it.value == val then UIDropDownMenu_SetText(dd, it.text); break end
    end
  end

  return dd, y - (U.DROPDOWN_BLOCK_H + (extraPad or 0))
end

function U.SetDropdownEnabled(dd, enabled)
  if enabled then
    UIDropDownMenu_EnableDropDown(dd)
    local txt = dd.Text or _G[(dd:GetName() or "") .. "Text"]
    if txt then txt:SetFontObject(GameFontHighlightSmall) end
  else
    UIDropDownMenu_DisableDropDown(dd)
    local txt = dd.Text or _G[(dd:GetName() or "") .. "Text"]
    if txt then txt:SetFontObject(GameFontDisableSmall) end
  end
end

-- =========================
-- Group boxes & two columns
-- =========================
local HEADER_H         = 22
local INNER_TOP_PAD    = 6
local INNER_BOTTOM_PAD = 6
local GROUP_STACK_GAP  = 16

function U.BeginGroup(parent, titleText, prev)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  if prev then
    box:SetPoint("TOPLEFT",  prev, "BOTTOMLEFT",  0, -GROUP_STACK_GAP)
    box:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -GROUP_STACK_GAP)
  else
    box:SetPoint("TOPLEFT",  parent, "TOPLEFT",   8, -10)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -10)
  end

  box:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    edgeSize = 1,
  })
  box:SetBackdropColor(C("panel"))
  box:SetBackdropBorderColor(C("border"))

  local titleBg = box:CreateTexture(nil, "BACKGROUND")
  titleBg:SetColorTexture(C("panelAlt"))
  titleBg:SetPoint("TOPLEFT", 1, -1)
  titleBg:SetPoint("TOPRIGHT", -1, -1)
  titleBg:SetHeight(HEADER_H)

  local titleFS = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleFS:SetPoint("LEFT", titleBg, "LEFT", 8, 0)
  titleFS:SetText(titleText or "")

  -- 1px divider under header (pixel-aligned)
  local divider = box:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(C("accent"))
  divider:SetAlpha(0.6)
  PixelUtil.SetPoint(divider, "TOPLEFT",  titleBg, "BOTTOMLEFT",  0, 0)
  PixelUtil.SetPoint(divider, "TOPRIGHT", titleBg, "BOTTOMRIGHT", 0, 0)
  PixelUtil.SetHeight(divider, 1)

  box._cursorY = -(HEADER_H + INNER_TOP_PAD)
  box._minY    = box._cursorY
  return box, box._cursorY
end

function U.EndGroup(box, innerY)
  box._minY = math.min(box._minY or innerY, innerY or 0)
  local innerHeight = math.abs(box._minY) + INNER_BOTTOM_PAD
  box:SetHeight(innerHeight)
  return box
end

-- Two-column container with center splitter (no overlap)
U.COL_GUTTER   = 16
U.COL_SIDE_PAD = 8
function U.CreateTwoColumnGrid(parent)
  local grid = CreateFrame("Frame", nil, parent)
  grid:SetPoint("TOPLEFT",     parent, "TOPLEFT",     U.COL_SIDE_PAD, -U.COL_SIDE_PAD)
  grid:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -U.COL_SIDE_PAD,  U.COL_SIDE_PAD)

  local split = CreateFrame("Frame", nil, grid)
  split:SetPoint("TOP",    grid, "TOP",    0, 0)
  split:SetPoint("BOTTOM", grid, "BOTTOM", 0, 0)
  split:SetWidth(1)

  local leftCol = CreateFrame("Frame", nil, grid)
  leftCol:SetPoint("TOPLEFT",    grid,  "TOPLEFT", 0, 0)
  leftCol:SetPoint("BOTTOMLEFT", grid,  "BOTTOMLEFT", 0, 0)
  leftCol:SetPoint("RIGHT",      split, "LEFT", -U.COL_GUTTER/2, 0)

  local rightCol = CreateFrame("Frame", nil, grid)
  rightCol:SetPoint("TOPRIGHT",    grid,  "TOPRIGHT", 0, 0)
  rightCol:SetPoint("BOTTOMRIGHT", grid,  "BOTTOMRIGHT", 0, 0)
  rightCol:SetPoint("LEFT",        split, "RIGHT", U.COL_GUTTER/2, 0)

  return grid, leftCol, rightCol
end

-- Simple placeholder used by other tabs
function U.Build_Placeholder(page, key)
  local y, x = -12, 12
  local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", x, y)
  title:SetText(("Tab: %s (placeholder)"):format(key))
  y = y - 24

  local info = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  info:SetPoint("TOPLEFT", x, y)
  info:SetText("This tab is not wired yet; layout only.")
  y = y - 20

  for i = 1, 20 do
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(("- line %02d -"):format(i))
    y = y - 16
  end

  page:SetHeight(math.abs(y) + 40)
end
