local ADDON, S = ...
S.Frames       = S.Frames or {}
S.Frames.Debug = S.Frames.Debug or {}
local Debug    = S.Frames.Debug

local function prf(...) print("|cffFFD200SunnyFrames|r", ...) end

local function safecall(obj, method, fallback, ...)
    if not obj or not obj[method] then return fallback end
    local ok, val1, val2, val3 = pcall(obj[method], obj, ...)
    if not ok then return fallback end
    if val3 ~= nil then return val1, val2, val3 end
    if val2 ~= nil then return val1, val2 end
    return val1
end

local function layerStr(region)
    local l, sub = safecall(region, "GetDrawLayer", "?", "?")
    if sub ~= nil then return tostring(l or "?").."("..tostring(sub or "?")..")" end
    return tostring(l or "?")
end

local function frmInfo(f)
    if not f then return "nil" end
    local strata = safecall(f, "GetFrameStrata", "?")
    local lvl    = safecall(f, "GetFrameLevel", "?")
    local shown  = safecall(f, "IsShown", false) and "shown" or "hidden"
    local alpha  = safecall(f, "GetAlpha", 1)
    return ("strata=%s level=%s %s alpha=%.2f"):format(tostring(strata), tostring(lvl), shown, tonumber(alpha) or 1)
end

local function texInfo(r)
    if not r then return "nil" end
    return ("draw=%s alpha=%.2f"):format(layerStr(r), tonumber(safecall(r, "GetAlpha", 1)) or 1)
end

local function dumpRegions(owner, prefix)
    local regs = { owner:GetRegions() }
    if #regs > 0 then
        prf(prefix.."Regions ("..#regs.."):")
        for i, r in ipairs(regs) do
            local rt = r.GetObjectType and r:GetObjectType() or "Region"
            local nm = r.GetName and r:GetName() or ""
            if rt == "Texture" then
                prf(prefix..("  [%02d] Texture  %-24s %s"):format(i, nm, texInfo(r)))
            elseif rt == "FontString" then
                local txt = safecall(r, "GetText", "")
                prf(prefix..("  [%02d] FontStr  %-24s draw=%s alpha=%.2f text='%s'")
                        :format(i, nm, layerStr(r), tonumber(safecall(r, "GetAlpha", 1)) or 1, tostring(txt or "")))
            else
                prf(prefix..("  [%02d] %-8s %-24s draw=%s alpha=%.2f")
                        :format(i, rt, nm, layerStr(r), tonumber(safecall(r, "GetAlpha", 1)) or 1))
            end
        end
    else
        prf(prefix.."Regions: (none)")
    end
end

local function dumpChildren(owner, prefix, depth)
    depth = depth or 0
    if depth >= 2 then return end -- avoid going too deep/noisy
    local kids = { owner:GetChildren() }
    if #kids > 0 then
        prf(prefix.."Children ("..#kids.."):")
        for i, ch in ipairs(kids) do
            local nm = ch.GetName and ch:GetName() or ""
            prf(prefix..("  [%02d] Frame    %-24s %s"):format(i, nm, frmInfo(ch)))
            dumpRegions(ch, prefix.."    ")
            -- One level deeper only:
            local gkids = { ch:GetChildren() }
            if #gkids > 0 then
                prf(prefix.."    Grandchildren ("..#gkids.."):")
                for j, g in ipairs(gkids) do
                    local gnm = g.GetName and g:GetName() or ""
                    prf(prefix..("      [%02d.%02d] Frame %-24s %s"):format(i, j, gnm, frmInfo(g)))
                    dumpRegions(g, prefix.."        ")
                end
            end
        end
    else
        prf(prefix.."Children: (none)")
    end
end

local function dumpOne(btn, unit, idx)
    prf(("=== Button #%d  name=%s  unit=%s ==="):format(idx or -1, btn:GetName() or "?", tostring(unit or "?")))
    prf(" Button:", frmInfo(btn))

    -- Layer planes
    if btn._sfPlanes then
        local arr = {}
        for name, data in pairs(btn._sfPlanes) do
            local fr = data and data.frame
            local lvl = (fr and fr.GetFrameLevel and fr:GetFrameLevel()) or -1
            table.insert(arr, { name = name, frame = fr, level = lvl, offset = data.offset or 0 })
        end
        table.sort(arr, function(a,b) return (a.level or 0) < (b.level or 0) end)
        prf(" Registered planes (low -> high):")
        for _, it in ipairs(arr) do
            prf(("  - %-10s  %s  offset=%d"):format(it.name, frmInfo(it.frame), it.offset or 0))
        end
    else
        prf(" (no _sfPlanes registered on this button)")
    end

    -- Named attachments
    if btn.Health then
        prf(" Health:", frmInfo(btn.Health))
        local tex = btn.Health.GetStatusBarTexture and btn.Health:GetStatusBarTexture()
        prf("  - StatusTexture: "..texInfo(tex))
    else
        prf(" Health: <nil>")
    end
    if btn.HealthBG then
        prf(" HealthBG (on Health): draw="..layerStr(btn.HealthBG).." alpha="..tostring(safecall(btn.HealthBG,"GetAlpha",1)))
    end

    if btn.NameLayer then prf(" NameLayer:", frmInfo(btn.NameLayer)) else prf(" NameLayer: <nil>") end
    if btn.NameText  then prf("  - NameText draw="..layerStr(btn.NameText).." alpha="..tostring(safecall(btn.NameText,"GetAlpha",1)).." text='"..(btn.NameText:GetText() or "").."'") else prf("  - NameText: <nil>") end

    -- Full walk of other regions/children that might occlude
    dumpRegions(btn, " ")
    dumpChildren(btn, " ")

    -- Verdict
    local okAbove = false
    if btn.Health and btn.NameLayer and btn.Health.GetFrameLevel and btn.NameLayer.GetFrameLevel then
        local hl = btn.Health:GetFrameLevel() or 0
        local nl = btn.NameLayer:GetFrameLevel() or 0
        okAbove = nl > hl
        prf((" Verdict: NameLayer %s Health (Name %d vs Health %d)"):format(okAbove and "ABOVE" or "NOT ABOVE", nl, hl))
    end

    prf("===============================================")
end

function Debug.DumpLayers(which)
    local Layers = S.Frames.Layers
    if Layers and Layers.GetOrder then
        local order  = Layers.GetOrder()
        local stride = Layers._stride or 20
        prf("Layer ORDER (low -> high): "..table.concat(order, ", ").."  stride="..tostring(stride))
    end

    local F = S.Frames.Factory
    if not F or not F.Active then prf("No Factory/Active pool.") return end
    local actives = F.Active()
    if not actives then prf("No active buttons.") return end

    local dumped = 0
    if type(which) == "number" then
        local btn = actives[which]
        if btn then
            local unit
            if S.Frames.UnitMap then
                for u, b in pairs(S.Frames.UnitMap) do if b == btn then unit = u break end end
            end
            dumpOne(btn, unit, which); dumped = 1
        else prf(("Index %d not active."):format(which)) end
    elseif type(which) == "string" and which ~= "" then
        local map = S.Frames.UnitMap
        if map and map[which] then
            local idx; for i, b in pairs(actives) do if b == map[which] then idx = i break end end
            dumpOne(map[which], which, idx or -1); dumped = 1
        else prf(("Unit '%s' not found."):format(which)) end
    else
        for i = 1, #actives do
            local btn = actives[i]
            if btn then
                local unit; if S.Frames.UnitMap then for u, b in pairs(S.Frames.UnitMap) do if b == btn then unit = u break end end end
                dumpOne(btn, unit, i); dumped = dumped + 1
            end
        end
        if dumped == 0 then prf("Active pool is empty.") end
    end
end

-- Visual overlay toggle on NameLayer to prove z-order
local _overlayOn = false
function Debug.ToggleNameOverlay()
    local F = S.Frames.Factory; if not F or not F.Active then return end
    local actives = F.Active()
    for _, btn in pairs(actives) do
        if btn and btn.NameLayer then
            btn._sfOverlay = btn._sfOverlay or btn.NameLayer:CreateTexture(nil, "OVERLAY")
            local ov = btn._sfOverlay
            ov:SetAllPoints(btn.NameLayer)
            if _overlayOn then
                ov:Hide()
            else
                ov:SetColorTexture(0, 1, 0, 0.12) -- faint green sheet
                ov:Show()
            end
        end
    end
    _overlayOn = not _overlayOn
    prf("Name overlay "..(_overlayOn and "ON" or "OFF"))
end

-- Slash commands
SLASH_SUNNYFRAMESLAYERS1 = "/sflayers"
SlashCmdList.SUNNYFRAMESLAYERS = function(msg)
    msg = tostring(msg or ""):match("^%s*(.-)%s*$")
    if msg == "" then Debug.DumpLayers(); return end
    local num = tonumber(msg)
    if num then Debug.DumpLayers(num) else Debug.DumpLayers(msg) end
end

SLASH_SFNAMEOVL1 = "/sfnameovl"
SlashCmdList.SFNAMEOVL = function() Debug.ToggleNameOverlay() end
