local ADDON, S = ...
S.Frames = S.Frames or {}
local M = S.Frames.Manager

S.FramesAPI = {
    BuildParty  = function() M.BuildParty() end,
    ApplySkin   = function() M.ApplySkin() end,
    ApplyLayout = function() M.ApplyLayout() end,
    RefreshAll  = function() M.RefreshAll() end,
}

-- Convenience for your existing ApplyAll hook (DB.lua references this)
function S.ApplyAll()
    if M then M.BuildParty() end
end
