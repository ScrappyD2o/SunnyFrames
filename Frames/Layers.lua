local ADDON, S = ...
S.Frames        = S.Frames or {}
S.Frames.Layers = S.Frames.Layers or {}

local Layers = S.Frames.Layers

-- Ordered planes: low -> high. Keep what you had; add frameBorder if you’re using it.
local ORDER = {
    "background",
    "healthBar",
    "shieldBar",
    "powerBar",
    "frameBorder", -- include if you use a border plane
    "nameText",
}

local RANK = {}
local function rebuildRank()
    wipe(RANK)
    for i, name in ipairs(ORDER) do
        RANK[name] = i - 1
    end
end
rebuildRank()

local STRIDE = 20

local function newPlane(btn)
    local f = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    f:SetAllPoints(btn)
    if f.EnableMouse then f:EnableMouse(false) end  -- <<< IMPORTANT
    return f
end

function Layers.RegisterPlane(btn, name, frame, offset)
    if not (btn and name) then return end
    btn._planeMap = btn._planeMap or {}
    local rec = btn._planeMap[name]
    if not rec then
        rec = {}
        btn._planeMap[name] = rec
    end
    rec.frame  = frame or rec.frame or newPlane(btn)
    rec.offset = tonumber(offset) or rec.offset or 0
    rec.frame:ClearAllPoints()
    rec.frame:SetAllPoints(btn)
    if rec.frame.EnableMouse then rec.frame:EnableMouse(false) end -- <<< IMPORTANT
    return rec.frame
end

function Layers.UnregisterPlane(btn, name)
    if not (btn and btn._planeMap and name) then return end
    btn._planeMap[name] = nil
end

function Layers.GetPlane(btn, name)
    if not (btn and name) then return nil end
    btn._planeMap = btn._planeMap or {}
    local rec = btn._planeMap[name]
    if rec and rec.frame then
        if rec.frame.EnableMouse then rec.frame:EnableMouse(false) end -- safety
        return rec.frame
    end
    return Layers.RegisterPlane(btn, name, nil, 0)
end

function Layers.GetOrder()
    local copy = {}
    for i, v in ipairs(ORDER) do copy[i] = v end
    return copy
end

function Layers.SetOrder(newOrder)
    if type(newOrder) ~= "table" or #newOrder == 0 then return end
    ORDER = {}
    for _, name in ipairs(newOrder) do
        if type(name) == "string" and name ~= "" then
            table.insert(ORDER, name)
        end
    end
    rebuildRank()
    Layers.ApplyAll()
end

function Layers.SetStride(n)
    local v = tonumber(n)
    if not v or v < 1 then return end
    STRIDE = math.floor(v + 0.5)
    Layers.ApplyAll()
end

function Layers.Apply(btn)
    if not btn or not btn._planeMap then return end
    local strata = btn:GetFrameStrata() or "MEDIUM"
    local base   = btn:GetFrameLevel()  or 0

    for _, name in ipairs(ORDER) do
        local rec = btn._planeMap[name]
        if rec and rec.frame and rec.frame.SetFrameLevel then
            local rk = RANK[name] or 0
            rec.frame:SetFrameStrata(strata)
            rec.frame:SetFrameLevel(base + rk * STRIDE + (rec.offset or 0))
            rec.frame:ClearAllPoints()
            rec.frame:SetAllPoints(btn)
            if rec.frame.EnableMouse then rec.frame:EnableMouse(false) end -- safety
        end
    end

    -- Any extra planes not in ORDER go above
    local top = (#ORDER - 1)
    for name, rec in pairs(btn._planeMap) do
        if not RANK[name] and rec.frame and rec.frame.SetFrameLevel then
            rec.frame:SetFrameStrata(strata)
            rec.frame:SetFrameLevel(base + (top + 1) * STRIDE + (rec.offset or 0))
            rec.frame:ClearAllPoints()
            rec.frame:SetAllPoints(btn)
            if rec.frame.EnableMouse then rec.frame:EnableMouse(false) end
        end
    end
end

function Layers.ApplyAll()
    local F = S.Frames.Factory
    if not F or not F.Active then return end
    for _, btn in pairs(F.Active()) do
        Layers.Apply(btn)
    end
end

return Layers
