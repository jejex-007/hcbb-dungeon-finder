-- Local replica of "who is searching", fed by HELLO/BYE broadcasts.
-- Untrusted input: semantic validation on top of Codec's syntactic checks
-- (NFR-S2/S4). In-memory only (NFR-D2).
local _, NS = ...

local Pool = { entries = {}, count = 0 }
NS.Pool = Pool

local function now() return NS.now() end

local function fireChanged()
    NS.addon:SendMessage("HCBB_POOL_CHANGED")
end

-- sender comes from the chat event (server-authenticated), never the payload.
-- msg.bossIds is a canonical ascending list (Codec-validated); a whole-message
-- reject on any bad id is correct because senders prune on level-up before
-- broadcasting — a partially-eligible list is malformed or hostile (NFR-S2).
function Pool:OnHello(sender, msg)
    local Data, C = NS.Data, NS.Data.CONST
    for i = 1, #msg.bossIds do
        local id = msg.bossIds[i]
        if id > Data.NUM_BOSSES then return end
        if not Data:IsEligible(id, msg.level) then return end
    end

    local e = self.entries[sender]
    if e then
        if msg.seq == e.seq then return end                       -- dupe
        if now() - e.lastSeen < C.SENDER_MIN_GAP then return end  -- flood
    else
        if self.count >= C.POOL_CAP then self:evictOldest() end
        e = { name = sender }
        self.entries[sender] = e
        self.count = self.count + 1
    end

    -- Per-boss age (R28): a boss kept across heartbeats keeps its ts, a boss
    -- added is stamped now, a boss dropped loses its ts. Generalizes the old
    -- "new goal, new age" without resetting queue position on the others —
    -- adding Gnomeregan must not send you to the back of the RFK line.
    local old, fs = e.firstSeen, {}
    for i = 1, #msg.bossIds do
        local id = msg.bossIds[i]
        fs[id] = old and old[id] or now()
    end
    e.firstSeen = fs
    e.bossIds = msg.bossIds
    e.level, e.roles = msg.level, msg.roles
    e.minSize, e.lead = msg.minSize, msg.lead
    e.class = msg.class
    e.seq, e.ver, e.lastSeen = msg.seq, msg.ver, now()
    fireChanged()
end

function Pool:OnBye(sender)
    if self.entries[sender] then
        self.entries[sender] = nil
        self.count = self.count - 1
        fireChanged()
    end
end

Pool.Remove = Pool.OnBye

function Pool:evictOldest()
    local oldest, oldestSeen
    for name, e in pairs(self.entries) do
        if not oldestSeen or e.lastSeen < oldestSeen then
            oldest, oldestSeen = name, e.lastSeen
        end
    end
    if oldest then
        self.entries[oldest] = nil
        self.count = self.count - 1
    end
end

-- Periodic TTL sweep (R17), started by Core.
function Pool:Sweep()
    local expiry, changed = NS.Data.CONST.EXPIRY, false
    local t = now()
    for name, e in pairs(self.entries) do
        if t - e.lastSeen > expiry then
            self.entries[name] = nil
            self.count = self.count - 1
            changed = true
        end
    end
    if changed then fireChanged() end
end

function Pool:Wipe()
    if self.count > 0 then
        self.entries = {}
        self.count = 0
        fireChanged()
    end
end

-- Matcher input for one boss (R10), minus excluded names (decliner cooldown).
-- maxAge (R26): only listings heard from within that many seconds are matchable,
-- so a stale/idle client whose listing hasn't expired yet is not matched into a
-- group it can't answer. Omitted → no freshness filter (used by counters).
-- `multi`/`sees` feed the R28 electorate: a multi-target listing is invisible
-- to clients below MULTI_TARGET_VER, so the election must know who can see it.
function Pool:GetForBoss(bossId, excluded, maxAge)
    local out, t = {}, now()
    local minVer = NS.Data.CONST.MULTI_TARGET_VER
    for name, e in pairs(self.entries) do
        if e.firstSeen[bossId] and not (excluded and excluded[name])
           and (not maxAge or t - e.lastSeen <= maxAge) then
            out[#out + 1] = { name = name, bossId = bossId, level = e.level,
                              roles = e.roles, minSize = e.minSize,
                              lead = e.lead, ts = e.firstSeen[bossId],
                              multi = #e.bossIds > 1,
                              sees = (e.ver and not NS.Codec.isNewer(minVer, e.ver))
                                     and true or false }
        end
    end
    return out
end

-- "N players searching in your bracket" (design 1c): shares at least one of
-- the given bosses (R28), within MAX_LEVEL_SPAN of the given level, excluding
-- the player themself. Returns (fresh, total): fresh = green listings
-- (< FRESH_GREEN), the ones actually matchable (R26); total = everyone still
-- in the pool. The UI shows only the count when they agree, and
-- "N active (M total)" when they don't.
function Pool:CountBracket(bossIds, level, selfName)
    local span = NS.Data.CONST.MAX_LEVEL_SPAN
    local maxAge, t = NS.Data.CONST.FRESH_GREEN, now()
    local fresh, total = 0, 0
    for name, e in pairs(self.entries) do
        if name ~= selfName and math.abs(e.level - level) <= span then
            for i = 1, #bossIds do
                if e.firstSeen[bossIds[i]] then
                    total = total + 1
                    if t - e.lastSeen <= maxAge then fresh = fresh + 1 end
                    break
                end
            end
        end
    end
    return fresh, total
end

-- Browser rows, freshest first (design 1h). A multi-target listing matches
-- the dungeon filter if ANY of its bosses lives in that dungeon (R28).
local function matchesFilter(e, dungeonFilter)
    if not dungeonFilter then return true end
    for i = 1, #e.bossIds do
        if NS.Data.BOSSES[e.bossIds[i]].dungeon == dungeonFilter then
            return true
        end
    end
    return false
end

function Pool:GetSorted(dungeonFilter)
    local out = {}
    for _, e in pairs(self.entries) do
        if matchesFilter(e, dungeonFilter) then
            out[#out + 1] = e
        end
    end
    table.sort(out, function(a, b)
        if a.lastSeen ~= b.lastSeen then return a.lastSeen > b.lastSeen end
        return a.name < b.name
    end)
    return out
end
