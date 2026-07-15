-- "Who is online with the addon", fed by periodic W pings. Distinct from
-- Pool on purpose: Pool holds people actively *searching* (short TTL, driven
-- by HELLO/BYE), Presence holds everyone *online* (long TTL, driven only by
-- the ping). A BYE means "I stopped searching", never "I logged off", so it
-- must not touch this store — going offline is detected by TTL alone.
-- Untrusted input (NFR-S2/S4). In-memory only (NFR-D2).
local _, NS = ...

local Presence = { entries = {}, count = 0 }
NS.Presence = Presence

-- Own AceEvent target. CallbackHandler stores ONE callback per (message,
-- object) — `events[eventname][self] = func` — so every module that subscribes
-- through the shared `addon` object silently overwrites the previous one.
-- Presence must therefore listen on itself, not on `addon`.
LibStub("AceEvent-3.0"):Embed(Presence)

local function now() return NS.now() end

local function fireChanged()
    NS.addon:SendMessage("HCBB_PRESENCE_CHANGED")
end

-- ------------------------------------------------------------- outbound --

-- 3.3.5 has no GetProfessions() (Cataclysm+), so professions are read off the
-- skill sheet. `isAbandonable` is what marks a profession that costs a slot —
-- verified in-game on both realms 2026-07-15: it holds for the primaries under
-- the "Professions" header AND for Ascension's custom Woodcutting/Woodworking
-- (which the client files under "Secondary Skills"), while Cooking, Fishing,
-- First Aid, Riding, class skills, weapon skills and languages are all
-- non-abandonable and drop out for free. Names are matched against
-- Data.PROF_ABBREV (enUS client, same assumption as byBossName); anything
-- unknown is ignored rather than guessed.
local function scanProfessions()
    local out = {}
    local n = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, n do
        local name, isHeader, _, rank, _, _, _, isAbandonable = GetSkillLineInfo(i)
        if not isHeader and isAbandonable and name then
            local ab = NS.Data.PROF_ABBREV[name]
            if ab and rank and rank > 0 then
                out[#out + 1] = { ab = ab, rank = math.min(rank, 999) }
                if #out >= NS.Data.MAX_PROFS then break end
            end
        end
    end
    return out
end

function Presence:Enabled()
    local db = NS.addon and NS.addon.db
    return not (db and db.global.hidePresence)
end

-- Opting out cannot un-send the pings peers already hold: they drop us when
-- our entry expires (PRESENCE_EXPIRY). But we must vanish from our OWN list
-- immediately — otherwise the user unticks the box, still sees themselves in
-- the tab, and rightly concludes the setting does nothing.
function Presence:SetHidden(hidden)
    NS.addon.db.global.hidePresence = hidden and true or false
    if hidden then
        self:Remove(UnitName("player"))
        return
    end
    -- Reappear at once instead of after up to PRESENCE_PING, but never let a
    -- toggled checkbox turn into a channel-spam vector (NFR-P2/S4).
    local t = now()
    if not self.lastPingAt
       or t - self.lastPingAt > NS.Data.CONST.SENDER_MIN_GAP then
        self:SendPing()
    end
end

function Presence:SendPing()
    -- First cycle done: the tab can stop saying "initializing" and show the
    -- real state. Set even when we don't actually send (not enrolled, opted
    -- out), because in those cases the empty list IS the truthful answer.
    if not self.ready then
        self.ready = true
        fireChanged()
    end
    if not NS.eligible then return end          -- R23: participants only
    if not self:Enabled() then return end       -- opt-out
    self.seq = ((self.seq or 0) + 1) % 65536
    local _, token = UnitClass("player")
    if NS.Comm:Broadcast({
        type = "W", seq = self.seq,
        level = UnitLevel("player") or 1,
        ver = NS.VERSION,
        class = NS.Data.CLASS_ABBREV[token] or "xx",
        profs = scanProfessions(),
    }) then
        self.lastPingAt = now()
    end
end

function Presence:Init(addon)
    -- Collapsed headers hide their child lines from GetSkillLineInfo, which
    -- would silently blank out the player's professions. Expanding once at
    -- load is invisible (the skill frame isn't open yet); we deliberately do
    -- NOT re-expand on every ping, which would fight the user's UI.
    if ExpandSkillHeader then ExpandSkillHeader(0) end
    local C = NS.Data.CONST
    -- Start the loop on the first CHANNEL_UP, not on a blind timer: a ping
    -- sent before the channel join (R23 gate + CHANNEL_JOIN_DELAY) is dropped
    -- on the floor, and the player would then wait a full interval to appear.
    -- Jittered so a server restart doesn't put every client in lockstep.
    Presence:RegisterMessage("HCBB_CHANNEL_UP", function()
        if Presence.started then return end
        Presence.started = true
        addon:ScheduleTimer(function()
            Presence:SendPing()
            addon:ScheduleRepeatingTimer(function() Presence:SendPing() end,
                                         C.PRESENCE_PING)
        end, math.random() * C.PRESENCE_JITTER)
    end)
end

-- -------------------------------------------------------------- inbound --

-- sender comes from the chat event (server-authenticated), never the payload.
function Presence:OnPing(sender, msg)
    local C = NS.Data.CONST
    local e = self.entries[sender]
    if e then
        if msg.seq == e.seq then return end                       -- dupe
        if now() - e.lastSeen < C.SENDER_MIN_GAP then return end  -- flood
    else
        if self.count >= C.PRESENCE_CAP then self:evictOldest() end
        e = { name = sender, firstSeen = now() }
        self.entries[sender] = e
        self.count = self.count + 1
    end
    e.level, e.class, e.ver, e.profs = msg.level, msg.class, msg.ver, msg.profs
    e.seq, e.lastSeen = msg.seq, now()
    fireChanged()
end

function Presence:Remove(name)
    if self.entries[name] then
        self.entries[name] = nil
        self.count = self.count - 1
        fireChanged()
    end
end

function Presence:evictOldest()
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

function Presence:Sweep()
    local expiry, changed = NS.Data.CONST.PRESENCE_EXPIRY, false
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

function Presence:Wipe()
    if self.count > 0 then
        self.entries = {}
        self.count = 0
        fireChanged()
    end
end

-- Tab rows: online players, freshest first.
function Presence:GetSorted()
    local out = {}
    for _, e in pairs(self.entries) do out[#out + 1] = e end
    table.sort(out, function(a, b)
        if a.lastSeen ~= b.lastSeen then return a.lastSeen > b.lastSeen end
        return a.name < b.name
    end)
    return out
end
