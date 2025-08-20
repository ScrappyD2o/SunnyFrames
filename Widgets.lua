local ADDON, S = ...
S.UI = S.UI or {}
local U = S.UI

-- ============
-- Color helper
-- ============
local function C(name)
    local c = S.UIColors and S.UIColors[name]
    if not c then
        return 1, 0, 1, 1
    end
    return c[1], c[2], c[3], c[4]
end

-- =================
-- Layout constants
-- =================
U.ROW_H = 24
U.SLIDER_BLOCK_H = 56
U.DROPDOWN_BLOCK_H = 48
U.DD_WIDTH = 220

local HEADER_H = 22
local INNER_TOP_PAD = 6
local INNER_BOTTOM_PAD = 6
local GROUP_STACK_GAP = 16
local LEFT_PAD = 16
local RIGHT_PAD = 16
local GAP = 32
local MAX_FULL = 140
local MAX_HALF = 140
local TEXT_PAD = 30

U.COL_GUTTER = 16
U.COL_SIDE_PAD = 8

-- =====================================
-- Small utility for flow/visibility args
-- =====================================
local function parseFlow(extraPad, base)
    if type(extraPad) == "table" then
        local pad = extraPad.extraPad or 0
        local vis = (extraPad.visible ~= false)
        return (base + pad), vis
    else
        return (base + (extraPad or 0)), true
    end
end

-- ===========================================
-- Group bookkeeping + reflow (shrink/expand)
-- ===========================================
function U.RegisterControl(groupBox, ctrl)
    if not groupBox or not ctrl then
        return
    end
    groupBox._controls = groupBox._controls or {}
    table.insert(groupBox._controls, ctrl)
    ctrl._group = groupBox
end

function U.RelayoutGroup(groupBox, controlsInOrder, startY)
    if not groupBox then
        return
    end
    local y = startY or groupBox._startY or 0
    local list = controlsInOrder or groupBox._controls or {}

    for _, ctrl in ipairs(list) do
        if ctrl and ctrl:IsShown() and not ctrl._noFlow then
            -- anchor leader
            if type(ctrl.Reanchor) == "function" then
                ctrl:Reanchor(y)
            end

            -- figure out row height (max of leader + any visible paired children)
            local rowBlockH = ctrl._blockH or 0

            if ctrl._paired then
                for _, p in ipairs(ctrl._paired) do
                    if p and p:IsShown() then
                        if type(p.Reanchor) == "function" then
                            p:Reanchor(y)
                        end
                        if p._blockH and p._blockH > rowBlockH then
                            rowBlockH = p._blockH
                        end
                    end
                end
            end

            y = y - rowBlockH
        end
    end

    return U.EndGroup(groupBox, y)
end

function U.PairRow(leftCtrl, ...)
    if not leftCtrl then
        return
    end
    leftCtrl._paired = leftCtrl._paired or {}
    local n = select('#', ...)
    for i = 1, n do
        local p = select(i, ...)
        if p then
            table.insert(leftCtrl._paired, p)
            -- mark the partner as "no flow": it is re-anchored by the row leader
            p._noFlow = true
        end
    end
end

-- =========================
-- Group boxes & two columns
-- =========================
function U.BeginGroup(parent, titleText, prev)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if prev then
        box:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -GROUP_STACK_GAP)
        box:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -GROUP_STACK_GAP)
    else
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -10)
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

    local divider = box:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(C("accent"))
    divider:SetAlpha(0.6)
    PixelUtil.SetPoint(divider, "TOPLEFT", titleBg, "BOTTOMLEFT", 0, 0)
    PixelUtil.SetPoint(divider, "TOPRIGHT", titleBg, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetHeight(divider, 1)

    box._cursorY = -(HEADER_H + INNER_TOP_PAD)
    box._minY = box._cursorY
    box._startY = box._cursorY
    box._controls = box._controls or {}

    return box, box._cursorY
end

function U.EndGroup(box, innerY)
    -- use the current flow result, not the historical minimum,
    -- so the group can shrink when controls are hidden
    box._minY = innerY or 0
    local innerHeight = math.abs(box._minY) + 6  -- INNER_BOTTOM_PAD
    box:SetHeight(innerHeight)
    return box
end

function U.CreateTwoColumnGrid(parent)
    local grid = CreateFrame("Frame", nil, parent)
    grid:SetPoint("TOPLEFT", parent, "TOPLEFT", U.COL_SIDE_PAD, -U.COL_SIDE_PAD)
    grid:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -U.COL_SIDE_PAD, U.COL_SIDE_PAD)

    local split = CreateFrame("Frame", nil, grid)
    split:SetPoint("TOP", grid, "TOP", 0, 0)
    split:SetPoint("BOTTOM", grid, "BOTTOM", 0, 0)
    split:SetWidth(1)

    local leftCol = CreateFrame("Frame", nil, grid)
    leftCol:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 0)
    leftCol:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, 0)
    leftCol:SetPoint("RIGHT", split, "LEFT", -U.COL_GUTTER / 2, 0)

    local rightCol = CreateFrame("Frame", nil, grid)
    rightCol:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, 0)
    rightCol:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, 0)
    rightCol:SetPoint("LEFT", split, "RIGHT", U.COL_GUTTER / 2, 0)

    return grid, leftCol, rightCol
end

function U.CalcWidths(box)
    local boxW = box:GetWidth()
    if not boxW or boxW <= 0 then
        boxW = 400
    end
    local usable = math.max(2 * MAX_HALF + GAP, boxW - LEFT_PAD - RIGHT_PAD)

    local halfW = math.min(MAX_HALF, math.floor((usable - GAP) / 2))
    local fullW = math.min(MAX_FULL, usable)
    local xLeft = LEFT_PAD
    local xRight = math.floor(usable / 2)

    return fullW, halfW, xLeft, xRight
end


-- =========
-- MakeLabel
-- =========
function U.MakeLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text or "")
    return fs
end

-- ======================
-- Simple placeholder tab
-- ======================
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

function U.SyncPartyFromDB()
    if not (S and S.Profile and S.Profile.party) then
        return
    end
    local p = S.Profile.party
    local W = U.widgets and U.widgets.party
    if not W then
        return
    end

    -- Guard so programmatic SetValue won't re-trigger sliders’ setters
    U._syncing = true
    if W.xSlider then
        W.xSlider:SetValue(tonumber(p.xPos) or 0)
    end
    if W.ySlider then
        W.ySlider:SetValue(tonumber(p.yPos) or 0)
    end

    -- Optional: keep these in lockstep too:
    if W.perSlider then
        if (p.orientation or "HORIZONTAL") == "HORIZONTAL" then
            W.perSlider:SetValue(tonumber(p.framesPerRow) or 5)
        else
            W.perSlider:SetValue(tonumber(p.framesPerColumn) or 5)
        end
    end
    if W.widthSlider then
        W.widthSlider:SetValue(tonumber(p.frameWidth) or 25)
    end
    if W.heightSlider then
        W.heightSlider:SetValue(tonumber(p.frameHeight) or 20)
    end
    U._syncing = false
end

-- Compute how far we can move the party container while keeping it on-screen
function U.CalcPartyOffsetLimits()
    local c  = _G.SunnyFramesPartyContainer
    local ui = UIParent
    if not (c and ui) then
        return -1000, 1000, -500, 500, 1
    end

    local uiW, uiH = ui:GetWidth() or 1920, ui:GetHeight() or 1080
    local cw,  ch  = c:GetWidth()  or 200,  c:GetHeight()  or 100
    local scale    = ui:GetEffectiveScale() or 1
    local step     = 1 / scale  -- one physical pixel in UI units

    local halfW = (uiW - cw) * 0.5
    local halfH = (uiH - ch) * 0.5

    -- Round to the same pixel grid as SavePosition (round-to-nearest pixel)
    local function quantMax(v)
        return (math.floor(v * scale + 0.5)) / scale
    end

    local maxX = quantMax(halfW)
    local maxY = quantMax(halfH)
    local minX = -maxX
    local minY = -maxY

    return minX, maxX, minY, maxY, step
end


-- Push fresh min/max to the Party position sliders (call after layout/refresh)
function U.UpdatePartyPositionSliderRanges()
    local W = U.widgets and U.widgets.party
    if not W then return end

    local minX, maxX, minY, maxY, step = U.CalcPartyOffsetLimits()

    U._syncing = true
    if W.xSlider and W.xSlider.ApplyRange then
        W.xSlider:ApplyRange(minX, maxX, step)
    elseif W.xSlider and W.xSlider.SetMinMaxValues then
        W.xSlider:SetMinMaxValues(minX, maxX)
        if W.xSlider.SetValueStep then W.xSlider:SetValueStep(step) end
        if W.xSlider.minText then W.xSlider.minText:SetText(U.FormatNumber(minX, step)) end
        if W.xSlider.maxText then W.xSlider.maxText:SetText(U.FormatNumber(maxX, step)) end
    end

    if W.ySlider and W.ySlider.ApplyRange then
        W.ySlider:ApplyRange(minY, maxY, step)
    elseif W.ySlider and W.ySlider.SetMinMaxValues then
        W.ySlider:SetMinMaxValues(minY, maxY)
        if W.ySlider.SetValueStep then W.ySlider:SetValueStep(step) end
        if W.ySlider.minText then W.ySlider.minText:SetText(U.FormatNumber(minY, step)) end
        if W.ySlider.maxText then W.ySlider.maxText:SetText(U.FormatNumber(maxY, step)) end
    end
    U._syncing = false

    -- Clamp DB into range and reflect into sliders/editboxes
    if S and S.Profile and S.Profile.party then
        local function snap(val, mn, mx, st)
            if val < mn then val = mn elseif val > mx then val = mx end
            if not st or st <= 0 then return val end
            return (math.floor((val - mn) / st + 0.5) * st + mn)
        end

        local px = tonumber(S.Profile.party.xPos) or 0
        local py = tonumber(S.Profile.party.yPos) or 0
        px = snap(px, minX, maxX, step)
        py = snap(py, minY, maxY, step)
        S.Profile.party.xPos = px
        S.Profile.party.yPos = py

        if W.xSlider and W.xSlider.SetValue then W.xSlider:SetValue(px) end
        if W.ySlider and W.ySlider.SetValue then W.ySlider:SetValue(py) end
        if W.xSlider and W.xSlider.editBox then W.xSlider.editBox:SetText(U.FormatNumber(px, step)) end
        if W.ySlider and W.ySlider.editBox then W.ySlider.editBox:SetText(U.FormatNumber(py, step)) end
    end

    -- Apply lock state: disable sliders AND their edit boxes
    local locked = S.Profile and S.Profile.general and S.Profile.general.lockFrames

    local function setEnabledDeep(slider, enabled)
        if not slider then return end
        if slider.SetEnabled then slider:SetEnabled(enabled) end
        if slider.editBox then
            if slider.editBox.ClearFocus then slider.editBox:ClearFocus() end
            if slider.editBox.SetEnabled then slider.editBox:SetEnabled(enabled) end
            if slider.editBox.EnableMouse then slider.editBox:EnableMouse(enabled) end
            -- match the visual gray-out with alpha
            if slider.editBox.SetAlpha then slider.editBox:SetAlpha(enabled and 1 or 0.4) end
        end
    end

    setEnabledDeep(W.xSlider, not locked)
    setEnabledDeep(W.ySlider, not locked)
end


-- Pretty-number formatter for sliders based on step resolution
function U.FormatNumber(val, step)
    if not step or step >= 1 then
        return tostring(math.floor(val + 0.5))
    end
    -- infer reasonable decimals from step, clamp to 2
    local decimals = math.min(2, math.max(1, math.ceil(-(math.log(step) / math.log(10)))))
    local s = string.format("%."..decimals.."f", val)
    -- trim trailing zeros and stray dot
    s = s:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    return s
end

-- Bound slider with CallbackRegistry events
-- usage:
--   local s = U.MakeBoundSlider(parent, "Horizontal Position",
--       minVal, maxVal, step, x, y, width, extraPad,
--       "party.xPos", or { path="party.xPos", section="party" }
--       { live=true, refresh=true, section="party" }  -- optional
--   )
--   s:RegisterCallback("ValueChanged",  function(self, value, meta) end, owner)
--   s:RegisterCallback("ValueCommitted",function(self, value, meta) end, owner)
function U.MakeBoundSlider(parent, label, minVal, maxVal, step, x, y, width, extraPad, configVar, opts)
    step = step or 1
    opts = opts or {}

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label or "")

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y - 16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(width or 250)

    -- Hide default labels
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

    local lowFS  = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local highFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lowFS:SetPoint("TOPLEFT",  slider, "BOTTOMLEFT",  0, -2)
    highFS:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    lowFS:SetText(U.FormatNumber(minVal, step))
    highFS:SetText(U.FormatNumber(maxVal, step))

    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetNumeric(false)
    eb:SetSize(60, 18)
    eb:SetJustifyH("CENTER")
    eb:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    -- Event dispatcher (Retail)
    Mixin(slider, CallbackRegistryMixin)
    slider:OnLoad()
    slider:GenerateCallbackEvents({ "ValueChanged", "ValueCommitted", "RangeChanged" })

    -- ------- Binding resolver -------
    local section = opts.section or (type(configVar)=="table" and configVar.section) or nil

    local function ensurePath(tbl, key)
        if not tbl[key] then tbl[key] = {} end
        return tbl[key]
    end

    local function resolvePath(root, path)
        local t = root
        local lastKey
        for seg in string.gmatch(path, "[^%.]+") do
            lastKey = seg
            if seg ~= lastKey then end -- appease luacheck
        end
        -- Walk until the last segment
        local prev = root
        for seg, dot in path:gmatch("([^%.]+)(%.?)") do
            if dot == "." then
                prev = ensurePath(prev, seg)
            else
                lastKey = seg
                return prev, lastKey
            end
        end
        return root, lastKey
    end

    local function makeRW()
        -- custom funcs win
        if type(configVar) == "table" and (configVar.get or configVar.set) then
            local get = configVar.get or function() return slider._value end
            local set = configVar.set or function(v) slider._value = v end
            return get, set
        end

        -- explicit table+key
        if type(configVar) == "table" and configVar.tbl and configVar.key then
            return function() return configVar.tbl[configVar.key] end,
            function(v)  configVar.tbl[configVar.key] = v end
        end

        -- **NEW**: table with .path (relative to S.Profile), e.g. { path="party.xPos" }
        if type(configVar) == "table" and type(configVar.path) == "string" then
            return function()
                if not (S and S.Profile) then return nil end
                local parentTbl, key = resolvePath(S.Profile, configVar.path)
                return parentTbl and parentTbl[key]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local parentTbl, key = resolvePath(S.Profile, configVar.path)
                if parentTbl then parentTbl[key] = v end
            end
        end

        -- plain string path, e.g. "party.xPos"
        if type(configVar) == "string" then
            return function()
                if not (S and S.Profile) then return nil end
                local parentTbl, key = resolvePath(S.Profile, configVar)
                return parentTbl and parentTbl[key]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local parentTbl, key = resolvePath(S.Profile, configVar)
                if parentTbl then parentTbl[key] = v end
            end
        end

        -- Fallback: internal value only
        return function() return slider._value end,
        function(v) slider._value = v end
    end


    local read, write = makeRW()
    -- default live/refresh
    local live    = (opts.live ~= false)
    local doRefresh = (opts.refresh ~= false)

    local function afterWrite()
        if section == "party" and S.ApplyPartyOffsets then
            S.ApplyPartyOffsets()
        end
        if section and S.NotifyProfileChanged then
            S.NotifyProfileChanged(section)
        end
        if doRefresh and S.Refresh then
            S.Refresh()
        end
    end

    -- ------- Utilities -------
    local suppressSetter = false
    local function curStep(self) return (self.GetValueStep and self:GetValueStep()) or step or 1 end
    local function clampStepDynamic(self, v)
        if v == nil then return nil end
        local curMin, curMax = self:GetMinMaxValues()
        local st = curStep(self)
        if v < curMin then v = curMin end
        if v > curMax then v = curMax end
        v = math.floor((v - curMin) / st + 0.5) * st + curMin
        if v < curMin then v = curMin end
        if v > curMax then v = curMax end
        return v
    end

    local function fmt(v) return U.FormatNumber(v, curStep(slider)) end

    -- ------- Behavior -------
    slider:SetScript("OnValueChanged", function(self, value)
        value = clampStepDynamic(self, value); if not value then return end
        if math.abs(self:GetValue() - value) > 1e-6 then self:SetValue(value); return end
        eb:SetText(fmt(value))

        -- Fire live event regardless
        self:TriggerEvent("ValueChanged", self, value, { fromUser = not U._syncing, isCommit = false })
        if type(opts.onValueChanged) == "function" then pcall(opts.onValueChanged, self, value, { fromUser = not U._syncing, isCommit = false }) end

        if suppressSetter or U._syncing then return end
        if live then
            write(value)
            afterWrite()
        else
            -- staged; commit on mouse up / enter
            slider._pending = value
        end
    end)

    -- Mouse-up commit (end of drag)
    slider:HookScript("OnMouseUp", function(self)
        if U._syncing then return end
        local value = clampStepDynamic(self, self:GetValue())
        if not live then
            write(value)
            afterWrite()
        end
        self:TriggerEvent("ValueCommitted", self, value, { fromUser = true, isCommit = true })
    end)

    -- Edit box commit
    local function commitFromEditBox()
        local txt = eb:GetText()
        if txt == "-" or txt == "" then
            eb:SetText(fmt(slider:GetValue()))
            eb:ClearFocus()
            return
        end
        local num = tonumber(txt)
        local value = clampStepDynamic(slider, num)
        if value then
            slider:SetValue(value)
            if not U._syncing then
                if not live then
                    write(value)
                    afterWrite()
                end
                slider:TriggerEvent("ValueCommitted", slider, value, { fromUser = true, isCommit = true })
            end
        else
            eb:SetText(fmt(slider:GetValue()))
        end
        eb:ClearFocus()
    end

    eb:SetScript("OnEnterPressed",  commitFromEditBox)
    eb:SetScript("OnEditFocusLost", commitFromEditBox)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(fmt(slider:GetValue())); self:ClearFocus() end)

    -- Public helpers (same surface as your other widgets)
    slider.title   = title
    slider.minText = lowFS
    slider.maxText = highFS
    slider.editBox = eb
    slider._enabled = true

    function slider:SetLabel(text) self.title:SetText(text or "") end

    function slider:Rebuild()
        local raw = read and read() or nil
        local default = (opts and opts.default) or 0
        local val = clampStepDynamic(self, raw ~= nil and raw or default)
        suppressSetter = true
        self:SetValue(val)
        if self.editBox then
            self.editBox:SetText(U.FormatNumber(val, (self.GetValueStep and self:GetValueStep()) or step or 1))
        end
        suppressSetter = false
    end

    function slider:SetEnabled(enabled)
        self._enabled = not not enabled
        if self._enabled then
            if self.Enable then self:Enable() end
            self:EnableMouse(true)
            if self.EnableMouseWheel then self:EnableMouseWheel(true) end
            if self.editBox then
                if self.editBox.Enable then self.editBox:Enable() end
                if self.editBox.SetEnabled then self.editBox:SetEnabled(true) end
                self.editBox:EnableMouse(true)
            end
            self:SetAlpha(1)
            if self.title   then self.title:SetFontObject(GameFontNormal) end
            if self.minText then self.minText:SetFontObject(GameFontHighlightSmall) end
            if self.maxText then self.maxText:SetFontObject(GameFontHighlightSmall) end
        else
            if self.Disable then self:Disable() end
            self:EnableMouse(false)
            if self.EnableMouseWheel then self:EnableMouseWheel(false) end
            if self.editBox then
                if self.editBox.Disable then self.editBox:Disable() end
                if self.editBox.SetEnabled then self.editBox:SetEnabled(false) end
                self.editBox:EnableMouse(false)
            end
            self:SetAlpha(0.4)
            if self.title   then self.title:SetFontObject(GameFontDisable) end
            if self.minText then self.minText:SetFontObject(GameFontDisableSmall) end
            if self.maxText then self.maxText:SetFontObject(GameFontDisableSmall) end
        end
    end

    function slider:SetVisible(visible)
        if visible then
            self:Show(); if self.title then self.title:Show() end
            if self.minText then self.minText:Show() end
            if self.maxText then self.maxText:Show() end
            if self.editBox then self.editBox:Show() end
            if self.Rebuild then self:Rebuild() end
        else
            self:Hide(); if self.title then self.title:Hide() end
            if self.minText then self.minText:Hide() end
            if self.maxText then self.maxText:Hide() end
            if self.editBox then self.editBox:Hide() end
        end
        if self._group and U.RelayoutGroup then
            U.RelayoutGroup(self._group, self._group._controls, self._group._startY)
        end
    end

    -- Range updater (fires RangeChanged)
    function slider:ApplyRange(minV, maxV, stp)
        stp = stp or curStep(self)
        U._syncing = true
        self:SetMinMaxValues(minV, maxV)
        if self.SetValueStep then self:SetValueStep(stp) end
        if self.minText then self.minText:SetText(U.FormatNumber(minV, stp)) end
        if self.maxText then self.maxText:SetText(U.FormatNumber(maxV, stp)) end
        U._syncing = false
        self:TriggerEvent("RangeChanged", self, { min=minV, max=maxV, step=stp })
        -- snap current value to new range
        self:Rebuild()
    end

    -- Flow integration like your other widgets
    local blockH, initiallyVisible = parseFlow(extraPad, U.SLIDER_BLOCK_H)
    slider._blockH = blockH
    slider._parent = parent
    slider._x      = x
    function slider:Reanchor(newY)
        if self.title then
            self.title:ClearAllPoints()
            self.title:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY)
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY - 16)
    end
    function slider:GetFlowY(prevY)
        return (self:IsShown() and (prevY - self._blockH)) or prevY
    end

    U.RegisterControl(parent, slider)
    if not initiallyVisible then
        slider:SetVisible(false)
        return slider, y
    end

    -- Initial value from binding/default
    slider._value = minVal
    slider:Rebuild()
    return slider, y - slider._blockH
end

-- Bound checkbox with Retail CallbackRegistry events
-- API:
--   local cb, nextY = U.MakeBoundCheckbox(parent, label, x, y, extraPad,
--                                         configVar,           -- { path="party.showPets", section="party" } | {tbl=...,key=...} | {get=...,set=...,section=...} | "party.showPets"
--                                         opts)               -- { refresh=true/false, default=false }
-- Subscribe:
--   cb:RegisterCallback("ValueChanged", function(self, checked, meta) end, owner)
function U.MakeBoundCheckbox(parent, label, x, y, extraPad, configVar, opts)
    opts = opts or {}

    -- Create
    local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)

    cb.Text:ClearAllPoints()
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    cb.Text:SetText(label or "")
    cb:SetHitRectInsets(0, -8, 0, 0)

    -- Events (Retail)
    Mixin(cb, CallbackRegistryMixin)
    cb:OnLoad()
    cb:GenerateCallbackEvents({ "ValueChanged" })

    -- Section / refresh behavior
    local section    = opts.section or (type(configVar)=="table" and configVar.section) or nil
    local doRefresh  = (opts.refresh ~= false)  -- default true

    local function afterWrite()
        if section and S.NotifyProfileChanged then
            S.NotifyProfileChanged(section)
        end
        if doRefresh and S.Refresh then
            S.Refresh()
        end
    end

    -- Path resolver (relative to S.Profile for string paths)
    local function ensurePath(tbl, key)
        if not tbl[key] then tbl[key] = {} end
        return tbl[key]
    end
    local function resolvePath(root, path)  -- returns parentTbl, lastKey
        local parent = root
        local last
        for seg, dot in path:gmatch("([^%.]+)(%.?)") do
            if dot == "." then
                parent = ensurePath(parent, seg)
            else
                last = seg
                return parent, last
            end
        end
        return root, path
    end

    -- Binding: read/write resolvers
    local function makeRW()
        -- custom get/set
        if type(configVar)=="table" and (configVar.get or configVar.set) then
            local get = configVar.get or function() return cb._checked end
            local set = configVar.set or function(v) cb._checked = not not v end
            return get, set
        end
        -- table+key
        if type(configVar)=="table" and configVar.tbl and configVar.key then
            return function() return not not configVar.tbl[configVar.key] end,
            function(v) configVar.tbl[configVar.key] = not not v end
        end
        -- table with .path (relative to S.Profile)
        if type(configVar)=="table" and type(configVar.path)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar.path)
                return p and not not p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar.path)
                if p then p[k] = not not v end
            end
        end
        -- plain string path (relative to S.Profile)
        if type(configVar)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar)
                return p and not not p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar)
                if p then p[k] = not not v end
            end
        end
        -- fallback internal state
        return function() return cb._checked end,
        function(v) cb._checked = not not v end
    end

    local read, write = makeRW()

    -- Guard to avoid re-entrant setter when programmatically syncing UI
    local suppressSetter = false

    -- Click -> write -> refresh -> event
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        if not suppressSetter and not U._syncing then
            write(checked)
            afterWrite()
        end
        self:TriggerEvent("ValueChanged", self, checked, { fromUser = true })
    end)

    -- Public API
    function cb:SetLabel(text)
        self.Text:SetText(text or "")
    end

    function cb:Rebuild()
        local v = read and read()
        if v == nil then v = (opts.default ~= nil) and opts.default or false end
        suppressSetter = true
        self:SetChecked(not not v)
        suppressSetter = false
    end

    function cb:SetEnabled(enabled)
        if enabled then
            self:Enable(); self:SetAlpha(1)
            self.Text:SetFontObject(GameFontNormal)
        else
            self:Disable(); self:SetAlpha(0.4)
            self.Text:SetFontObject(GameFontDisable)
        end
    end

    function cb:SetVisible(visible)
        if visible then
            self:Show(); if self.Text then self.Text:Show() end
            if self.Rebuild then self:Rebuild() end
        else
            self:Hide(); if self.Text then self.Text:Hide() end
        end
        if self._group and U.RelayoutGroup then
            U.RelayoutGroup(self._group, self._group._controls, self._group._startY)
        end
    end

    function cb:SetValue(checked, fireEvent)
        checked = not not checked
        suppressSetter = true
        self:SetChecked(checked)
        suppressSetter = false
        if not U._syncing then
            write(checked)
            afterWrite()
            if fireEvent then
                self:TriggerEvent("ValueChanged", self, checked, { fromUser = false })
            end
        end
    end

    -- Flow integration
    local blockH, initiallyVisible = (function()
        local bh, vis = parseFlow(extraPad, U.ROW_H)
        cb._blockH = bh
        return bh, vis
    end)()

    cb._parent = parent
    cb._x      = x
    function cb:Reanchor(newY)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY)
        if self.Text then
            self.Text:ClearAllPoints()
            self.Text:SetPoint("LEFT", self, "RIGHT", 6, 0)
        end
    end
    function cb:GetFlowY(prevY)
        return (self:IsShown() and (prevY - self._blockH)) or prevY
    end

    U.RegisterControl(parent, cb)
    if not initiallyVisible then
        cb:SetVisible(false)
        return cb, y
    end

    -- Init from binding/default
    cb._checked = false
    cb:Rebuild()

    return cb, y - cb._blockH
end

-- Bound dropdown (Retail) with callback events
-- API:
--   local dd, nextY = U.MakeBoundDropdown(parent, label, items, x, y, width, extraPad,
--                                         configVar,              -- { path="party.sortingOrder", section="party" } | {tbl=...,key=...} | {get=...,set=...,section=...} | "party.sortingOrder"
--                                         opts)                   -- { refresh=true/false, default=value }
-- Subscribe:
--   dd:RegisterCallback("ValueChanged", function(self, value, meta) end, owner)

function U.MakeBoundDropdown(parent, label, items, x, y, width, extraPad, configVar, opts)
    opts = opts or {}
    items = items or {}

    -- Label
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(label or "")

    -- Dropdown
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x - 16, y - 16)
    UIDropDownMenu_SetWidth(dd, width or U.DD_WIDTH)
    UIDropDownMenu_JustifyText(dd, "LEFT")

    -- Events
    Mixin(dd, CallbackRegistryMixin)
    dd:OnLoad()
    dd:GenerateCallbackEvents({ "ValueChanged" })

    -- Behavior toggles
    local section   = opts.section or (type(configVar)=="table" and configVar.section) or nil
    local doRefresh = (opts.refresh ~= false)  -- default true

    local function afterWrite()
        if section and S.NotifyProfileChanged then S.NotifyProfileChanged(section) end
        if doRefresh and S.Refresh then S.Refresh() end
    end

    -- Helpers
    local function getTextRegion(frame)
        return frame.Text or (frame:GetName() and _G[frame:GetName().."Text"]) or nil
    end

    local function findItemByValue(val)
        for _, it in ipairs(items) do
            if it.value == val then return it end
        end
    end

    local function applySelected(value)
        UIDropDownMenu_SetSelectedValue(dd, value)
        local it = findItemByValue(value)
        UIDropDownMenu_SetText(dd, it and it.text or "")
    end

    -- Path resolver (relative to S.Profile)
    local function ensurePath(tbl, key)
        if not tbl[key] then tbl[key] = {} end
        return tbl[key]
    end
    local function resolvePath(root, path) -- returns parent, lastKey
        local parent = root
        local last
        for seg, dot in path:gmatch("([^%.]+)(%.?)") do
            if dot == "." then
                parent = ensurePath(parent, seg)
            else
                last = seg
                return parent, last
            end
        end
        return root, path
    end

    -- Binding resolver
    local function makeRW()
        -- custom get/set
        if type(configVar)=="table" and (configVar.get or configVar.set) then
            local get = configVar.get or function() return dd._value end
            local set = configVar.set or function(v) dd._value = v end
            return get, set
        end
        -- explicit table+key
        if type(configVar)=="table" and configVar.tbl and configVar.key then
            return function() return configVar.tbl[configVar.key] end,
            function(v)  configVar.tbl[configVar.key] = v end
        end
        -- table with .path (relative to S.Profile)
        if type(configVar)=="table" and type(configVar.path)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar.path)
                return p and p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar.path)
                if p then p[k] = v end
            end
        end
        -- plain string path
        if type(configVar)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar)
                return p and p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar)
                if p then p[k] = v end
            end
        end
        -- fallback internal
        return function() return dd._value end,
        function(v) dd._value = v end
    end

    local read, write = makeRW()
    local suppressSetter = false

    -- Populate & behavior
    UIDropDownMenu_Initialize(dd, function(self, level)
        local currentVal = read and read() or UIDropDownMenu_GetSelectedValue(dd)
        for _, it in ipairs(items) do
            local info   = UIDropDownMenu_CreateInfo()
            info.text    = it.text
            info.value   = it.value
            info.checked = (currentVal == it.value)
            info.func = function()
                suppressSetter = true
                applySelected(it.value)
                suppressSetter = false

                if not U._syncing then
                    write(it.value)
                    afterWrite()
                end
                dd:TriggerEvent("ValueChanged", dd, it.value, { fromUser = true })
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Public API
    dd.label = fs
    function dd:SetLabel(text)
        if self.label then self.label:SetText(text or "") end
    end

    function dd:Rebuild()
        local val = read and read()
        if val == nil then val = opts.default end
        suppressSetter = true
        applySelected(val)
        suppressSetter = false
    end

    function dd:SetEnabled(enabled)
        if enabled then
            UIDropDownMenu_EnableDropDown(self)
            local txt = getTextRegion(self)
            if txt then txt:SetFontObject(GameFontHighlightSmall) end
            if self.label then self.label:SetFontObject(GameFontNormal) end
        else
            UIDropDownMenu_DisableDropDown(self)
            local txt = getTextRegion(self)
            if txt then txt:SetFontObject(GameFontDisableSmall) end
            if self.label then self.label:SetFontObject(GameFontDisable) end
        end
    end

    function dd:SetVisible(visible)
        if visible then
            self:Show(); if self.label then self.label:Show() end
            if self.Rebuild then self:Rebuild() end
        else
            self:Hide(); if self.label then self.label:Hide() end
        end
        if self._group and U.RelayoutGroup then
            U.RelayoutGroup(self._group, self._group._controls, self._group._startY)
        end
    end

    function dd:SetItems(newItems)
        items = newItems or {}
        self:Rebuild()
    end

    function dd:SetValue(value, fireEvent)
        suppressSetter = true
        applySelected(value)
        suppressSetter = false
        if not U._syncing then
            write(value)
            afterWrite()
            if fireEvent then
                dd:TriggerEvent("ValueChanged", dd, value, { fromUser = false })
            end
        end
    end

    -- Flow integration
    local blockH, initiallyVisible = parseFlow(extraPad, U.DROPDOWN_BLOCK_H)
    dd._blockH = blockH

    dd._parent = parent
    dd._x      = x
    function dd:Reanchor(newY)
        if self.label then
            self.label:ClearAllPoints()
            self.label:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY)
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x - 16, newY - 16)
    end

    function dd:GetFlowY(prevY)
        return (self:IsShown() and (prevY - self._blockH)) or prevY
    end

    U.RegisterControl(parent, dd)
    if not initiallyVisible then
        dd:SetVisible(false)
        return dd, y
    end

    -- Init from binding/default
    dd._value = opts.default
    dd:Rebuild()

    return dd, y - dd._blockH
end

-- Bound texture dropdown (Retail) with swatch preview + events
-- API:
--   local dd, nextY = U.MakeBoundTextureDropdown(parent, label, items, x, y, width, extraPad,
--                                                configVar,                -- { path="party.barTexture", section="party" } | {tbl=...,key=...} | {get=...,set=...,section=...} | "party.barTexture"
--                                                opts)                     -- { refresh=true/false, default=value }
-- Subscribe:
--   dd:RegisterCallback("ValueChanged", function(self, value, meta) end, owner)
function U.MakeBoundTextureDropdown(parent, label, items, x, y, width, extraPad, configVar, opts)
    opts   = opts   or {}
    items  = items  or {}
    width  = width  or U.DD_WIDTH

    -- Label
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(label or "")

    -- Dropdown
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x - 16, y - 16)
    UIDropDownMenu_SetWidth(dd, width)
    UIDropDownMenu_JustifyText(dd, "LEFT")

    -- Events
    Mixin(dd, CallbackRegistryMixin)
    dd:OnLoad()
    dd:GenerateCallbackEvents({ "ValueChanged" })

    -- Behavior toggles
    local section   = opts.section or (type(configVar)=="table" and configVar.section) or nil
    local doRefresh = (opts.refresh ~= false)  -- default true

    local function afterWrite()
        if section and S.NotifyProfileChanged then S.NotifyProfileChanged(section) end
        if doRefresh and S.Refresh then S.Refresh() end
    end

    -- Swatch helpers
    local ROW_H  = 20
    local SW_H   = ROW_H - 6
    local SW_W   = math.max(40, width - 90)
    local function swatchInline(texPath)
        texPath = texPath or ""
        return ("|T%s:%d:%d:0:0|t"):format(texPath, SW_H, SW_W)
    end

    -- Text region helper
    local function getTextRegion(frame)
        return frame.Text or (frame:GetName() and _G[frame:GetName().."Text"]) or nil
    end

    local function findItemByValue(val)
        for _, it in ipairs(items) do
            if it.value == val then return it end
        end
    end

    local function applySelected(value)
        UIDropDownMenu_SetSelectedValue(dd, value)
        local it = findItemByValue(value)
        if it then
            UIDropDownMenu_SetText(dd, swatchInline(it.value) .. " " .. (it.text or it.value))
        else
            UIDropDownMenu_SetText(dd, "")
        end
    end

    -- Path resolver (relative to S.Profile)
    local function ensurePath(tbl, key)
        if not tbl[key] then tbl[key] = {} end
        return tbl[key]
    end
    local function resolvePath(root, path) -- returns parent, lastKey
        local parent = root
        local last
        for seg, dot in path:gmatch("([^%.]+)(%.?)") do
            if dot == "." then
                parent = ensurePath(parent, seg)
            else
                last = seg
                return parent, last
            end
        end
        return root, path
    end

    -- Binding resolver
    local function makeRW()
        -- custom get/set
        if type(configVar)=="table" and (configVar.get or configVar.set) then
            local get = configVar.get or function() return dd._value end
            local set = configVar.set or function(v) dd._value = v end
            return get, set
        end
        -- explicit table+key
        if type(configVar)=="table" and configVar.tbl and configVar.key then
            return function() return configVar.tbl[configVar.key] end,
            function(v)  configVar.tbl[configVar.key] = v end
        end
        -- table with .path (relative to S.Profile)
        if type(configVar)=="table" and type(configVar.path)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar.path)
                return p and p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar.path)
                if p then p[k] = v end
            end
        end
        -- plain string path
        if type(configVar)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar)
                return p and p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar)
                if p then p[k] = v end
            end
        end
        -- fallback internal
        return function() return dd._value end,
        function(v) dd._value = v end
    end

    local read, write = makeRW()
    local suppressSetter = false

    -- Populate menu
    UIDropDownMenu_Initialize(dd, function(self, level)
        local currentVal = (read and read()) or UIDropDownMenu_GetSelectedValue(dd)
        for _, it in ipairs(items) do
            local info        = UIDropDownMenu_CreateInfo()
            info.text         = swatchInline(it.value) .. " " .. (it.text or it.value)
            info.value        = it.value
            info.checked      = (currentVal == it.value)
            info.minWidth     = 0
            info.notCheckable = false
            info.func = function()
                suppressSetter = true
                applySelected(it.value)
                suppressSetter = false

                if not U._syncing then
                    write(it.value)
                    afterWrite()
                end
                dd:TriggerEvent("ValueChanged", dd, it.value, { fromUser = true })
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Public API
    dd.label = fs

    function dd:SetLabel(text)
        if self.label then self.label:SetText(text or "") end
    end

    function dd:Rebuild()
        local val = read and read()
        if val == nil then val = opts.default end
        suppressSetter = true
        applySelected(val)
        suppressSetter = false
    end

    function dd:SetEnabled(enabled)
        if enabled then
            UIDropDownMenu_EnableDropDown(self)
            local txt = getTextRegion(self)
            if txt then txt:SetFontObject(GameFontHighlightSmall) end
            if self.label then self.label:SetFontObject(GameFontNormal) end
        else
            UIDropDownMenu_DisableDropDown(self)
            local txt = getTextRegion(self)
            if txt then txt:SetFontObject(GameFontDisableSmall) end
            if self.label then self.label:SetFontObject(GameFontDisable) end
        end
    end

    function dd:SetVisible(visible)
        if visible then
            self:Show(); if self.label then self.label:Show() end
            if self.Rebuild then self:Rebuild() end
        else
            self:Hide(); if self.label then self.label:Hide() end
        end
        if self._group and U.RelayoutGroup then
            U.RelayoutGroup(self._group, self._group._controls, self._group._startY)
        end
    end

    function dd:SetItems(newItems)
        items = newItems or {}
        -- No need to re-init now; menu builds on open. Just refresh the shown text.
        self:Rebuild()
    end

    function dd:SetValue(value, fireEvent)
        suppressSetter = true
        applySelected(value)
        suppressSetter = false
        if not U._syncing then
            write(value)
            afterWrite()
            if fireEvent then
                dd:TriggerEvent("ValueChanged", dd, value, { fromUser = false })
            end
        end
    end

    -- Flow integration
    local blockH, initiallyVisible = parseFlow(extraPad, U.DROPDOWN_BLOCK_H)
    dd._blockH = blockH

    dd._parent = parent
    dd._x      = x
    function dd:Reanchor(newY)
        if self.label then
            self.label:ClearAllPoints()
            self.label:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY)
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x - 16, newY - 16)
    end

    function dd:GetFlowY(prevY)
        return (self:IsShown() and (prevY - self._blockH)) or prevY
    end

    U.RegisterControl(parent, dd)
    if not initiallyVisible then
        dd:SetVisible(false)
        return dd, y
    end

    -- Init from binding/default
    dd._value = opts.default
    dd:Rebuild()

    return dd, y - dd._blockH
end

-- Bound color picker (Retail) with events + alpha
-- API:
--   local cp, nextY = U.MakeBoundColorPicker(parent, label, x, y, extraPad,
--                                            configVar,              -- { path="party.healthColor", section="party" } | {tbl=...,key=...} | {get=...,set=...,section=...} | "party.healthColor"
--                                            opts)                   -- { refresh=true/false, default={r,g,b,a}, live=true/false }
-- Subscribe:
--   cp:RegisterCallback("ValueChanged",  function(self, r,g,b,a, meta) end, owner)
--   cp:RegisterCallback("ValueCommitted",function(self, r,g,b,a, meta) end, owner)
function U.MakeBoundColorPicker(parent, label, x, y, extraPad, configVar, opts)
    opts = opts or {}

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(label or "")

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetPoint("TOPLEFT", x, y - 18)
    btn:SetSize(28, 18)
    btn:SetBackdrop({ bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1 })
    btn:SetBackdropBorderColor(C("border"))
    local swatch = btn:CreateTexture(nil, "ARTWORK"); swatch:SetAllPoints(btn)

    -- Events
    Mixin(btn, CallbackRegistryMixin)
    btn:OnLoad()
    btn:GenerateCallbackEvents({ "ValueChanged", "ValueCommitted" })

    -- Behavior toggles
    local section   = opts.section or (type(configVar)=="table" and configVar.section) or nil
    local doRefresh = (opts.refresh ~= false)  -- default true
    local live      = (opts.live ~= false)     -- default true (write as you drag)

    local function afterWrite()
        if section and S.NotifyProfileChanged then S.NotifyProfileChanged(section) end
        if doRefresh and S.Refresh then S.Refresh() end
    end

    -- Path helpers
    local function ensurePath(tbl, key) if not tbl[key] then tbl[key] = {} end; return tbl[key] end
    local function resolvePath(root, path) -- returns parent, lastKey
        local parent = root
        for seg, dot in path:gmatch("([^%.]+)(%.?)") do
            if dot == "." then parent = ensurePath(parent, seg) else return parent, seg end
        end
        return root, path
    end

    -- Binding (colors may be stored as table {r,g,b,a}; custom set can be set(r,g,b,a))
    local function makeRW()
        -- custom get/set
        if type(configVar)=="table" and (configVar.get or configVar.set) then
            local get = configVar.get or function() return btn._r,btn._g,btn._b,btn._a end
            local set = configVar.set or function(r,g,b,a) btn._r,btn._g,btn._b,btn._a = r,g,b,a end
            return get, set, "custom"
        end

        -- explicit table+key (store as {r,g,b,a})
        if type(configVar)=="table" and configVar.tbl and configVar.key then
            return function()
                local v = configVar.tbl[configVar.key]
                if type(v)=="table" then
                    local r = v[1] or 1
                    local g = v[2] or 1
                    local b = v[3] or 1
                    local a = v[4]; if a==nil then a=1 end
                    return r,g,b,a
                end
                return nil
            end,
            function(r,g,b,a)
                configVar.tbl[configVar.key] = { r or 1, g or 1, b or 1, (a~=nil and a or 1) }
            end,
            "table"
        end

        -- table with .path (relative to S.Profile)
        if type(configVar)=="table" and type(configVar.path)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar.path)
                local v = p and p[k]
                if type(v)=="table" then
                    local r = v[1] or 1
                    local g = v[2] or 1
                    local b = v[3] or 1
                    local a = v[4]; if a==nil then a=1 end
                    return r,g,b,a
                end
                return nil
            end,
            function(r,g,b,a)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar.path)
                if p then p[k] = { r or 1, g or 1, b or 1, (a~=nil and a or 1) } end
            end,
            "table"
        end

        -- plain string path (relative to S.Profile)
        if type(configVar)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar)
                local v = p and p[k]
                if type(v)=="table" then
                    local r = v[1] or 1
                    local g = v[2] or 1
                    local b = v[3] or 1
                    local a = v[4]; if a==nil then a=1 end
                    return r,g,b,a
                end
                return nil
            end,
            function(r,g,b,a)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar)
                if p then p[k] = { r or 1, g or 1, b or 1, (a~=nil and a or 1) } end
            end,
            "table"
        end

        -- fallback
        return function() return btn._r,btn._g,btn._b,btn._a end,
        function(r,g,b,a) btn._r,btn._g,btn._b,btn._a = r,g,b,a end,
        "custom"
    end


    local read, write, bindKind = makeRW()

    local suppressSetter = false
    local openedSessionCanceled = false

    local function applyRGBA(r,g,b,a, writeNow, fromUser)
        r = r or 1; g = g or 1; b = b or 1; a = (a ~= nil) and a or 1
        swatch:SetColorTexture(r,g,b,a)
        if not suppressSetter and not U._syncing and writeNow then
            write(r,g,b,a)
            afterWrite()
        end
        btn:TriggerEvent("ValueChanged", btn, r,g,b,a, { fromUser = fromUser and true or false, live = true })
    end

    local function BringPickerToFront()
        local top = _G.SunnyFramesConfigUI
        ColorPickerFrame:SetParent(UIParent)
        ColorPickerFrame:SetToplevel(true)
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        local base = (top and top:GetFrameLevel()) or 1000
        ColorPickerFrame:SetFrameLevel(math.min(65535, base + 50))
        ColorPickerFrame:Raise()
    end

    local function readRGBA()
        local r,g,b,a
        if read then r,g,b,a = read() end
        if r == nil then
            local d = opts.default
            if type(d)=="table" then
                r = d[1] or 1; g = d[2] or 1; b = d[3] or 1; a = (d[4] ~= nil and d[4] or 1)
            else
                r,g,b,a = 1,1,1,1
            end
        else
            if g == nil then g = 1 end
            if b == nil then b = 1 end
            if a == nil then a = 1 end
        end
        return r,g,b,a
    end

    local function openPicker()
        local r,g,b,a = readRGBA()
        local opacity = 1 - (a or 1)
        openedSessionCanceled = false

        local function onSwatch()
            local nr,ng,nb = ColorPickerFrame:GetColorRGB()
            local na = 1 - (ColorPickerFrame.opacity or 0)
            applyRGBA(nr,ng,nb,na, live, true)
        end
        local function onOpacity()
            local nr,ng,nb = ColorPickerFrame:GetColorRGB()
            local na = 1 - (ColorPickerFrame.opacity or 0)
            applyRGBA(nr,ng,nb,na, live, true)
        end
        local function onCancel(prev)
            openedSessionCanceled = true
            local pr,pg,pb,po = unpack(prev)   -- po is opacity (1-a)
            local pa = 1 - (po or 0)
            suppressSetter = true
            applyRGBA(pr,pg,pb,pa, live, true) -- visually revert + emit ValueChanged
            suppressSetter = false
            -- ensure model is reverted too
            if not U._syncing then
                write(pr,pg,pb,pa)
                afterWrite()
            end
            btn:TriggerEvent("ValueCommitted", btn, pr,pg,pb,pa, { fromUser = true, canceled = true })
        end

        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            BringPickerToFront()
            ColorPickerFrame:SetupColorPickerAndShow({
                r=r, g=g, b=b, hasOpacity=true, opacity=opacity,
                previousValues={ r, g, b, opacity },
                swatchFunc  = onSwatch,
                opacityFunc = onOpacity,
                cancelFunc  = onCancel,
            })
        else
            BringPickerToFront()
            OpenColorPicker({
                r=r, g=g, b=b, hasOpacity=true, opacity=opacity,
                previousValues={ r, g, b, opacity },
                swatchFunc  = onSwatch,
                opacityFunc = onOpacity,
                cancelFunc  = onCancel,
            })
        end

        -- Commit when picker closes (if not canceled)
        ColorPickerFrame:HookScript("OnHide", function()
            if openedSessionCanceled then return end
            local nr,ng,nb = ColorPickerFrame:GetColorRGB()
            local na = 1 - (ColorPickerFrame.opacity or 0)
            if not live then
                -- write once on commit
                write(nr,ng,nb,na)
                afterWrite()
            end
            btn:TriggerEvent("ValueCommitted", btn, nr,ng,nb,na, { fromUser = true, canceled = false })
        end)
    end

    btn:SetScript("OnClick", openPicker)

    -- Public API
    btn.label  = fs
    btn.swatch = swatch

    function btn:SetLabel(text)
        if self.label then self.label:SetText(text or "") end
    end

    function btn:Rebuild()
        local r,g,b,a = readRGBA()
        suppressSetter = true
        swatch:SetColorTexture(r,g,b,a)
        suppressSetter = false
    end

    function btn:SetEnabled(enabled)
        if enabled then
            self:Enable(); self:SetAlpha(1)
            if self.label then self.label:SetFontObject(GameFontNormal) end
        else
            self:Disable(); self:SetAlpha(0.4)
            if self.label then self.label:SetFontObject(GameFontDisable) end
        end
    end

    function btn:SetVisible(visible)
        if visible then
            self:Show(); if self.label then self.label:Show() end
            if self.Rebuild then self:Rebuild() end
        else
            self:Hide(); if self.label then self.label:Hide() end
        end
        if self._group and U.RelayoutGroup then
            U.RelayoutGroup(self._group, self._group._controls, self._group._startY)
        end
    end

    function btn:SetColor(r,g,b,a, fireEvent)
        suppressSetter = true
        swatch:SetColorTexture(r or 1, g or 1, b or 1, (a~=nil and a or 1))
        suppressSetter = false
        if not U._syncing then
            write(r,g,b,a)
            afterWrite()
            if fireEvent then
                btn:TriggerEvent("ValueChanged", btn, r,g,b,(a~=nil and a or 1), { fromUser = false, live = false })
                btn:TriggerEvent("ValueCommitted", btn, r,g,b,(a~=nil and a or 1), { fromUser = false, canceled = false })
            end
        end
    end

    -- Flow integration
    local blockH, initiallyVisible = parseFlow(extraPad, U.DROPDOWN_BLOCK_H)
    btn._blockH = blockH

    btn._parent = parent
    btn._x      = x
    function btn:Reanchor(newY)
        if self.label then
            self.label:ClearAllPoints()
            self.label:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY)
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY - 18)
    end
    function btn:GetFlowY(prevY)
        return (self:IsShown() and (prevY - self._blockH)) or prevY
    end

    U.RegisterControl(parent, btn)
    if not initiallyVisible then
        btn:SetVisible(false)
        return btn, y
    end

    -- Init from binding/default
    local dr,dg,db,da = 1,1,1,1
    if opts.default and type(opts.default)=="table" then
        dr = opts.default[1] or 1; dg = opts.default[2] or 1; db = opts.default[3] or 1; da = (opts.default[4]~=nil and opts.default[4] or 1)
    end
    btn._r,btn._g,btn._b,btn._a = dr,dg,db,da
    btn:Rebuild()

    return btn, y - btn._blockH
end

-- Bound input field (Retail) with validation + events
-- API:
--   local eb, nextY = U.MakeBoundInputField(parent, label, x, y, width, extraPad,
--                                           configVar,              -- { path="party.title", section="party" } | {tbl=...,key=...} | {get=...,set=...,section=...} | "party.title"
--                                           opts)                   -- { refresh=true/false, default="", placeholder="", trim=true,
--                                                                   --   numeric=true/false, integer=true/false, min=..., max=..., pattern="^...$",
--                                                                   --   validator=function(txt)-> ok[, normalized], maxLetters=..., live=false/true }
-- Subscribe:
--   eb:RegisterCallback("ValueChanged",   function(self, textOrNumber, meta) end, owner)
--   eb:RegisterCallback("ValueCommitted", function(self, textOrNumber, meta) end, owner)
function U.MakeBoundInputField(parent, label, x, y, width, extraPad, configVar, opts)
    opts  = opts or {}
    width = width or 160

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(label or "")

    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", x, y - 16)
    eb:SetSize(width, 20)
    eb:SetAutoFocus(false)
    eb:SetNumeric(false) -- allow -, decimals, etc.; we validate ourselves

    if opts.maxLetters then eb:SetMaxLetters(opts.maxLetters) end

    -- Events
    Mixin(eb, CallbackRegistryMixin)
    eb:OnLoad()
    eb:GenerateCallbackEvents({ "ValueChanged", "ValueCommitted" })

    -- Behavior toggles
    local section   = opts.section or (type(configVar)=="table" and configVar.section) or nil
    local doRefresh = (opts.refresh ~= false)   -- default true
    local liveWrite = (opts.live == true)       -- default commit-only

    local function afterWrite()
        if section and S.NotifyProfileChanged then S.NotifyProfileChanged(section) end
        if doRefresh and S.Refresh then S.Refresh() end
    end

    -- Path helpers
    local function ensurePath(tbl, key) if not tbl[key] then tbl[key] = {} end; return tbl[key] end
    local function resolvePath(root, path) -- returns parent, lastKey
        local parent = root
        for seg, dot in path:gmatch("([^%.]+)(%.?)") do
            if dot == "." then parent = ensurePath(parent, seg) else return parent, seg end
        end
        return root, path
    end

    -- Binding
    local function makeRW()
        if type(configVar)=="table" and (configVar.get or configVar.set) then
            local get = configVar.get or function() return eb._value end
            local set = configVar.set or function(v) eb._value = v end
            return get, set
        end
        if type(configVar)=="table" and configVar.tbl and configVar.key then
            return function() return configVar.tbl[configVar.key] end,
            function(v)  configVar.tbl[configVar.key] = v end
        end
        if type(configVar)=="table" and type(configVar.path)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar.path)
                return p and p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar.path)
                if p then p[k] = v end
            end
        end
        if type(configVar)=="string" then
            return function()
                if not (S and S.Profile) then return nil end
                local p,k = resolvePath(S.Profile, configVar)
                return p and p[k]
            end,
            function(v)
                if not (S and S.Profile) then return end
                local p,k = resolvePath(S.Profile, configVar)
                if p then p[k] = v end
            end
        end
        return function() return eb._value end,
        function(v) eb._value = v end
    end

    local read, write = makeRW()
    local suppressSetter = false

    -- Placeholder
    local placeholder
    if opts.placeholder then
        placeholder = eb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        placeholder:SetPoint("LEFT", eb, "LEFT", 6, 0)
        placeholder:SetText(opts.placeholder)
    end
    local function updatePlaceholder()
        if not placeholder then return end
        local hasText = (eb:GetText() or "") ~= ""
        if eb:HasFocus() or hasText then placeholder:Hide() else placeholder:Show() end
    end

    -- Validation / normalization
    local function normalizeAndValidate(txt)
        txt = tostring(txt or "")
        if opts.trim ~= false then txt = txt:match("^%s*(.-)%s*$") end

        if opts.pattern and not txt:match(opts.pattern) then
            return nil
        end

        if type(opts.validator) == "function" then
            local ok, norm = opts.validator(txt)
            if not ok then return nil end
            if norm ~= nil then txt = tostring(norm) end
        end

        if opts.numeric then
            local num = tonumber(txt)
            if not num then return nil end
            if opts.integer then num = math.floor(num + 0.0000001) end
            if opts.min and num < opts.min then num = opts.min end
            if opts.max and num > opts.max then num = opts.max end
            return tostring(num), num
        end

        return txt
    end

    local function commit()
        local raw = eb:GetText() or ""
        local norm, num = normalizeAndValidate(raw)
        if not norm then
            suppressSetter = true
            local cur = read and read()
            eb:SetText(cur ~= nil and tostring(cur) or (opts.default ~= nil and tostring(opts.default) or ""))
            suppressSetter = false
            eb:ClearFocus()
            updatePlaceholder()
            return
        end

        if not U._syncing then
            if opts.numeric then write(num) else write(norm) end
            afterWrite()
        end

        suppressSetter = true
        eb:SetText(norm)
        suppressSetter = false

        eb:ClearFocus()
        updatePlaceholder()

        eb:TriggerEvent("ValueCommitted", eb, opts.numeric and num or norm, { fromUser = true })
    end

    -- Live typing (optional write), always fire ValueChanged (UI listeners)
    eb:SetScript("OnTextChanged", function(self, userInput)
        updatePlaceholder()
        if suppressSetter or U._syncing then return end
        local text = self:GetText() or ""
        local norm, num = normalizeAndValidate(text)
        local payload = opts.numeric and num or (norm or text)
        self:TriggerEvent("ValueChanged", self, payload, { fromUser = true })
        if liveWrite and norm ~= nil then
            if opts.numeric then write(num) else write(norm) end
            afterWrite()
        end
    end)

    eb:SetScript("OnEnterPressed",  commit)
    eb:SetScript("OnEditFocusLost", commit)
    eb:SetScript("OnEscapePressed", function(self)
        suppressSetter = true
        local cur = read and read()
        self:SetText(cur ~= nil and tostring(cur) or (opts.default ~= nil and tostring(opts.default) or ""))
        suppressSetter = false
        self:ClearFocus()
        updatePlaceholder()
    end)
    eb:SetScript("OnEditFocusGained", updatePlaceholder)

    -- Public API
    eb.label = fs

    function eb:SetLabel(text)
        if self.label then self.label:SetText(text or "") end
    end

    function eb:Rebuild()
        local v = read and read()
        if v == nil then v = opts.default end
        suppressSetter = true
        self:SetText(v ~= nil and tostring(v) or "")
        suppressSetter = false
        updatePlaceholder()
    end

    function eb:SetEnabled(enabled)
        if enabled then
            self:Enable(); self:SetAlpha(1)
            if self.label then self.label:SetFontObject(GameFontNormal) end
        else
            self:Disable(); self:SetAlpha(0.4)
            if self.label then self.label:SetFontObject(GameFontDisable) end
        end
    end

    function eb:SetVisible(visible)
        if visible then
            self:Show(); if self.label then self.label:Show() end
            if self.Rebuild then self:Rebuild() end
        else
            self:Hide(); if self.label then self.label:Hide() end
        end
        if self._group and U.RelayoutGroup then
            U.RelayoutGroup(self._group, self._group._controls, self._group._startY)
        end
    end

    function eb:SetValue(v, fireEvent)
        suppressSetter = true
        self:SetText(v ~= nil and tostring(v) or "")
        suppressSetter = false
        if not U._syncing then
            local norm, num = normalizeAndValidate(self:GetText() or "")
            if norm ~= nil then
                if opts.numeric then write(num) else write(norm) end
                afterWrite()
                if fireEvent then
                    self:TriggerEvent("ValueChanged", self, opts.numeric and num or norm, { fromUser = false })
                    self:TriggerEvent("ValueCommitted", self, opts.numeric and num or norm, { fromUser = false })
                end
            end
        end
        updatePlaceholder()
    end

    -- Flow integration
    local blockH, initiallyVisible = parseFlow(extraPad, U.DROPDOWN_BLOCK_H)
    eb._blockH = blockH

    eb._parent = parent
    eb._x      = x
    function eb:Reanchor(newY)
        if self.label then
            self.label:ClearAllPoints()
            self.label:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY)
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self._parent, "TOPLEFT", self._x, newY - 16)
    end
    function eb:GetFlowY(prevY)
        return (self:IsShown() and (prevY - self._blockH)) or prevY
    end

    U.RegisterControl(parent, eb)
    if not initiallyVisible then
        eb:SetVisible(false)
        return eb, y
    end

    -- Init from binding/default
    eb._value = opts.default
    eb:Rebuild()

    return eb, y - eb._blockH
end
