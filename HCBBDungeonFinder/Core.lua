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

local debugLog, debugOn = {}, false
function NS.Debug(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    local line = table.concat(parts, " ")
    debugLog[#debugLog + 1] = ("%.1f %s"):format(NS.now() or 0, line)
    if #debugLog > 100 then table.remove(debugLog, 1) end -- NFR-O1 ring buffer
    if debugOn then addon:Print("|cff888888" .. line .. "|r") end
end

local versionNoticed = false
function NS.NoticeNewerVersion()
    if versionNoticed then return end
    versionNoticed = true
    addon:Print(NS.L["MSG_NEWER_PROTO"])
end

-- ------------------------------------------------------------ database ---

local defaults = {
    global = {
        lang = "auto",
        sound = true,
        minimap = { hide = false, angle = 220 },
        brackets = {}, -- per-boss {min,max} overrides (R2)
    },
    char = {
        prefs = { bossId = nil, roles = 0, minSize = 5, lead = false },
        cleared = {}, -- bossId -> true
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HCBB_DB", defaults, true)
    NS.SetLanguage(self.db.global.lang)

    self:RegisterChatCommand("hcbb", "OnSlash")
end

function addon:OnEnable()
    NS.Comm:Init(self)
    NS.Session:Init(self)
    self:ScheduleRepeatingTimer(function() NS.Pool:Sweep() end, 15)
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
    elseif cmd == "debug" then
        debugOn = not debugOn
        NS.debugChannel = debugOn
        self:Print("debug " .. (debugOn and "ON" or "OFF"))
    elseif cmd == "log" then
        for _, line in ipairs(debugLog) do self:Print(line) end
    elseif cmd == "pool" then
        self:Print(("pool: %d listings, channel %s (id %d)"):format(
            NS.Pool.count, NS.Comm.healthy and "OK" or "DOWN", NS.Comm.channelId))
        for name, e in pairs(NS.Pool.entries) do
            self:Print(("  %s lv%d boss#%d roles=%d min=%d lead=%d age=%ds"):format(
                name, e.level, e.bossId, e.roles, e.minSize, e.lead,
                NS.now() - e.firstSeen))
        end
    elseif cmd == "auras" then
        -- Identify the exact trial marker to put in Data.CHALLENGE_AURAS.
        self:Print(("eligible=%s — player auras:"):format(tostring(NS.eligible)))
        for _, kind in ipairs({ { "BUFF", UnitBuff }, { "DEBUFF", UnitDebuff } }) do
            for i = 1, 40 do
                local name, _, _, _, _, _, _, _, _, _, spellId = kind[2]("player", i)
                if not name then break end
                self:Print(("  [%s] %s (spellId %s)"):format(kind[1], name, tostring(spellId)))
            end
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
    local roleSets = { 1, 2, 4, 8, 8, 9 }
    local classes = { "wa", "su", "sa", "ra", "ma", "dh" }
    for i, name in ipairs(names) do
        NS.Pool:OnHello(name, {
            seq = i, bossId = bossId,
            level = math.max(b.min, math.min(b.max, level - (i % 3) + 1)),
            roles = roleSets[i], minSize = 3 + (i % 3), lead = i % 2,
            ver = NS.VERSION, class = classes[i],
        })
    end
    self:Print(("demo: seeded %d listings for %s"):format(#names, b.boss))
    self:ScheduleTimer(function()
        local me = UnitName("player")
        addon:SendMessage("HCBB_PROPOSAL_SHOW", {
            demo = true, matchId = "Aldric-1", bossId = bossId, size = 5,
            yourRole = 8, leader = "Aldric", iAmLeader = false,
            members = {
                { name = "Aldric",  role = 1, level = level, lead = 1 },
                { name = "Berylla", role = 2, level = level, lead = 0 },
                { name = "Corvin",  role = 4, level = level, lead = 0 },
                { name = me,        role = 8, level = level, lead = 0 },
                { name = "Ewina",   role = 8, level = level, lead = 0 },
            },
        })
    end, 2)
end
