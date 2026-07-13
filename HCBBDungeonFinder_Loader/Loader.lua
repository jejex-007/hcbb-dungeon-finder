-- Participation gate loader (R23).
--
-- WoW 3.3.5 loads every enabled addon at login, so a normal addon cannot
-- refuse to load on the "wrong" character. This tiny addon is the only part
-- always loaded; the real addon (HCBBDungeonFinder) is LoadOnDemand and is
-- pulled into memory *only* on a character carrying the Boss Blitz marker.
-- On any other character the addon never loads: no frames, no slash command,
-- nothing. (The main addon keeps its own runtime R23 gate as a safety net,
-- e.g. for losing the debuff on death mid-session — an addon can't unload.)
--
-- Deliberately self-contained (the main addon isn't loaded yet), so the
-- marker is duplicated here. Keep in sync with Data.CHALLENGE_AURAS.
local MAIN = "HCBBDungeonFinder"
local SPELL_ID = 93131
local NAME = "Hardcore - Boss Blitz"

local function hasMarker()
    for _, scan in ipairs({ UnitBuff, UnitDebuff }) do
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, _, spellId = scan("player", i)
            if not name then break end
            if spellId == SPELL_ID or name == NAME then return true end
        end
    end
    return false
end

local function load()
    local loaded, reason = LoadAddOn(MAIN)
    if not loaded and reason == "DISABLED" then
        EnableAddOn(MAIN)
        LoadAddOn(MAIN)
    end
end

-- A permanent debuff is present at PLAYER_ENTERING_WORLD, but UNIT_AURA
-- covers the case where auras populate a frame late, or the player enrolls
-- and gets the debuff mid-session. We stop listening the moment we load.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_AURA")
f:SetScript("OnEvent", function(self, event, unit)
    if IsAddOnLoaded(MAIN) then
        self:UnregisterAllEvents()
        return
    end
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if hasMarker() then
        load()
        self:UnregisterAllEvents()
    end
end)
