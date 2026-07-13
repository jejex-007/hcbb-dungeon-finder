-- Zero-dependency test runner exposing the subset of the busted API used by
-- the specs, so they run on any plain Lua (5.1+) without luarocks:
--   lua tests/run.lua        (from the repo root)
-- CI uses real busted; this runner is for local dev on machines without it.
local passed, failed = 0, {}
local context = ""

local function fail(msg)
    error({ hcbbTestFailure = msg }, 0)
end

assert = setmetatable({
    equal = function(expected, actual)
        if expected ~= actual then
            fail(("expected %s, got %s"):format(tostring(expected), tostring(actual)))
        end
    end,
    truthy = function(v)
        if not v then fail("expected truthy, got " .. tostring(v)) end
    end,
    falsy = function(v)
        if v then fail("expected falsy, got " .. tostring(v)) end
    end,
}, { __call = function(_, v, msg) if not v then fail(msg or "assertion failed") end return v end })

function describe(name, fn)
    local prev = context
    context = context .. name .. " > "
    fn()
    context = prev
end

function it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        local msg = type(err) == "table" and err.hcbbTestFailure or tostring(err)
        failed[#failed + 1] = context .. name .. ": " .. msg
    end
end

package.path = "./?.lua;" .. package.path

local specs = { "tests.codec_spec", "tests.matcher_spec" }
for _, spec in ipairs(specs) do
    require(spec)
end

print(("%d passed, %d failed"):format(passed, #failed))
for _, line in ipairs(failed) do print("FAIL " .. line) end
if #failed > 0 then os.exit(1) end
