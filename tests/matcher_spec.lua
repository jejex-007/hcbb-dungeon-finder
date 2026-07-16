-- Matcher tests (NFR-T1): composition rules R7/R8, level span R9, minSize
-- R4, leader election R11, role assignment R15, determinism.
--
-- Match() returns nil when no group is feasible; a spec that indexes the
-- result is asserting one was found. Let it blow up — that IS the failure,
-- and guarding for nil here would turn a real failure into a test that
-- checks nothing.
---@diagnostic disable: need-check-nil
local Matcher = require("HCBBDungeonFinder.Matcher")

local TANK, HEAL, SUPPORT, DPS = 1, 2, 4, 8

local function listing(name, level, roles, opts)
    opts = opts or {}
    return { name = name, bossId = opts.bossId or 1, level = level,
             roles = roles, minSize = opts.minSize or 3,
             lead = opts.lead or 0, ts = opts.ts or 100 }
end

local OPTS = { allowedSizes = { 5, 4, 3 }, maxSpan = 3, selfName = "Self" }

local function names(match)
    local out = {}
    for _, m in ipairs(match.members) do out[#out + 1] = m.name end
    table.sort(out)
    return table.concat(out, ",")
end

local function roleOf(match, name)
    for _, m in ipairs(match.members) do
        if m.name == name then return m.role end
    end
end

describe("Matcher.election (R11)", function()
    local function m(name, role, lead)
        return { name = name, role = role, lead = lead }
    end

    it("prefers the tank who opted in", function()
        assert.equal("T", Matcher.election({ m("T", TANK, 1), m("H", HEAL, 1),
                                             m("D", DPS, 1) }))
    end)

    it("falls through tank > heal > support > dps", function()
        assert.equal("H", Matcher.election({ m("T", TANK, 0), m("H", HEAL, 1),
                                             m("S", SUPPORT, 1), m("D", DPS, 1) }))
        assert.equal("S", Matcher.election({ m("T", TANK, 0), m("H", HEAL, 0),
                                             m("S", SUPPORT, 1), m("D", DPS, 1) }))
    end)

    it("defaults to the tank when nobody opted in", function()
        assert.equal("T", Matcher.election({ m("T", TANK, 0), m("H", HEAL, 0),
                                             m("D", DPS, 0) }))
    end)

    it("picks a DPS lead deterministically", function()
        local members = { m("T", TANK, 0), m("H", HEAL, 0),
                          m("D1", DPS, 1), m("D2", DPS, 1), m("D3", DPS, 1) }
        local first = Matcher.election(members)
        for _ = 1, 10 do
            assert.equal(first, Matcher.election(members))
        end
        assert.truthy(first == "D1" or first == "D2" or first == "D3")
    end)
end)

describe("Matcher.find", function()
    it("builds a full 5-player group T/H/D/D/D (R7, R8)", function()
        local pool = {
            listing("Tank", 20, TANK), listing("Heal", 20, HEAL),
            listing("D1", 20, DPS), listing("D2", 21, DPS),
            listing("D3", 19, DPS),
        }
        local match = Matcher.find(pool, OPTS)
        assert.truthy(match)
        assert.equal(5, match.size)
        assert.equal("D1,D2,D3,Heal,Tank", names(match))
    end)

    it("uses at most one support, only when it adds a body (R7)", function()
        local pool = {
            listing("Tank", 20, TANK), listing("Heal", 20, HEAL),
            listing("S1", 20, SUPPORT), listing("S2", 20, SUPPORT),
            listing("D1", 20, DPS),
        }
        -- 5 needs T+H+3 flex but only 1 DPS + 2 supports -> only 1 support
        -- allowed, so no 5-group; a 4-group T/H/S/D works.
        local match = Matcher.find(pool, OPTS)
        assert.truthy(match)
        assert.equal(4, match.size)
        local supports = 0
        for _, m in ipairs(match.members) do
            if m.role == SUPPORT then supports = supports + 1 end
        end
        assert.equal(1, supports)
    end)

    it("respects every member's minSize (R4)", function()
        local pool = {
            listing("Tank", 20, TANK, { minSize = 5 }),
            listing("Heal", 20, HEAL),
            listing("D1", 20, DPS),
            listing("D2", 20, DPS),
        }
        -- Tank insists on 5; only 4 bodies -> no match at all.
        assert.falsy(Matcher.find(pool, OPTS))
    end)

    it("never groups players more than 3 levels apart (R9)", function()
        local pool = {
            listing("Tank", 16, TANK), listing("Heal", 20, HEAL),
            listing("D1", 20, DPS), listing("D2", 20, DPS),
            listing("D3", 20, DPS),
        }
        assert.falsy(Matcher.find(pool, OPTS))
        pool[1] = listing("Tank", 17, TANK)
        local match = Matcher.find(pool, OPTS)
        assert.truthy(match)
    end)

    it("honors allowedSizes gating (R14)", function()
        local pool = {
            listing("Tank", 20, TANK), listing("Heal", 20, HEAL),
            listing("D1", 20, DPS),
        }
        assert.falsy(Matcher.find(pool, { allowedSizes = { 5 }, maxSpan = 3 }))
        local match = Matcher.find(pool, { allowedSizes = { 5, 4, 3 }, maxSpan = 3 })
        assert.truthy(match)
        assert.equal(3, match.size)
    end)

    it("assigns multi-role players where needed (R15)", function()
        local pool = {
            listing("Flex", 20, TANK + DPS), listing("Heal", 20, HEAL),
            listing("D1", 20, DPS),
        }
        local match = Matcher.find(pool, OPTS)
        assert.truthy(match)
        assert.equal(TANK, roleOf(match, "Flex"))
    end)

    it("is deterministic for identical input", function()
        local pool = {
            listing("Tank", 20, TANK + DPS), listing("Heal", 20, HEAL + DPS),
            listing("A", 20, DPS + TANK), listing("B", 21, DPS + HEAL),
            listing("C", 19, DPS + SUPPORT), listing("D", 22, DPS),
            listing("E", 18, TANK + HEAL),
        }
        local first = Matcher.find(pool, OPTS)
        for _ = 1, 5 do
            local again = Matcher.find(pool, OPTS)
            assert.equal(names(first), names(again))
            assert.equal(first.leader, again.leader)
        end
    end)

    it("prefers the oldest listing (fairness)", function()
        local pool = {
            listing("OldTank", 20, TANK, { ts = 10 }),
            listing("NewTank", 20, TANK, { ts = 50 }),
            listing("Heal", 20, HEAL), listing("D1", 20, DPS),
            listing("D2", 20, DPS), listing("D3", 20, DPS),
        }
        local match = Matcher.find(pool, OPTS)
        assert.truthy(names(match):find("OldTank"))
        assert.falsy(names(match):find("NewTank"))
    end)
end)

describe("Matcher.findForSelf", function()
    it("returns nil when self is not in any match", function()
        local pool = {
            listing("Tank", 20, TANK), listing("Heal", 20, HEAL),
            listing("D1", 20, DPS), listing("D2", 20, DPS),
            listing("D3", 20, DPS),
        }
        assert.falsy(Matcher.findForSelf(pool, OPTS))
    end)

    it("peels disjoint matches until self is included", function()
        local pool = {
            -- first (older) full group without Self
            listing("Tank", 20, TANK, { ts = 1 }), listing("Heal", 20, HEAL, { ts = 1 }),
            listing("D1", 20, DPS, { ts = 1 }), listing("D2", 20, DPS, { ts = 1 }),
            listing("D3", 20, DPS, { ts = 1 }),
            -- second group where Self tanks
            listing("Self", 20, TANK, { ts = 5 }), listing("Heal2", 20, HEAL, { ts = 5 }),
            listing("D4", 20, DPS, { ts = 5 }), listing("D5", 20, DPS, { ts = 5 }),
            listing("D6", 20, DPS, { ts = 5 }),
        }
        local match = Matcher.findForSelf(pool, OPTS)
        assert.truthy(match)
        assert.truthy(names(match):find("Self"))
        assert.equal("Self", match.leader) -- default leader = tank (R11)
    end)
end)
