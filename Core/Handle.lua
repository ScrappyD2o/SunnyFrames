local ADDON, S = ...

local handle

function S.EnsureHandle()
    if handle then return end

    handle = CreateFrame("Button", "SunnyFramesHandle", S.root, "BackdropTemplate")
    handle:SetSize(25, 10)
    handle:SetPoint("TOPLEFT", S.root, "TOPLEFT", 0, 12)
    handle:SetFrameStrata("HIGH")
    handle:SetFrameLevel(S.root:GetFrameLevel() + 5)
    handle:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1
    })
    handle:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    handle:SetBackdropBorderColor(0, 0, 0, 1)

    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("SunnyFrames", 1, 1, 1)
        if S.DB().lockFrame then
            GameTooltip:AddLine("Right-click for options", .9, .9, .9)
        else
            GameTooltip:AddLine("Left-drag to move", .9, .9, .9)
            GameTooltip:AddLine("Right-click for options", .9, .9, .9)
        end
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not S.DB().lockFrame then
            S.root:SetMovable(true)
            S.root:StartMoving()
        end
    end)
    handle:SetScript("OnDragStop", function()
        S.root:StopMovingOrSizing()
        if S.SavePosition then S.SavePosition() end
    end)

    handle:RegisterForClicks("AnyUp")
    handle:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" and type(SunnyFrames_ToggleConfig) == "function" then
            SunnyFrames_ToggleConfig()
        end
    end)
end

function S.ApplyMovableState()
    S.root:EnableMouse(false)
    if S.EnsureHandle then S.EnsureHandle() end
end
