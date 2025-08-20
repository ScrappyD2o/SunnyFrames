-- Frames/Factory.lua
local ADDON, S = ...
S         = _G[ADDON] or S or {}
_G[ADDON] = S
S.Frames  = S.Frames or {}

local F = {}
S.Frames.Factory = F

-- =========================================================
-- Locals
-- =========================================================
local pool   = {}    -- [index] = Button (created)
local active = {}    -- [index] = Button (claimed/visible)

local function makeName(i) return "SunnyFramesUnitFrame"..tostring(i) end

-- =========================================================
-- Pixel helpers (fallbacks if PixelUtil not present)
-- =========================================================
local function GetPixel()
    local s = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if s <= 0 then s = 1 end
    return 1 / s
end
local function Snap(v)
    local p = GetPixel()
    return math.floor((v / p) + 0.5) * p
end
local function PxSetPoint(region, ...)
    if PixelUtil and PixelUtil.SetPoint then PixelUtil.SetPoint(region, ...) else region:SetPoint(...) end
end
local function PxSetWidth(region, w)
    if PixelUtil and PixelUtil.SetWidth then PixelUtil.SetWidth(region, w) else region:SetWidth(Snap(w)) end
end
local function PxSetHeight(region, h)
    if PixelUtil and PixelUtil.SetHeight then PixelUtil.SetHeight(region, h) else region:SetHeight(Snap(h)) end
end
local function SnapFrameSizeToPixels(frame)
    if not frame or not frame.GetSize then return end
    local w, h = frame:GetSize()
    if not w or not h then return end
    local nw, nh = Snap(w), Snap(h)
    if math.abs(nw - w) > 0.001 or math.abs(nh - h) > 0.001 then
        frame:SetSize(nw, nh)
    end
end

-- =========================================================
-- Border (on "frameBorder" plane)
-- =========================================================
function S.Frames_EnsureBorder(btn)
    if not btn then return nil end

    local Layers = S.Frames and S.Frames.Layers
    local parent = (Layers and Layers.GetPlane and Layers.GetPlane(btn, "frameBorder")) or btn

    if btn._pxBorder and btn._pxBorder.parent == parent then
        return btn._pxBorder
    end

    local t = btn._pxBorder or {}
    t.parent = parent

    local tex = [[Interface\Buttons\WHITE8X8]]
    local function ensure(k)
        if t[k] and t[k].GetObjectType and t[k]:GetParent() == parent then return t[k] end
        -- Use OVERLAY so within the plane it’s on top of its ARTWORK children
        local r = parent:CreateTexture(nil, "OVERLAY")
        r:SetTexture(tex)
        t[k] = r
        return r
    end

    t.top    = ensure("top")
    t.bottom = ensure("bottom")
    t.left   = ensure("left")
    t.right  = ensure("right")

    btn._pxBorder = t

    if not btn._pxBorderHooked then
        btn._pxBorderHooked = true
        btn:HookScript("OnSizeChanged", function() S.Frames_ApplyPixelBorder(btn) end)
        btn:HookScript("OnShow",        function() S.Frames_ApplyPixelBorder(btn) end)
    end
    return t
end

function S.Frames_ApplyPixelBorder(btn)
    if not btn then return end

    -- Snap the button size first; prevents tiny empty slivers
    SnapFrameSizeToPixels(btn)

    local t = S.Frames_EnsureBorder(btn)

    local framesCfg = (S.Profile and S.Profile.party) or {}
    local reqTh     = tonumber(framesCfg.frameBorder) or 1
    local th        = math.max(0, math.floor(reqTh + 0.5))

    if th <= 0 then
        t.top:Hide(); t.bottom:Hide(); t.left:Hide(); t.right:Hide()
        return
    end

    -- Border color (black by default)
    local br, bg, bb, ba = 0, 0, 0, 1

    -- Anchor exactly to the plane edges, all snapped.
    t.top:ClearAllPoints()
    PxSetPoint(t.top, "TOPLEFT",  t.parent, "TOPLEFT",  0, 0)
    PxSetPoint(t.top, "TOPRIGHT", t.parent, "TOPRIGHT", 0, 0)
    PxSetHeight(t.top, th)
    t.top:SetVertexColor(br, bg, bb, ba); t.top:Show()

    t.bottom:ClearAllPoints()
    PxSetPoint(t.bottom, "BOTTOMLEFT",  t.parent, "BOTTOMLEFT", 0, 0)
    PxSetPoint(t.bottom, "BOTTOMRIGHT", t.parent, "BOTTOMRIGHT", 0, 0)
    PxSetHeight(t.bottom, th)
    t.bottom:SetVertexColor(br, bg, bb, ba); t.bottom:Show()

    t.left:ClearAllPoints()
    PxSetPoint(t.left, "TOPLEFT",    t.parent, "TOPLEFT",    0, 0)
    PxSetPoint(t.left, "BOTTOMLEFT", t.parent, "BOTTOMLEFT", 0, 0)
    PxSetWidth(t.left, th)
    t.left:SetVertexColor(br, bg, bb, ba); t.left:Show()

    t.right:ClearAllPoints()
    PxSetPoint(t.right, "TOPRIGHT",    t.parent, "TOPRIGHT",  0, 0)
    PxSetPoint(t.right, "BOTTOMRIGHT", t.parent, "BOTTOMRIGHT", 0, 0)
    PxSetWidth(t.right, th)
    t.right:SetVertexColor(br, bg, bb, ba); t.right:Show()
end

function S.Frames_RefreshAllBorders()
    if not (S and S.Frames and S.Frames.Manager and S.Frames.Manager.IterateButtons) then return end
    for btn in S.Frames.Manager.IterateButtons("party") do
        S.Frames_ApplyPixelBorder(btn)
    end
end

-- =========================================================
-- Unit frame creation & pool
-- =========================================================
local function CreateUnitFrame(i, parent)
    local name = makeName(i)
    local f = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
    f:SetSize(120, 36)
    f:SetFrameStrata("MEDIUM")

    -- Secure targeting defaults
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")

    -- Let click-targeting extender wire here if present
    if S.Frames and S.Frames.ApplyClickTargeting then
        pcall(S.Frames.ApplyClickTargeting, f)
    end

    -- Ensure layering exists ASAP so border plane is real
    if S.Frames and S.Frames.Layers and S.Frames.Layers.Apply then
        S.Frames.Layers.Apply(f)
    end

    -- Simple background so borders are visible
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture([[Interface\Buttons\WHITE8X8]])
    bg:SetVertexColor(0, 0, 0, 0.20)
    bg:SetAllPoints(true)
    f._bg = bg

    -- Border now that plane exists
    S.Frames_EnsureBorder(f)
    S.Frames_ApplyPixelBorder(f)

    return f
end

function F.EnsurePool(parent, count)
    for i = 1, count do
        if not pool[i] then
            pool[i] = CreateUnitFrame(i, parent)
            pool[i]:Hide()
        else
            pool[i]:SetParent(parent)
        end
    end
    -- hide extras
    for i = count + 1, #pool do
        local btn = pool[i]
        if btn then
            active[i] = nil
            btn:Hide()
        end
    end
end

function F.Acquire(i, parent)
    if not pool[i] then
        pool[i] = CreateUnitFrame(i, parent)
    else
        pool[i]:SetParent(parent)
    end
    active[i] = pool[i]
    pool[i]:Show()
    -- repaint border after any size/layout changes
    S.Frames_ApplyPixelBorder(pool[i])
    return pool[i]
end

function F.Release(i)
    local btn = pool[i]
    if not btn then return end
    active[i] = nil
    btn:Hide()
end

function F.Get(i) return pool[i] end
function F.ForEachActive(cb) for _, btn in pairs(active) do cb(btn) end end
function F.Active() return active end

-- Optional: repaint borders shortly after login/reload once everything has scaled
if C_Timer and C_Timer.After then
    C_Timer.After(0.1, function()
        if S.Frames_RefreshAllBorders then S.Frames_RefreshAllBorders() end
    end)
end

return F
