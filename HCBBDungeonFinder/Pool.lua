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
function Pool:OnHello(sender, msg)
    local Data, C = NS.Data, NS.Data.CONST
    if msg.bossId > Data.NUM_BOSSES then return end
    if not Data:IsEligible(msg.bossId, msg.level) then return end

    local e = self.entries[sender]
    if e then
        if msg.seq == e.seq then return end                       -- dupe
        if now() - e.lastSeen < C.SENDER_MIN_GAP then return end  -- flood
    else
        if self.count >= C.POOL_CAP then self:evictOldest() end
        e = { name = sender, firstSeen = now() }
        self.entries[sender] = e
        self.count = self.count + 1
    end

    if e.bossId ~= msg.bossId then e.firstSeen = now() end -- new goal, new age
    e.bossId, e.level, e.roles = msg.bossId, msg.level, msg.roles
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
function Pool:GetForBoss(bossId, excluded)
    local out = {}
    for name, e in pairs(self.entries) do
        if e.bossId == bossId and not (excluded and excluded[name]) then
            out[#out + 1] = { name = name, bossId = e.bossId, level = e.level,
                              roles = e.roles, minSize = e.minSize,
                              lead = e.lead, ts = e.firstSeen }
        end
    end
    return out
end

-- "N players searching in your bracket" (design 1c): same boss, within
-- MAX_LEVEL_SPAN of the given level, excluding the player themself.
function Pool:CountBracket(bossId, level, selfName)
    local span, n = NS.Data.CONST.MAX_LEVEL_SPAN, 0
    for name, e in pairs(self.entries) do
        if name ~= selfName and e.bossId == bossId
           and math.abs(e.level - level) <= span then
            n = n + 1
        end
    end
    return n
end

-- Browser rows, freshest first (design 1h).
function Pool:GetSorted(dungeonFilter)
    local out = {}
    for _, e in pairs(self.entries) do
        if not dungeonFilter
           or NS.Data.BOSSES[e.bossId].dungeon == dungeonFilter then
            out[#out + 1] = e
        end
    end
    table.sort(out, function(a, b)
        if a.lastSeen ~= b.lastSeen then return a.lastSeen > b.lastSeen end
        return a.name < b.name
    end)
    return out
end
