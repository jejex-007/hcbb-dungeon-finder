-- Static game data and protocol constants. Declarative only (NFR-A3):
-- no logic beyond index building. Bracket defaults follow BR §7:
-- [unlock - 4, unlock].
local _, NS = ...

local Data = {}
NS.Data = Data

Data.CONST = {
    PROTO            = 1,          -- wire protocol major version
    CHANNEL          = "HCBBDungeonFinder",  -- hidden broadcast channel (unique name avoids collisions)
    COMM_PREFIX      = "HCBB",     -- SendAddonMessage prefix
    HEARTBEAT        = 30,         -- s between HELLO rebroadcasts (R17)
    EXPIRY           = 120,        -- s without heartbeat before eviction (R17)
    FRESH_GREEN      = 60,         -- s: browser dot green below this (R17)
    FRESH_YELLOW     = 90,         -- s: yellow below this, red above. Kept
                                   -- under EXPIRY (120) so the red band is a
                                   -- real 30 s window, not the zero-width one
                                   -- FRESH_YELLOW == EXPIRY used to give.
    PROPOSAL_TIMEOUT = 30,         -- s to answer a proposal (R12)
    FORMING_TIMEOUT  = 20,         -- s to receive the party invite (design 1l)
    GRACE_SMALLER    = 90,         -- s of searching before size 4 allowed, 2x for 3 (R14)
    MATCH_DEBOUNCE   = 2,          -- s debounce on pool changes before matching
    POOL_CAP         = 200,        -- max listings kept (NFR-P6)
    SENDER_MIN_GAP   = 10,         -- s minimum between HELLOs from one sender (NFR-S4)
    MAX_LEVEL_SPAN   = 3,          -- challenge rule (R9)
    CHANNEL_JOIN_DELAY = 8,        -- s after login before joining the channel
    DECLINE_COOLDOWN = 120,        -- s a decliner is excluded from rematching
    -- Who's Playing presence. Unlike HELLO (sent only while searching), every
    -- online client pings, so the interval is deliberately 4x the heartbeat:
    -- NFR-P2 allows 1 msg/30 s per client and this stays well under it while
    -- the channel-wide volume scales with the whole online population.
    PRESENCE_PING    = 120,        -- s between presence pings
    PRESENCE_JITTER  = 30,         -- s of random spread, so a server restart
                                   -- doesn't make every client ping in lockstep
    PRESENCE_EXPIRY  = 300,        -- s without a ping before we treat as offline
    PRESENCE_CAP     = 200,        -- max presence entries kept (NFR-P6)
}

-- Community links surfaced in the Options tab. Ascension has no in-game
-- browser and rejects clickable URLs, so the UI shows them pre-selected in a
-- copyable edit box (UI.CopyPopup) rather than opening them.
Data.LINKS = {
    discord = "https://discord.gg/AHpHCd65eQ",
}

-- The two primary professions, shown in the Who's Playing tab (R25). Keyed by
-- the enUS skill-line name: the client runs enUS, the same assumption the
-- cleared-boss tracking already makes with byBossName. Two-letter wire
-- abbreviations keep channel payloads ASCII (NFR-C3) and short (NFR-C2); the
-- display name is localized from the `PROF_<ab>` locale key (R22/NFR-L2), so
-- the wire stays locale-independent.
--
-- This table IS the filter, which is why Ascension's custom Woodcutting and
-- Woodworking are deliberately absent: they are abandonable and cost a slot
-- like a primary (verified in-game 2026-07-15 on both realms — the client
-- files them under "Secondary Skills"), so `isAbandonable` alone would let
-- them through. Collection also checks `isAbandonable`, which is what drops
-- Cooking, Fishing, First Aid, Riding, class/weapon skills and languages for
-- free. Both game modes are identical here, so there is deliberately no
-- per-mode table. Unknown skill lines are ignored, never guessed (NFR-S2).
Data.PROF_ABBREV = {
    ["Alchemy"] = "al", ["Blacksmithing"] = "bs", ["Enchanting"] = "en",
    ["Engineering"] = "eg", ["Herbalism"] = "hb", ["Inscription"] = "in",
    ["Jewelcrafting"] = "jc", ["Leatherworking"] = "lw", ["Mining"] = "mi",
    ["Skinning"] = "sk", ["Tailoring"] = "ta",
}

Data.MAX_PROFS = 2

Data.ROLE = { TANK = 1, HEAL = 2, SUPPORT = 4, DPS = 8 }
Data.ROLE_ORDER = { 1, 2, 4, 8 }

-- Game modes have different class/role systems and live on separate realms
-- whose names EMBED the mode, e.g. "Bronzebeard - Warcraft Reborn" and
-- "Vol'jin - Conquest of Azeroth" (confirmed in-game). Conquest of Azeroth
-- has the 21 custom classes and the Support role; Warcraft Reborn has the 9
-- base classes and NO Support role. We detect WR by the mode tag as a
-- case-insensitive substring of the realm name; anything else defaults to
-- CoA, the superset — so an unknown realm keeps the full feature set (M6.2).
Data.WR_REALM_TAG = "Warcraft Reborn"
Data.MODE = { COA = "CoA", WR = "WR" }

-- Roles offered per mode (M6.2). The mode is the source of truth; the Support
-- role simply isn't part of the Warcraft Reborn set. Add a mode here to give
-- it its own role set — no special-casing in the UI.
Data.MODE_ROLES = {
    [Data.MODE.COA] = { 1, 2, 4, 8 }, -- Tank, Heal, Support, DPS
    [Data.MODE.WR]  = { 1, 2, 8 },    -- Tank, Heal, DPS (no Support)
}

-- CoA classes: token <-> 2-letter wire abbreviation, display name, color.
-- Abbreviations/colors mirror the community LootCollector addon so we stay
-- consistent with the ecosystem. UnitClass("player") returns these tokens.
Data.CLASS_ABBREV = {
    WARRIOR = "wa", PALADIN = "pa", HUNTER = "hu", ROGUE = "ro", PRIEST = "pr",
    DEATHKNIGHT = "dk", SHAMAN = "sh", MAGE = "ma", WARLOCK = "lo", DRUID = "dr",
    HERO = "he", BARBARIAN = "ba", WITCHDOCTOR = "wd", DEMONHUNTER = "dh",
    WITCHHUNTER = "wh", STORMBRINGER = "sb", FLESHWARDEN = "fw", GUARDIAN = "gu",
    MONK = "mo", SONOFARUGAL = "sa", RANGER = "ra", CHRONOMANCER = "ch",
    NECROMANCER = "ne", PYROMANCER = "py", CULTIST = "cu", STARCALLER = "sc",
    SUNCLERIC = "su", TINKER = "ti", PROPHET = "pt", REAPER = "re",
    WILDWALKER = "ww", SPIRITMAGE = "sm", KNIGHTOFXOROTH = "kx",
}
Data.CLASS_TOKEN = {}
for token, ab in pairs(Data.CLASS_ABBREV) do Data.CLASS_TOKEN[ab] = token end

Data.CLASS_DISPLAY = {
    SONOFARUGAL = "Bloodmage", TINKER = "Tinker", PROPHET = "Venomancer",
    RANGER = "Ranger", NECROMANCER = "Necromancer", WILDWALKER = "Primalist",
    CULTIST = "Cultist", GUARDIAN = "Guardian", REAPER = "Reaper",
    MONK = "Templar", BARBARIAN = "Barbarian", STORMBRINGER = "Stormbringer",
    SUNCLERIC = "Sun Cleric", STARCALLER = "Starcaller", SPIRITMAGE = "Runemaster",
    WITCHDOCTOR = "Witch Doctor", CHRONOMANCER = "Chronomancer",
    PYROMANCER = "Pyromancer", FLESHWARDEN = "Knight of Xoroth",
    DEMONHUNTER = "Felsworn", WITCHHUNTER = "Witch Hunter",
    KNIGHTOFXOROTH = "Knight of Xoroth",
}

Data.CLASS_COLOR = { -- custom CoA colors (base classes use RAID_CLASS_COLORS)
    KNIGHTOFXOROTH = { 0.77, 0.12, 0.23 }, SONOFARUGAL = { 0.77, 0.12, 0.23 },
    FLESHWARDEN = { 0.77, 0.12, 0.23 }, DEMONHUNTER = { 0.64, 0.19, 0.79 },
    BARBARIAN = { 0.78, 0.61, 0.43 }, CHRONOMANCER = { 1.00, 0.96, 0.41 },
    CULTIST = { 0.53, 0.53, 0.93 }, NECROMANCER = { 0.67, 0.83, 0.45 },
    PYROMANCER = { 1.00, 0.49, 0.04 }, RANGER = { 0.67, 0.83, 0.45 },
    REAPER = { 0.00, 1.00, 0.59 }, STARCALLER = { 0.41, 0.80, 0.94 },
    STORMBRINGER = { 0.00, 0.44, 0.87 }, SUNCLERIC = { 1.00, 0.49, 0.04 },
    TINKER = { 1.00, 0.96, 0.41 }, WILDWALKER = { 1.00, 0.49, 0.04 },
    WITCHDOCTOR = { 0.96, 0.55, 0.73 }, WITCHHUNTER = { 0.53, 0.53, 0.93 },
    GUARDIAN = { 0.50, 0.50, 0.50 }, MONK = { 0.96, 0.55, 0.73 },
    SPIRITMAGE = { 0.41, 0.80, 0.94 }, PROPHET = { 0.67, 0.83, 0.45 },
}

function Data:GetClassColor(token)
    if not token then return nil end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return { c.r, c.g, c.b } end
    return self.CLASS_COLOR[token]
end

function Data:ClassDisplay(token)
    if not token then return nil end
    return self.CLASS_DISPLAY[token]
        or (token:sub(1, 1) .. token:sub(2):lower())
end

-- Participation marker (R23): the Boss Blitz mode shows as a permanent
-- debuff "Hardcore - Boss Blitz" (spellId 93131), confirmed in-game via
-- /hcbb auras. Only characters carrying it may use the addon. The spellId
-- is the primary match (locale-independent); the name is a fallback.
Data.CHALLENGE_AURAS = {
    spellIds = {
        [93131] = true,
    },
    names = {
        ["Hardcore - Boss Blitz"] = true,
    },
}

-- Blitz progression, season 2026-06 (BR §7). Fixed order, ids are wire ids
-- (R22) — never reorder or reuse; append only.
Data.BOSSES = {
    { boss = "Edwin VanCleef",           dungeon = "The Deadmines",         unlock = 21 },
    { boss = "Mutanus the Devourer",     dungeon = "Wailing Caverns",       unlock = 22 },
    { boss = "Archmage Arugal",          dungeon = "Shadowfang Keep",       unlock = 26 },
    { boss = "Aku'mai",                  dungeon = "Blackfathom Deeps",     unlock = 28 },
    { boss = "Charlga Razorflank",       dungeon = "Razorfen Kraul",        unlock = 33 },
    { boss = "Mekgineer Thermaplugg",    dungeon = "Gnomeregan",            unlock = 34 },
    { boss = "Bloodmage Thalnos",        dungeon = "SM: Graveyard",         unlock = 34 },
    { boss = "Arcanist Doan",            dungeon = "SM: Library",           unlock = 37 },
    { boss = "Herod",                    dungeon = "SM: Armory",            unlock = 40 },
    { boss = "Amnennar the Coldbringer", dungeon = "Razorfen Downs",        unlock = 41 },
    { boss = "Archaedas",                dungeon = "Uldaman",               unlock = 47 },
    { boss = "Lord Vyletongue",          dungeon = "Maraudon: Purple",      unlock = 47 },
    { boss = "Chief Ukorz Sandscalp",    dungeon = "Zul'Farrak",            unlock = 48 },
    { boss = "Razorlash",                dungeon = "Maraudon: Orange",      unlock = 48 },
    { boss = "Celebras the Cursed",      dungeon = "Maraudon: Inner",       unlock = 49 },
    { boss = "Princess Theradras",       dungeon = "Maraudon: Inner",       unlock = 51 },
    { boss = "Shade of Eranikus",        dungeon = "The Sunken Temple",     unlock = 55 },
    { boss = "Alzzin the Wildshaper",    dungeon = "Dire Maul: East",       unlock = 58 },
    { boss = "Emperor Dagran Thaurissan", dungeon = "Blackrock Depths",     unlock = 59 },
    { boss = "King Gordok",              dungeon = "Dire Maul: North",      unlock = 60 },
    { boss = "Prince Tortheldrin",       dungeon = "Dire Maul: West",       unlock = 60 },
    { boss = "Overlord Wyrmthalak",      dungeon = "Lower Blackrock Spire", unlock = 60 },
    { boss = "Balnazzar",                dungeon = "Stratholme: Live",      unlock = 60 },
    { boss = "Baron Rivendare",          dungeon = "Stratholme: Undead",    unlock = 60 },
    { boss = "Darkmaster Gandling",      dungeon = "Scholomance",           unlock = 60 },
}

Data.NUM_BOSSES = #Data.BOSSES

Data.byBossName = {}
Data.dungeons = {}
local seenDungeon = {}
for id, b in ipairs(Data.BOSSES) do
    b.id = id
    -- The boss must be killed BEFORE reaching its "beyond" level, so the
    -- ceiling is unlock-1, and the floor keeps groups within the 3-level
    -- challenge span: [unlock-4, unlock-1]. E.g. VanCleef (beyond 21): 17-20.
    b.max = b.max or (b.unlock - 1)
    b.min = b.min or (b.max - 3)
    Data.byBossName[b.boss] = b
    if not seenDungeon[b.dungeon] then
        seenDungeon[b.dungeon] = true
        Data.dungeons[#Data.dungeons + 1] = b.dungeon
    end
end

-- Effective bracket, honoring SavedVariables overrides (R2, NFR-D1).
function Data:GetBracket(bossId)
    local b = self.BOSSES[bossId]
    if not b then return nil end
    local o = NS.addon and NS.addon.db and NS.addon.db.global.brackets[bossId]
    if o and o.min and o.max then return o.min, o.max end
    return b.min, b.max
end

function Data:IsEligible(bossId, level)
    local min, max = self:GetBracket(bossId)
    if not min then return false end
    return level >= min and level <= max
end

-- R27: a boss whose "beyond" level (unlock) you have already reached was
-- necessarily killed to get there — the challenge blocks levelling past it
-- otherwise. Such a boss is cleared by level: shown ticked, not un-checkable.
-- Based on the raw progression value, not the effective bracket, so retuning
-- a bracket in SavedVariables never changes what the game itself enforced.
function Data:IsClearedByLevel(bossId, level)
    local b = self.BOSSES[bossId]
    return b ~= nil and level >= b.unlock
end
