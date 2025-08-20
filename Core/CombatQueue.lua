local ADDON, S = ...
S.CombatQueue = S.CombatQueue or {}

local queue = {}
local queuedKeys = {}

local function runQueued()
    for i = 1, #queue do
        local ok, err = pcall(queue[i])
        -- swallow errors (but you can print if you want)
    end
    wipe(queue)
    wipe(queuedKeys)
end

function S.CombatQueue:RunOrDefer(key, func)
    if not InCombatLockdown() then
        if S.dprintf then S.dprintf("RunOrDefer: running now (%s)", tostring(key)) end
        func()
        return
    end
    if key and queuedKeys[key] then if S.dprintf then S.dprintf("RunOrDefer: already queued (%s)", tostring(key)) end; return end -- collapse duplicates
    table.insert(queue, func)
    if S.dprintf then S.dprintf("RunOrDefer: deferred (%s) due to combat", tostring(key)) end
    if key then queuedKeys[key] = true end
end

-- Flush on leaving combat
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function() if S.dprintf then S.dprintf("Combat ended: flushing %d task(s)", #queue) end; runQueued() end)
