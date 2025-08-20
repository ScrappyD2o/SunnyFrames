local ADDON, S = ...
S.Frames      = S.Frames or {}
S.Frames.Events = S.Frames.Events or {}

-- Singleton event frame + subscription map
function S.Frames.Events.Ensure()
    if S.Frames.Events._frame then return S.Frames.Events._frame end
    local f = CreateFrame("Frame")
    S.Frames.Events._frame = f
    S.Frames.Events._subs  = {}  -- event -> { [key]=callback }
    f:SetScript("OnEvent", function(_, event, ...)
        local map = S.Frames.Events._subs[event]
        if not map then return end
        for _, cb in pairs(map) do
            local ok, err = pcall(cb, event, ...)
            if not ok and S.dprintf then S.dprintf("Events error: %s", tostring(err)) end
        end
    end)
    return f
end

function S.Frames.Events.Subscribe(event, key, callback)
    if not event or not key or type(callback) ~= "function" then return end
    local f = S.Frames.Events.Ensure()
    local subs = S.Frames.Events._subs
    subs[event] = subs[event] or {}
    subs[event][key] = callback
    f:RegisterEvent(event)
end

function S.Frames.Events.Unsubscribe(event, key)
    if not event or not key then return end
    local f = S.Frames.Events.Ensure()
    local subs = S.Frames.Events._subs
    local map = subs[event]
    if not map then return end
    map[key] = nil
    local hasAny = false
    for _, _ in pairs(map) do hasAny = true break end
    if not hasAny then
        subs[event] = nil
        f:UnregisterEvent(event)
    end
end
