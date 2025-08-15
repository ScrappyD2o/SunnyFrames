local ADDON, S = ...

------------------------------------------------------------
-- Class color helpers
------------------------------------------------------------
function S.ClassColor(unit)
    if S.PGet("useClassColors") and RAID_CLASS_COLORS and unit and UnitExists(unit) then
        local class = select(2, UnitClass(unit))
        local c = class and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    end
    return 0.15, 0.8, 0.2
end

function S.ClassColorForClass(classToken)
    if S.PGet("useClassColors") and RAID_CLASS_COLORS and classToken then
        local c = RAID_CLASS_COLORS[classToken]
        if c then return c.r, c.g, c.b end
    end
    return 0.15, 0.8, 0.2
end

------------------------------------------------------------
-- Power color helpers
------------------------------------------------------------
function S.PowerTypeAndColor(unit)
    local index, token = UnitPowerType(unit)
    token = token or (index and _G[select(2, GetPowerBarInfo(index))] or "MANA")
    local color
    if PowerBarColor and token and PowerBarColor[token] then
        color = PowerBarColor[token]
    elseif PowerBarColor and index and PowerBarColor[index] then
        color = PowerBarColor[index]
    end
    if color then return token, color.r, color.g, color.b end
    return token or "MANA", 0.0, 0.55, 1.0
end

function S.PowerColorForToken(token)
    if PowerBarColor and token and PowerBarColor[token] then
        local c = PowerBarColor[token]
        return c.r, c.g, c.b
    end
    return 0.0, 0.55, 1.0
end

------------------------------------------------------------
-- Unit list helper (with Test Mode)
------------------------------------------------------------
local TEST_CLASSES = {
    "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT",
    "SHAMAN","MAGE","WARLOCK","MONK","DRUID","DEMONHUNTER","EVOKER",
}
local TEST_POWER = { "MANA","ENERGY","RAGE","FOCUS","FURY","INSANITY" }
local TEST_NAMES = {
    "Delande","Alyra","Kael","Morthos","Seris","Taryn","Varek","Nyra",
    "Bram","Elior","Zarin","Kessa","Doran","Maelis","Riven","Thale",
}

function S.TestData(i)
    local name  = TEST_NAMES[((i-1) % #TEST_NAMES) + 1] .. i
    local class = TEST_CLASSES[((i-1) % #TEST_CLASSES) + 1]
    local ptype = TEST_POWER[((i-1) % #TEST_POWER) + 1]

    local t = S.time or 0
    local phase = t * 0.6 + i * 0.7
    local hpMax = 1000 + (i % 5) * 500
    local hp    = math.floor(hpMax * (0.25 + 0.75 * (0.5 + 0.5 * math.sin(phase))))
    local pMax  = 100
    local pCur  = math.floor(pMax * (0.5 + 0.5 * math.sin(phase * 1.7)))

    return {
        name = name,
        class = class,
        powerToken = ptype,
        hp = hp, hpMax = hpMax,
        pCur = pCur, pMax = pMax,
    }
end

function S.UnitList()
    local db = S.DB()
    if db.testMode then
        local preset = db.testPreset or "PARTY"
        local n = (preset == "RAID40") and 40 or (preset == "RAID20") and 20 or 5
        local units = {}
        for i = 1, n do units[i] = "test"..i end
        return units
    end

    local units = {}
    if IsInRaid() and db.useRaid then
        for i = 1, 40 do
            local u = "raid"..i
            if UnitExists(u) then units[#units+1] = u end
        end
    else
        if db.showPlayer then units[#units+1] = "player" end
        for i = 1, 4 do
            local u = "party"..i
            if UnitExists(u) then units[#units+1] = u end
        end
    end
    return units
end

------------------------------------------------------------
-- UTF-8 + font + resource helpers
------------------------------------------------------------
function S.Utf8Len(s)
    local len, i, n = 0, 1, #s
    while i <= n do
        len = len + 1
        local c = s:byte(i)
        if not c then break end
        if c < 0x80 then i = i + 1
        elseif c < 0xE0 then i = i + 2
        elseif c < 0xF0 then i = i + 3
        else i = i + 4 end
    end
    return len
end

function S.Utf8Sub(s, startChar, endChar)
    local startIndex = 1
    while startChar > 1 do
        local c = s:byte(startIndex)
        if not c then return "" end
        if c < 0x80 then startIndex = startIndex + 1
        elseif c < 0xE0 then startIndex = startIndex + 2
        elseif c < 0xF0 then startIndex = startIndex + 3
        else startIndex = startIndex + 4 end
        startChar = startChar - 1
    end
    local currentIndex = startIndex
    local charsLeft = (endChar or S.Utf8Len(s)) - (startChar - 1)
    while charsLeft > 0 and currentIndex <= #s do
        local c = s:byte(currentIndex)
        if c < 0x80 then currentIndex = currentIndex + 1
        elseif c < 0xE0 then currentIndex = currentIndex + 2
        elseif c < 0xF0 then currentIndex = currentIndex + 3
        else currentIndex = currentIndex + 4 end
        charsLeft = charsLeft - 1
    end
    return s:sub(startIndex, currentIndex - 1)
end

function S.ApplyNameFont(fs, cellH)
    local path, _, flags = GameFontHighlightSmall:GetFont()
    local maxWanted = tonumber(S.PGet("nameFontSize")) or 12
    local capByHeight = math.max(4, math.floor((cellH or 18) * 0.9))
    local size = math.max(4, math.min(maxWanted, capByHeight))
    fs:SetFont(path, size, flags)
    return size, path, flags
end

function S.FitNameText(cell, text)
    if not cell or not cell.name then return end
    local fs = cell.name
    text = text or "?"

    local maxChars = tonumber(S.PGet("nameMaxChars")) or 20
    local ulen = S.Utf8Len(text)
    if ulen > maxChars then
        text = S.Utf8Sub(text, 1, maxChars)
    end

    fs:SetWordWrap(false)
    fs:SetNonSpaceWrap(false)
    fs:SetMaxLines(1)

    local available = math.max(0, (cell:GetWidth() or 0) - 4)
    if available <= 0 then fs:SetText("?"); return end

    local size, path, flags = S.ApplyNameFont(fs, cell:GetHeight())
    fs:SetText(text)
    local tw = fs:GetStringWidth() or 0

    if S.PGet("nameAutoFit") ~= false then
        while tw > available and size > 4 do
            size = size - 1
            fs:SetFont(path, size, flags)
            fs:SetText(text)
            tw = fs:GetStringWidth() or 0
        end
    end

    if tw <= available then return end

    local ell = "…"
    local low, high = 0, S.Utf8Len(text)
    local best = 0
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = S.Utf8Sub(text, 1, mid) .. ell
        fs:SetText(candidate)
        local cw = fs:GetStringWidth() or 0
        if cw <= available then best = mid; low = mid + 1 else high = mid - 1 end
    end
    fs:SetText(S.Utf8Sub(text, 1, best) .. ell)
end

function S.ShouldShowResource(unit)
    local mode = (S.PGet("resourceMode") or "ALL")
    if mode == "NONE" then return false end
    if mode == "MANA" then
        local _, token = UnitPowerType(unit)
        token = token or "MANA"
        return token == "MANA"
    end
    return true
end
