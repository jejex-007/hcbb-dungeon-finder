-- Codec wire-protocol tests (NFR-T1). Runs under busted (CI) and under
-- tests/run.lua (local, zero-dependency).
local Codec = require("HCBBDungeonFinder.Codec")

describe("Codec.encode", function()
    it("round-trips HELLO", function()
        local msg = { type = "H", seq = 42, bossId = 7, level = 33,
                      roles = 9, minSize = 4, lead = 1, ver = "0.1.0" }
        local wire = Codec.encode(msg)
        assert.equal("HCBB1:H:42:7:33:9:4:1:0.1.0", wire)
        local back = Codec.decode(wire)
        assert.equal("H", back.type)
        assert.equal(42, back.seq)
        assert.equal(7, back.bossId)
        assert.equal(33, back.level)
        assert.equal(9, back.roles)
        assert.equal(4, back.minSize)
        assert.equal(1, back.lead)
        assert.equal("0.1.0", back.ver)
    end)

    it("round-trips HELLO with optional class", function()
        local wire = Codec.encode({ type = "H", seq = 1, bossId = 7, level = 33,
                      roles = 9, minSize = 4, lead = 1, ver = "0.1.0", class = "sa" })
        assert.equal("HCBB1:H:1:7:33:9:4:1:0.1.0:sa", wire)
        assert.equal("sa", Codec.decode(wire).class)
        -- 9-field HELLO (no class) still decodes, class nil (back-compat)
        local back = Codec.decode("HCBB1:H:1:7:33:9:4:1:0.1.0")
        assert.equal("H", back.type)
        assert.equal(nil, back.class)
    end)

    it("rejects a malformed class field", function()
        assert.falsy(Codec.decode("HCBB1:H:1:7:33:9:4:1:0.1.0:XX"))
        assert.falsy(Codec.encode({ type = "H", seq = 1, bossId = 1, level = 20,
                      roles = 1, minSize = 3, lead = 0, ver = "0.1.0", class = "toolong" }))
    end)

    it("round-trips BYE", function()
        local back = Codec.decode(Codec.encode({ type = "B", seq = 65535 }))
        assert.equal("B", back.type)
        assert.equal(65535, back.seq)
    end)

    it("round-trips PROPOSE with members", function()
        local members = {
            { name = "Aldric", role = 1, level = 20 },
            { name = "Berylla", role = 2, level = 19 },
            { name = "Corvin", role = 8, level = 21 },
        }
        local wire = Codec.encode({ type = "P", matchId = "Aldric-3",
                                    bossId = 1, size = 3, yourRole = 8,
                                    members = members })
        local back = Codec.decode(wire)
        assert.equal("P", back.type)
        assert.equal("Aldric-3", back.matchId)
        assert.equal(3, #back.members)
        assert.equal("Berylla", back.members[2].name)
        assert.equal(2, back.members[2].role)
        assert.equal(19, back.members[2].level)
    end)

    it("round-trips ACK / NACK / CONFIRM / ABORT", function()
        assert.equal("A", Codec.decode(Codec.encode({ type = "A", matchId = "X-1" })).type)
        assert.equal("C", Codec.decode(Codec.encode({ type = "C", matchId = "X-1" })).type)
        local n = Codec.decode(Codec.encode({ type = "N", matchId = "X-1", reason = "busy" }))
        assert.equal("busy", n.reason)
        local x = Codec.decode(Codec.encode({ type = "X", matchId = "X-1", reason = "refill" }))
        assert.equal("refill", x.reason)
    end)

    it("round-trips SUGGEST", function()
        local wire = Codec.encode({ type = "S", target = "Corvin", bossId = 3 })
        assert.equal("HCBB1:S:Corvin:3", wire)
        local back = Codec.decode(wire)
        assert.equal("S", back.type)
        assert.equal("Corvin", back.target)
        assert.equal(3, back.bossId)
    end)

    it("accepts UTF-8 accented names", function()
        local wire = Codec.encode({ type = "P", matchId = "Ambrose-1",
                                    bossId = 2, size = 3, yourRole = 8, members = {
            { name = "J\195\169r\195\180me", role = 1, level = 20 },
            { name = "Ambr\195\184se", role = 2, level = 20 },
            { name = "Zo\195\171", role = 8, level = 20 },
        } })
        assert.truthy(wire)
        assert.equal("J\195\169r\195\180me", Codec.decode(wire).members[1].name)
    end)

    it("rejects invalid fields", function()
        assert.falsy(Codec.encode({ type = "H", seq = -1, bossId = 1, level = 20,
                                    roles = 1, minSize = 3, lead = 0, ver = "0.1.0" }))
        assert.falsy(Codec.encode({ type = "H", seq = 1, bossId = 1, level = 20,
                                    roles = 16, minSize = 3, lead = 0, ver = "0.1.0" }))
        assert.falsy(Codec.encode({ type = "H", seq = 1, bossId = 1, level = 20,
                                    roles = 1, minSize = 6, lead = 0, ver = "0.1.0" }))
        assert.falsy(Codec.encode({ type = "N", matchId = "X-1", reason = "nope" }))
        assert.falsy(Codec.encode({ type = "Z" }))
    end)

    it("rejects separator characters in names", function()
        assert.falsy(Codec.encode({ type = "P", matchId = "A-1", bossId = 1,
                                    size = 3, yourRole = 8, members = {
            { name = "Bad:name", role = 1, level = 20 },
            { name = "Okname", role = 2, level = 20 },
            { name = "Other", role = 8, level = 20 },
        } }))
    end)
end)

describe("Codec.decode", function()
    it("ignores foreign and malformed input", function()
        assert.falsy(Codec.decode("hello world"))
        assert.falsy(Codec.decode("HCBBX:H:1"))
        assert.falsy(Codec.decode(""))
        assert.falsy(Codec.decode(nil))
        assert.falsy(Codec.decode(("x"):rep(400)))
    end)

    it("reports newer protocol majors distinctly", function()
        local t, err = Codec.decode("HCBB2:H:1:1:20:1:3:0:0.1.0")
        assert.falsy(t)
        assert.equal("version", err)
    end)

    it("rejects field-count and range violations", function()
        assert.falsy(Codec.decode("HCBB1:H:1:1:20:1:3:0"))          -- missing ver
        assert.falsy(Codec.decode("HCBB1:H:1:1:20:1:3:0:0.1.0:x"))  -- extra
        assert.falsy(Codec.decode("HCBB1:H:1:0:20:1:3:0:0.1.0"))    -- bossId 0
        assert.falsy(Codec.decode("HCBB1:H:1:1:20:0:3:0:0.1.0"))    -- roles 0
        assert.falsy(Codec.decode("HCBB1:N:X-1:pwned"))             -- bad reason
    end)

    it("rejects member lists that disagree with size", function()
        assert.falsy(Codec.decode("HCBB1:P:A-1:1:4:8:Aldric,1,20;Berylla,2,20;Corvin,8,20"))
    end)

    it("rejects duplicate member names", function()
        assert.falsy(Codec.decode("HCBB1:P:A-1:1:3:8:Aldric,1,20;Aldric,2,20;Corvin,8,20"))
    end)
end)

describe("Codec.isNewer", function()
    it("orders by major, then minor, then patch", function()
        assert.truthy(Codec.isNewer("1.0.0", "0.9.9"))
        assert.truthy(Codec.isNewer("0.2.0", "0.1.9"))
        assert.truthy(Codec.isNewer("0.1.2", "0.1.1"))
        assert.falsy(Codec.isNewer("0.1.1", "0.1.2"))
        assert.falsy(Codec.isNewer("0.9.9", "1.0.0"))
    end)

    it("compares patch numerically, not lexically", function()
        assert.truthy(Codec.isNewer("0.1.10", "0.1.9"))  -- 10 > 9
        assert.falsy(Codec.isNewer("0.1.9", "0.1.10"))
    end)

    it("is false for equal versions (no self-nag)", function()
        assert.falsy(Codec.isNewer("0.1.0", "0.1.0"))
    end)

    it("is false for malformed or missing versions (never nags on garbage)", function()
        assert.falsy(Codec.isNewer("1.0", "0.1.0"))
        assert.falsy(Codec.isNewer("0.1.0", "garbage"))
        assert.falsy(Codec.isNewer(nil, "0.1.0"))
        assert.falsy(Codec.isNewer("0.1.0", nil))
    end)
end)
