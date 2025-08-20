local ADDON, S = ...
S.Frames         = S.Frames or {}
S.Frames.Roster  = S.Frames.Roster or {}
local R          = S.Frames.Roster

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local function P()
    return (S.Profile and S.Profile.party) or {}
end

local function unitExists(u)
    return u and UnitExists(u)
end

local function ownerUnits()
    -- Owners only; pets are handled separately so they can be glued to owners
    return { "player", "party1", "party2", "party3", "party4" }
end

local function petOf(owner)
    if owner == "player" then
        return "pet"
    end
    return owner .. "pet"
end

-- ------------------------------------------------------------
-- Sort keys & comparators
-- ------------------------------------------------------------
local ROLE_ORDER_THD = { TANK=1, HEALER=2, DAMAGER=3, NONE=4, [""]=4, [false]=4 }
local ROLE_ORDER_HTD = { HEALER=1, TANK=2,  DAMAGER=3, NONE=4, [""]=4, [false]=4 }

local function roleRank(unit, scheme)
    local role = (UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)) or "NONE"
    if scheme == "THD" then
        return ROLE_ORDER_THD[role] or 4
    else
        return ROLE_ORDER_HTD[role] or 4
    end
end

local function sort_alpha_asc(a, b)
    local na = (UnitName(a) or ""):lower()
    local nb = (UnitName(b) or ""):lower()
    if na ~= nb then return na < nb end
    -- stable tie-breaker: unit id string
    return tostring(a) < tostring(b)
end

local function sort_alpha_desc(a, b)
    local na = (UnitName(a) or ""):lower()
    local nb = (UnitName(b) or ""):lower()
    if na ~= nb then return na > nb end
    return tostring(a) < tostring(b)
end

local function sort_role(a, b, scheme)
    local ra = roleRank(a, scheme)
    local rb = roleRank(b, scheme)
    if ra ~= rb then return ra < rb end
    return sort_alpha_asc(a, b)
end

-- ------------------------------------------------------------
-- Public: BuildPartyList
-- ------------------------------------------------------------
function R.BuildPartyList()
    local p            = P()
    local orderMode    = (p.sortingOrder or "UNSORTED"):upper()
    local showPets     = (p.showPets == true)   -- default OFF per UI (only include pets when true)

    -- Gather existing owners
    local owners = {}
    for _, u in ipairs(ownerUnits()) do
        if unitExists(u) then
            table.insert(owners, u)
        end
    end

    -- Apply sorting (owners only)
    if orderMode == "AZ" then
        table.sort(owners, sort_alpha_asc)
    elseif orderMode == "ZA" then
        table.sort(owners, sort_alpha_desc)
    elseif orderMode == "THD" then
        table.sort(owners, function(a, b) return sort_role(a, b, "THD") end)
    elseif orderMode == "HTD" then
        table.sort(owners, function(a, b) return sort_role(a, b, "HTD") end)
    else
        -- "UNSORTED": keep natural order (player, party1..4)
    end

    -- Build final list and glue pets to owners (if enabled)
    local out = {}
    for _, owner in ipairs(owners) do
        table.insert(out, owner)
        if showPets then
            local pet = petOf(owner)
            if unitExists(pet) then
                table.insert(out, pet)
            end
        end
    end

    if S.dprintf then
        S.dprintf("Roster: order=%s showPets=%s owners=%d total=%d",
                orderMode, tostring(showPets), #owners, #out)
    end
    return out
end

return R
