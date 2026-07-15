-- Wire protocol v1 encoder/decoder. Pure Lua 5.1 — no WoW API — so it runs
-- under busted in CI (NFR-T1). Strict charset validation replaces escaping:
-- any field containing a separator or unexpected character is rejected
-- (NFR-S2). Payloads stay well under 240 bytes (NFR-C2).
--
-- Grammar (docs/design/architecture.md §4):
--   HCBB1:H:<seq>:<bossId>:<level>:<roles>:<minSize>:<lead>:<ver>
--   HCBB1:B:<seq>
--   HCBB1:P:<matchId>:<bossId>:<size>:<yourRole>:<name,role,lvl;...>
--   HCBB1:A:<matchId>
--   HCBB1:N:<matchId>:<reason>
--   HCBB1:C:<matchId>
--   HCBB1:X:<matchId>:<reason>
--   HCBB1:W:<seq>:<level>:<ver>:<class>:<ab><rank>,...  (presence/Who's Playing)
--
-- W is additive on purpose: it ships under the SAME protocol major, because
-- Codec.decode reports an unknown *type* separately from an unknown *major*
-- and Comm drops it silently. A 0.1.x client therefore ignores W without
-- crashing or firing the update notice, whereas bumping to HCBB2 would make
-- it reject every message including HELLO. Never bump the major to add a type.

local Codec = { PROTO = 1 }

local vararg = { ... }
if type(vararg[2]) == "table" then vararg[2].Codec = Codec end

local HEADER = "HCBB" .. Codec.PROTO
local MAX_PAYLOAD = 240

local REASONS = { busy = true, changed = true, declined = true,
                  refill = true, timeout = true, cancel = true }
local VALID_ROLE = { [1] = true, [2] = true, [4] = true, [8] = true }
-- Wire ceiling for W: a character has at most two primary professions.
local MAX_PROFS = 2

-- WoW character names: no spaces or punctuation we use as separators.
-- UTF-8 accented bytes are > 0x7F and pass the negated class.
local NAME_PAT = "^[^%s:;,|]+$"
local VER_PAT = "^%d+%.%d+%.%d+$"
local MATCHID_PAT = "^[^%s:;,|]+%-%d+$"

local function isInt(v, min, max)
    return type(v) == "number" and v == math.floor(v) and v >= min and v <= max
end

local function checkName(s)
    return type(s) == "string" and #s >= 2 and #s <= 48 and s:match(NAME_PAT) ~= nil
end

-- ---------------------------------------------------------------- encode --

local function encodeMembers(members)
    if type(members) ~= "table" or #members < 3 or #members > 5 then return nil end
    local parts = {}
    for i = 1, #members do
        local m = members[i]
        if not (type(m) == "table" and checkName(m.name)
                and VALID_ROLE[m.role] and isInt(m.level, 1, 99)) then
            return nil
        end
        parts[i] = m.name .. "," .. m.role .. "," .. m.level
    end
    return table.concat(parts, ";")
end

-- "<ab><rank>" pairs, comma-separated; "" when the character has none (a
-- perfectly normal state, not an error). Rank is the raw skill value: the
-- Ascension caps differ from WotLK (150/225 vs 450), so we never interpret it.
local function encodeProfs(profs)
    if profs == nil then return "" end
    if type(profs) ~= "table" or #profs > MAX_PROFS then return nil end
    local parts, seen = {}, {}
    for i = 1, #profs do
        local p = profs[i]
        if not (type(p) == "table" and type(p.ab) == "string"
                and p.ab:match("^%l%l$") and isInt(p.rank, 1, 999)
                and not seen[p.ab]) then
            return nil
        end
        seen[p.ab] = true
        parts[i] = p.ab .. p.rank
    end
    return table.concat(parts, ",")
end

local encoders = {
    H = function(t)
        if not (isInt(t.seq, 0, 65535) and isInt(t.bossId, 1, 99)
                and isInt(t.level, 1, 99) and isInt(t.roles, 1, 15)
                and isInt(t.minSize, 3, 5) and (t.lead == 0 or t.lead == 1)
                and type(t.ver) == "string" and t.ver:match(VER_PAT)) then
            return nil
        end
        local s = table.concat({ HEADER, "H", t.seq, t.bossId, t.level,
                                 t.roles, t.minSize, t.lead, t.ver }, ":")
        -- Optional trailing class field (2-letter abbrev), backward-compatible.
        if t.class ~= nil then
            if not (type(t.class) == "string" and t.class:match("^%l%l$")) then return nil end
            s = s .. ":" .. t.class
        end
        return s
    end,
    B = function(t)
        if not isInt(t.seq, 0, 65535) then return nil end
        return HEADER .. ":B:" .. t.seq
    end,
    P = function(t)
        local members = encodeMembers(t.members)
        if not (members and type(t.matchId) == "string"
                and t.matchId:match(MATCHID_PAT) and isInt(t.bossId, 1, 99)
                and isInt(t.size, 3, 5) and VALID_ROLE[t.yourRole]) then
            return nil
        end
        return table.concat({ HEADER, "P", t.matchId, t.bossId, t.size,
                              t.yourRole, members }, ":")
    end,
    A = function(t)
        if not (type(t.matchId) == "string" and t.matchId:match(MATCHID_PAT)) then return nil end
        return HEADER .. ":A:" .. t.matchId
    end,
    C = function(t)
        if not (type(t.matchId) == "string" and t.matchId:match(MATCHID_PAT)) then return nil end
        return HEADER .. ":C:" .. t.matchId
    end,
    N = function(t)
        if not (type(t.matchId) == "string" and t.matchId:match(MATCHID_PAT)
                and REASONS[t.reason]) then return nil end
        return HEADER .. ":N:" .. t.matchId .. ":" .. t.reason
    end,
    X = function(t)
        if not (type(t.matchId) == "string" and t.matchId:match(MATCHID_PAT)
                and REASONS[t.reason]) then return nil end
        return HEADER .. ":X:" .. t.matchId .. ":" .. t.reason
    end,
    W = function(t) -- presence ping (Who's Playing). Name comes from the
                    -- channel sender (NFR-S2), never from the payload.
                    -- Carries `ver` on purpose: every online client pings, so
                    -- this is a far better update-notice vector than HELLO,
                    -- which only goes out while someone is searching (NFR-C5).
        if not (isInt(t.seq, 0, 65535) and isInt(t.level, 1, 99)
                and type(t.ver) == "string" and t.ver:match(VER_PAT)
                and type(t.class) == "string" and t.class:match("^%l%l$")) then
            return nil
        end
        local profs = encodeProfs(t.profs)
        if not profs then return nil end
        return table.concat({ HEADER, "W", t.seq, t.level, t.ver, t.class,
                              profs }, ":")
    end,
    S = function(t) -- suggest invite (over PARTY/RAID)
        if not (checkName(t.target) and isInt(t.bossId, 1, 99)) then return nil end
        return HEADER .. ":S:" .. t.target .. ":" .. t.bossId
    end,
}

function Codec.encode(t)
    if type(t) ~= "table" then return nil, "not a table" end
    local enc = encoders[t.type]
    if not enc then return nil, "unknown type" end
    local s = enc(t)
    if not s then return nil, "invalid fields" end
    if #s > MAX_PAYLOAD then return nil, "too long" end
    return s
end

-- ---------------------------------------------------------------- decode --

local function split(s, sep)
    local out, pos = {}, 1
    while true do
        local i = s:find(sep, pos, true)
        if not i then out[#out + 1] = s:sub(pos) break end
        out[#out + 1] = s:sub(pos, i - 1)
        pos = i + 1
    end
    return out
end

local function decodeMembers(s, size)
    local rows = split(s, ";")
    if #rows ~= size then return nil end
    local members, seen = {}, {}
    for i = 1, #rows do
        local name, role, level = rows[i]:match("^([^,]+),(%d+),(%d+)$")
        role, level = tonumber(role), tonumber(level)
        if not (name and checkName(name) and VALID_ROLE[role]
                and isInt(level, 1, 99) and not seen[name]) then
            return nil
        end
        seen[name] = true
        members[i] = { name = name, role = role, level = level }
    end
    return members
end

local function decodeProfs(s)
    if s == "" then return {} end -- no professions is valid, not a failure
    local rows = split(s, ",")
    if #rows > MAX_PROFS then return nil end
    local profs, seen = {}, {}
    for i = 1, #rows do
        local ab, rank = rows[i]:match("^(%l%l)(%d+)$")
        rank = tonumber(rank)
        if not (ab and rank and isInt(rank, 1, 999) and not seen[ab]) then
            return nil
        end
        seen[ab] = true
        profs[i] = { ab = ab, rank = rank }
    end
    return profs
end

local decoders = {
    H = function(f)
        if #f ~= 9 and #f ~= 10 then return nil end
        local t = { type = "H", seq = tonumber(f[3]), bossId = tonumber(f[4]),
                    level = tonumber(f[5]), roles = tonumber(f[6]),
                    minSize = tonumber(f[7]), lead = tonumber(f[8]), ver = f[9] }
        if not (t.seq and isInt(t.seq, 0, 65535)
                and t.bossId and isInt(t.bossId, 1, 99)
                and t.level and isInt(t.level, 1, 99)
                and t.roles and isInt(t.roles, 1, 15)
                and t.minSize and isInt(t.minSize, 3, 5)
                and (t.lead == 0 or t.lead == 1)
                and t.ver:match(VER_PAT)) then
            return nil
        end
        if #f == 10 then -- optional class field
            if not f[10]:match("^%l%l$") then return nil end
            t.class = f[10]
        end
        return t
    end,
    B = function(f)
        if #f ~= 3 then return nil end
        local seq = tonumber(f[3])
        if not (seq and isInt(seq, 0, 65535)) then return nil end
        return { type = "B", seq = seq }
    end,
    P = function(f)
        if #f ~= 7 then return nil end
        local t = { type = "P", matchId = f[3], bossId = tonumber(f[4]),
                    size = tonumber(f[5]), yourRole = tonumber(f[6]) }
        if not (t.matchId:match(MATCHID_PAT)
                and t.bossId and isInt(t.bossId, 1, 99)
                and t.size and isInt(t.size, 3, 5)
                and t.yourRole and VALID_ROLE[t.yourRole]) then
            return nil
        end
        t.members = decodeMembers(f[7], t.size)
        if not t.members then return nil end
        return t
    end,
    A = function(f)
        if not (#f == 3 and f[3]:match(MATCHID_PAT)) then return nil end
        return { type = "A", matchId = f[3] }
    end,
    C = function(f)
        if not (#f == 3 and f[3]:match(MATCHID_PAT)) then return nil end
        return { type = "C", matchId = f[3] }
    end,
    N = function(f)
        if not (#f == 4 and f[3]:match(MATCHID_PAT) and REASONS[f[4]]) then return nil end
        return { type = "N", matchId = f[3], reason = f[4] }
    end,
    X = function(f)
        if not (#f == 4 and f[3]:match(MATCHID_PAT) and REASONS[f[4]]) then return nil end
        return { type = "X", matchId = f[3], reason = f[4] }
    end,
    W = function(f)
        if #f ~= 7 then return nil end
        local t = { type = "W", seq = tonumber(f[3]), level = tonumber(f[4]),
                    ver = f[5], class = f[6] }
        if not (t.seq and isInt(t.seq, 0, 65535)
                and t.level and isInt(t.level, 1, 99)
                and t.ver:match(VER_PAT)
                and t.class:match("^%l%l$")) then
            return nil
        end
        t.profs = decodeProfs(f[7])
        if not t.profs then return nil end
        return t
    end,
    S = function(f)
        if #f ~= 4 then return nil end
        local bossId = tonumber(f[4])
        if not (checkName(f[3]) and bossId and isInt(bossId, 1, 99)) then return nil end
        return { type = "S", target = f[3], bossId = bossId }
    end,
}

-- Returns a message table, or nil plus a reason. Unknown protocol majors are
-- reported distinctly so the caller can show the "newer version" notice
-- (NFR-C5) without trusting anything else in the payload.
function Codec.decode(s)
    if type(s) ~= "string" or #s > MAX_PAYLOAD then return nil, "bad input" end
    if s:sub(1, 4) ~= "HCBB" then return nil, "not ours" end
    local proto = s:match("^HCBB(%d+):")
    if not proto then return nil, "malformed" end
    if tonumber(proto) ~= Codec.PROTO then return nil, "version" end
    local f = split(s, ":")
    local dec = decoders[f[2]]
    if not dec then return nil, "unknown type" end
    local t = dec(f)
    if not t then return nil, "invalid fields" end
    return t
end

-- Numeric semver comparison (pure, testable). Returns true iff release `a`
-- is strictly newer than release `b`. Both must be well-formed "X.Y.Z";
-- anything else returns false so a garbage version never nags the user.
-- Numeric per component, so 0.1.10 is newer than 0.1.9 (a string compare
-- would get that wrong).
function Codec.isNewer(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local a1, a2, a3 = a:match("^(%d+)%.(%d+)%.(%d+)$")
    local b1, b2, b3 = b:match("^(%d+)%.(%d+)%.(%d+)$")
    if not (a1 and b1) then return false end
    a1, a2, a3 = tonumber(a1), tonumber(a2), tonumber(a3)
    b1, b2, b3 = tonumber(b1), tonumber(b2), tonumber(b3)
    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end
    return a3 > b3
end

return Codec
