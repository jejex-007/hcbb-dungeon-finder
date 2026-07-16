-- Addon bootstrap: single global HCBB (NFR-C4), SavedVariables, language
-- selection, slash commands, cleared-boss tracking, debug tooling.
local ADDON_NAME, NS = ...

local addon = LibStub("AceAddon-3.0"):NewAddon("HCBB", "AceConsole-3.0",
    "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0")
_G.HCBB = addon
NS.addon = addon
NS.VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
NS.now = GetTime

-- ------------------------------------------------------------- locales ---
-- Hand-rolled instead of AceLocale: the manual override (R21 — no itIT
-- client locale on 3.3.5) and the instant language switch (design 1i) both
-- want a swappable lookup table with enUS fallback (NFR-L1).

NS.locales = NS.locales or {}
local activeLocale = {}
NS.L = setmetatable({}, {
    __index = function(_, key)
        local v = activeLocale[key] or NS.locales.enUS[key]
        if v == nil then
            NS.Debug("missing locale key", key)
            v = key
        end
        return v
    end,
})

function NS.SetLanguage(code)
    if code == "auto" or not NS.locales[code] then
        local client = GetLocale()
        code = NS.locales[client] and client or "enUS"
    end
    activeLocale = NS.locales[code]
    NS.activeLanguage = code
    if addon.SendMessage then addon:SendMessage("HCBB_LOCALE_CHANGED") end
end

-- --------------------------------------------------------------- debug ---
-- Silent capped ring buffer only — never prints to chat (a live "debug"
-- print mode would flood the chat and lag the client under heavy channel
-- traffic). Surfaced on demand, bounded, via /hcbb log.

local LOG_MAX = 50
local debugLog = {}
function NS.Debug(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    debugLog[#debugLog + 1] = ("%.1f %s"):format(NS.now() or 0, table.concat(parts, " "))
    if #debugLog > LOG_MAX then table.remove(debugLog, 1) end
end

local versionNoticed = false
function NS.NoticeNewerVersion()
    if versionNoticed then return end
    versionNoticed = true
    NS.updateAvailable = true
    addon:Print(NS.L["MSG_NEWER_PROTO"])
    -- Surface an accent banner in the window's status strip too (not just chat).
    if addon.SendMessage then addon:SendMessage("HCBB_UPDATE_AVAILABLE") end
end

-- ------------------------------------------------------------ database ---

local defaults = {
    global = {
        lang = "auto",
        sound = true,
        minimap = { hide = false, angle = 220 },
        brackets = {}, -- per-boss {min,max} overrides (R2)
        hidePresence = false, -- opt out of broadcasting presence (Who's Playing)
    },
    char = {
        prefs = { bossId = nil, roles = 0, minSize = 5, lead = false },
        cleared = {}, -- bossId -> true
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HCBB_DB", defaults, true)
    NS.SetLanguage(self.db.global.lang)

    -- Game mode (M6.2) is the source of truth for mode-specific behaviour. The
    -- realm name embeds the mode (e.g. "Bronzebeard - Warcraft Reborn"), so
    -- match the WR tag as a case-insensitive substring; default to CoA.
    NS.realm = GetRealmName() or ""
    NS.gameMode = NS.realm:lower():find(NS.Data.WR_REALM_TAG:lower(), 1, true)
        and NS.Data.MODE.WR or NS.Data.MODE.COA

    self:RegisterChatCommand("hcbb", "OnSlash")
end

function addon:OnEnable()
    NS.Comm:Init(self)
    NS.Session:Init(self)
    NS.Presence:Init(self)
    self:ScheduleRepeatingTimer(function() NS.Pool:Sweep() end, 15)
    self:ScheduleRepeatingTimer(function() NS.Presence:Sweep() end, 30)
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        addon:UpdateEligibility()
        -- Auras can land a beat after the loading screen; scan again.
        addon:ScheduleTimer(function() addon:UpdateEligibility() end, 3)
    end)
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    if NS.UI and NS.UI.Init then NS.UI.Init() end
    -- The loader only loads us on an enrolled character, and usually after
    -- the first PLAYER_ENTERING_WORLD has already fired, so check now too.
    self:UpdateEligibility()
end

-- --------------------------------------------------- participation gate --
-- R23: only characters enrolled in the challenge (trial buff present) may
-- use the addon. Client-side courtesy gating — the wire protocol still
-- treats every peer as untrusted (NFR-S4).

NS.eligible = false

-- The Boss Blitz marker is an aura on the character (a buff OR a debuff —
-- private-server mode flags are commonly permanent debuffs), so scan both.
local function scanAuras(scanFn)
    local markers = NS.Data.CHALLENGE_AURAS
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = scanFn("player", i)
        if not name then break end
        if markers.names[name] or (spellId and markers.spellIds[spellId]) then
            return true
        end
    end
    return false
end

local function scanParticipation()
    return scanAuras(UnitBuff) or scanAuras(UnitDebuff)
end

function addon:UpdateEligibility()
    local was = NS.eligible
    NS.eligible = scanParticipation()
    if was == NS.eligible then return end
    NS.Debug("eligibility ->", tostring(NS.eligible))
    if NS.eligible then
        NS.Comm:ScheduleJoin()
    else
        NS.Session:Cancel() -- aura lost (death/failure): stop everything
        NS.Comm:Leave()
    end
    self:SendMessage("HCBB_ELIGIBILITY_CHANGED", NS.eligible)
end

-- UNIT_AURA fires for every unit and often; keep the player filter cheap
-- and debounce the 40-slot scan (NFR-P3).
function addon:OnUnitAura(_, unit)
    if unit ~= "player" or self.auraScanPending then return end
    self.auraScanPending = self:ScheduleTimer(function()
        addon.auraScanPending = nil
        addon:UpdateEligibility()
    end, 2)
end

-- ------------------------------------------------- cleared-boss tracking --
-- Design 1b shows cleared bosses with a checkmark. Auto-detected from the
-- combat log by canonical (enUS) NPC name — correct on Ascension's enUS
-- client; the picker also allows a manual toggle as fallback.

function addon:OnCombatLog(_, _, subEvent, _, _, _, _, destName)
    if subEvent ~= "UNIT_DIED" or not destName then return end
    local boss = NS.Data.byBossName[destName]
    if boss and not self.db.char.cleared[boss.id] then
        self.db.char.cleared[boss.id] = true
        self:Print(NS.L["MSG_BOSS_CLEARED"]:format(boss.boss))
        self:SendMessage("HCBB_CLEARED_CHANGED")
    end
end

-- --------------------------------------------------------------- slash ---

function addon:OnSlash(input)
    local cmd = (input or ""):lower():match("^%s*(%S*)")
    if cmd == "" or cmd == "show" then
        if NS.UI and NS.UI.Toggle then NS.UI.Toggle() end
    elseif cmd == "log" then -- last LOG_MAX comm events only (no flood)
        local n = #debugLog
        for i = math.max(1, n - LOG_MAX + 1), n do self:Print(debugLog[i]) end
    elseif cmd == "pool" then
        self:Print(("pool: %d listings, channel %s (id %d)"):format(
            NS.Pool.count, NS.Comm.healthy and "OK" or "DOWN", NS.Comm.channelId))
        for name, e in pairs(NS.Pool.entries) do
            self:Print(("  %s lv%d boss#%d roles=%d min=%d lead=%d age=%ds"):format(
                name, e.level, e.bossId, e.roles, e.minSize, e.lead,
                NS.now() - e.firstSeen))
        end
    elseif cmd == "demo" then
        self:Demo()
    else
        self:Print(NS.L["MSG_USAGE"])
    end
end

-- ---------------------------------------------------------------- demo ---
-- Solo visual smoke test (no peers needed): seeds fake pool listings and,
-- a beat later, a fake proposal popup. Demo proposals never touch Session
-- state or the wire — the popup knows via the demo flag.

function addon:Demo()
    local level = UnitLevel("player")
    local bossId
    for id = 1, NS.Data.NUM_BOSSES do
        if NS.Data:IsEligible(id, level) then bossId = id break end
    end
    if not bossId then
        self:Print("demo: no boss bracket fits your level (" .. level .. ")")
        return
    end
    local b = NS.Data.BOSSES[bossId]
    local names = { "Aldric", "Berylla", "Corvin", "Dathne", "Ewina", "Falrik" }
    -- Demo listings mirror the active mode (M6.2): CoA shows custom classes and
    -- a Support; Warcraft Reborn shows base classes and no Support role.
    local roleSets, classes
    if NS.gameMode == NS.Data.MODE.COA then
        roleSets = { 1, 2, 4, 8, 8, 9 }
        classes = { "wa", "su", "sa", "ra", "ma", "dh" }
    else
        roleSets = { 1, 2, 8, 8, 8, 9 }
        classes = { "wa", "pa", "hu", "ro", "ma", "dr" }
    end
    -- Fake professions for the Who's Playing tab (R25); the last one has none,
    -- so the "no professions" path gets exercised too.
    local profSets = {
        { { ab = "bs", rank = 147 }, { ab = "mi", rank = 133 } },
        { { ab = "en", rank = 129 }, { ab = "ta", rank = 117 } },
        { { ab = "al", rank = 210 }, { ab = "hb", rank = 225 } },
        { { ab = "lw", rank = 95 }, { ab = "sk", rank = 130 } },
        { { ab = "jc", rank = 180 } },
        {},
    }
    for i, name in ipairs(names) do
        local lvl = math.max(b.min, math.min(b.max, level - (i % 3) + 1))
        NS.Pool:OnHello(name, {
            seq = i, bossId = bossId, level = lvl,
            roles = roleSets[i], minSize = 3 + (i % 3), lead = i % 2,
            ver = NS.VERSION, class = classes[i],
        })
        -- Presence is a separate store fed by its own ping, so the demo has to
        -- seed it explicitly — being in the pool never implies being online.
        NS.Presence:OnPing(name, {
            seq = i, level = lvl, ver = NS.VERSION, class = classes[i],
            profs = profSets[i],
        })
    end
    -- Two stale "Who's Looking" listings so the freshness dots and the
    -- "N active (M total)" counter (R26) can be seen: one yellow, one red.
    -- OnHello stamps lastSeen = now, so we backdate it by hand right after.
    -- They are NOT matchable (only green listings are, R26) and they drift and
    -- expire like any real stale listing — re-run /hcbb demo to refresh them.
    local staleLvl = math.max(b.min, math.min(b.max, level))
    local stale = { { name = "Gorven", age = 65 },   -- yellow: 60-90 s band
                    { name = "Halwyn", age = 95 } }   -- red: 90-120 s band
    for i, s in ipairs(stale) do
        NS.Pool:OnHello(s.name, {
            seq = 99, bossId = bossId, level = staleLvl, roles = 8,
            minSize = 3, lead = 0, ver = NS.VERSION, class = classes[i],
        })
        local e = NS.Pool.entries[s.name]
        if e then e.lastSeen = NS.now() - s.age end
    end
    NS.Presence.ready = true -- demo answers the "have we pinged yet?" question
    self:Print(("demo: seeded %d listings for %s"):format(#names, b.boss))
    self:ScheduleTimer(function()
        local me = UnitName("player")
        -- Warcraft Reborn has no Support role, so the flex slot is a DPS there.
        local flexRole = (NS.gameMode == NS.Data.MODE.COA) and 4 or 8
        addon:SendMessage("HCBB_PROPOSAL_SHOW", {
            demo = true, matchId = "Aldric-1", bossId = bossId, size = 5,
            yourRole = 8, leader = "Aldric", iAmLeader = false,
            members = {
                { name = "Aldric",  role = 1, level = level, lead = 1 },
                { name = "Berylla", role = 2, level = level, lead = 0 },
                { name = "Corvin",  role = flexRole, level = level, lead = 0 },
                { name = me,        role = 8, level = level, lead = 0 },
                { name = "Ewina",   role = 8, level = level, lead = 0 },
            },
        })
    end, 2)
end
