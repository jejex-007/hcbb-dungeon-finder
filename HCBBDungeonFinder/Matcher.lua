-- Deterministic matchmaking. Pure Lua 5.1 — no WoW API — busted-tested in
-- CI (NFR-T1). Implements R7–R11, R14–R15.
--
-- Input listings: { name, bossId, level, roles (bitmask), minSize, lead,
-- ts (local first-seen; drives fairness ordering) }, unique names.
-- Determinism: identical input -> identical output. Divergence between
-- clients' pools is resolved by the ACK round-trip, not by the matcher.

local Matcher = {}

local vararg = { ... }
if type(vararg[2]) == "table" then vararg[2].Matcher = Matcher end

local ROLE_TANK, ROLE_HEAL, ROLE_SUPPORT, ROLE_DPS = 1, 2, 4, 8

local floor = math.floor

local function hasRole(mask, role)
    return floor(mask / role) % 2 == 1
end

local function byAge(a, b)
    if a.ts ~= b.ts then return a.ts < b.ts end
    return a.name < b.name
end

-- Deterministic stand-in for "random DPS" (R11): djb2 hash of the sorted
-- member names, so every client draws the same "random" leader.
local function hashPick(names, n)
    table.sort(names)
    local h = 5381
    local s = table.concat(names, "+")
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 2147483647
    end
    return (h % n) + 1
end

-- R11: tank-lead > heal-lead > support-lead > hashed DPS-lead > tank.
-- members: { name, role (assigned), lead }.
function Matcher.election(members)
    local tank, byRole, dpsLeads = nil, {}, {}
    for i = 1, #members do
        local m = members[i]
        if m.role == ROLE_TANK then tank = m end
        if m.lead == 1 then
            if m.role == ROLE_DPS then
                dpsLeads[#dpsLeads + 1] = m.name
            else
                byRole[m.role] = m.name
            end
        end
    end
    if byRole[ROLE_TANK] then return byRole[ROLE_TANK] end
    if byRole[ROLE_HEAL] then return byRole[ROLE_HEAL] end
    if byRole[ROLE_SUPPORT] then return byRole[ROLE_SUPPORT] end
    if #dpsLeads > 0 then
        local names = {}
        for i = 1, #members do names[i] = members[i].name end
        return dpsLeads[hashPick(names, #dpsLeads)]
    end
    return tank and tank.name
end

-- Backtracking role assignment for one window. Slots: TANK, HEAL, then
-- size-2 flex slots (at most one SUPPORT, the rest DPS) — R7, R15. Flex
-- tries DPS before SUPPORT so supports are used only when they add a body.
-- Candidates are tried oldest-first, which makes the result deterministic
-- and fair.
local function assign(cands, size)
    local used, out = {}, {}

    local function fill(slot, supportUsed)
        if slot > size then return true end
        local want
        if slot == 1 then want = { ROLE_TANK }
        elseif slot == 2 then want = { ROLE_HEAL }
        elseif supportUsed then want = { ROLE_DPS }
        else want = { ROLE_DPS, ROLE_SUPPORT } end

        for w = 1, #want do
            local role = want[w]
            for i = 1, #cands do
                if not used[i] and hasRole(cands[i].roles, role) then
                    used[i] = true
                    out[slot] = { name = cands[i].name, role = role,
                                  level = cands[i].level, lead = cands[i].lead }
                    if fill(slot + 1, supportUsed or role == ROLE_SUPPORT) then
                        return true
                    end
                    used[i] = false
                    out[slot] = nil
                end
            end
        end
        return false
    end

    if fill(1, false) then return out end
    return nil
end

local function matchKey(members)
    local names = {}
    for i = 1, #members do names[i] = members[i].name end
    table.sort(names)
    return table.concat(names, "+")
end

-- Best match for one boss pool at one size, or nil. Enumerates level
-- windows [L, L+maxSpan] (R9) and keeps the assignment whose oldest member
-- is oldest (fairness), tie-broken on member names.
local function findAtSize(listings, size, maxSpan)
    local eligible = {}
    for i = 1, #listings do
        if listings[i].minSize <= size then
            eligible[#eligible + 1] = listings[i]
        end
    end
    if #eligible < size then return nil end
    table.sort(eligible, byAge)

    local best, bestTs, bestKey
    local levels = {}
    for i = 1, #eligible do levels[eligible[i].level] = true end

    for L in pairs(levels) do
        local window = {}
        for i = 1, #eligible do
            local lv = eligible[i].level
            if lv >= L and lv <= L + maxSpan then
                window[#window + 1] = eligible[i]
            end
        end
        if #window >= size then
            local members = assign(window, size)
            if members then
                local oldest = math.huge
                for i = 1, #window do
                    -- oldest member actually assigned, not oldest in window
                    for j = 1, #members do
                        if members[j].name == window[i].name and window[i].ts < oldest then
                            oldest = window[i].ts
                        end
                    end
                end
                local key = matchKey(members)
                if not best or oldest < bestTs
                   or (oldest == bestTs and key < bestKey) then
                    best, bestTs, bestKey = members, oldest, key
                end
            end
        end
    end
    return best
end

-- Best match in a same-boss pool: largest allowed size first (R8/R14).
-- opts: { allowedSizes = {5,4,3}, maxSpan = 3 }.
function Matcher.find(listings, opts)
    local sizes = opts.allowedSizes
    for i = 1, #sizes do
        local members = findAtSize(listings, sizes[i], opts.maxSpan)
        if members then
            return { size = sizes[i], members = members,
                     leader = Matcher.election(members) }
        end
    end
    return nil
end

-- Peel disjoint best matches until one contains selfName (that is the only
-- match this client may act on), or the pool is exhausted.
function Matcher.findForSelf(listings, opts)
    local pool = {}
    for i = 1, #listings do pool[i] = listings[i] end
    while true do
        local match = Matcher.find(pool, opts)
        if not match then return nil end
        local inIt = {}
        for i = 1, #match.members do inIt[match.members[i].name] = true end
        if inIt[opts.selfName] then return match end
        local rest = {}
        for i = 1, #pool do
            if not inIt[pool[i].name] then rest[#rest + 1] = pool[i] end
        end
        pool = rest
    end
end

return Matcher
