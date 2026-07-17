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
-- members: { name, role (assigned), lead, multi?, sees? }.
--
-- R28 electorate: a match containing a multi-target listing is invisible to
-- clients that cannot decode target lists — electing one of them would leave
-- a match nobody acts on (only the elected leader's client acts, §6). So the
-- electorate shrinks to the members who can see the match (`sees`); the R11
-- chain then applies unchanged within it, with the default fallback extended
-- (the electorate may have no tank). Guaranteed non-empty: a multi listing's
-- own sender always sees. All-scalar matches keep pure R11, versions ignored.
function Matcher.election(members)
    local pool = members
    for i = 1, #members do
        if members[i].multi then
            pool = {}
            for j = 1, #members do
                if members[j].sees then pool[#pool + 1] = members[j] end
            end
            break
        end
    end
    local byRole, dpsLeads, byDefault, dpsAll = {}, {}, {}, {}
    for i = 1, #pool do
        local m = pool[i]
        if m.role == ROLE_DPS then dpsAll[#dpsAll + 1] = m.name
        else byDefault[m.role] = byDefault[m.role] or m.name end
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
    local names
    if #dpsLeads > 0 then
        names = {}
        for i = 1, #members do names[i] = members[i].name end
        return dpsLeads[hashPick(names, #dpsLeads)]
    end
    -- No volunteer: highest-priority role present in the electorate (the
    -- classic "tank by default", generalized for a tank-less electorate).
    if byDefault[ROLE_TANK] then return byDefault[ROLE_TANK] end
    if byDefault[ROLE_HEAL] then return byDefault[ROLE_HEAL] end
    if byDefault[ROLE_SUPPORT] then return byDefault[ROLE_SUPPORT] end
    if #dpsAll > 0 then
        names = {}
        for i = 1, #members do names[i] = members[i].name end
        return dpsAll[hashPick(names, #dpsAll)]
    end
    return nil
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
                                  level = cands[i].level, lead = cands[i].lead,
                                  multi = cands[i].multi, sees = cands[i].sees }
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

-- R28: best match across several targeted bosses. bossIds ascending (= the
-- progression order, ids follow BR §7); listingsByBoss[bossId] = same-boss
-- listings. Priority is size-major, boss-minor: every boss is tried at 5
-- before any boss is tried at 4 — so "largest group wins, progression order
-- breaks ties" needs no scoring, just this iteration order. Deterministic:
-- all clients walk the same (size, boss) sequence over the same replica.
function Matcher.findForSelfMulti(bossIds, listingsByBoss, opts)
    local one = { allowedSizes = { 0 }, maxSpan = opts.maxSpan,
                  selfName = opts.selfName }
    local sizes = opts.allowedSizes
    for s = 1, #sizes do
        one.allowedSizes[1] = sizes[s]
        for b = 1, #bossIds do
            local listings = listingsByBoss[bossIds[b]]
            if listings and #listings > 0 then
                local match = Matcher.findForSelf(listings, one)
                if match then
                    match.bossId = bossIds[b]
                    return match
                end
            end
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
