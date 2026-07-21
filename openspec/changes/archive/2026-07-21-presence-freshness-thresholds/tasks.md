## 1. Constants (Data.lua)

- [x] 1.1 Add `PRESENCE_FRESH_GREEN = 120` and `PRESENCE_FRESH_YELLOW = 240` to the PRESENCE block of `Data.CONST`, with a comment stating the invariant (`FRESH_GREEN >= PING`) and pointing at the spec

## 2. Display (Playing.lua)

- [x] 2.1 Change `freshColor` to read `PRESENCE_FRESH_GREEN` / `PRESENCE_FRESH_YELLOW` instead of computing bands from `PRESENCE_PING`

## 3. OpenSpec enablement (one-time, rides the first change)

- [x] 3.1 Mark `docs/user-guide/business-rules.md` and `non-functional-requirements.md` with the "legacy — being absorbed into `openspec/specs/`" header
- [x] 3.2 Add the conflict rule to the project `CLAUDE.md`: once a capability has a spec under `openspec/specs/`, that spec wins over any legacy doc

## 4. Verify

- [x] 4.1 luacheck clean
- [x] 4.2 busted/tests.run.lua green (no behaviour change expected)
- [x] 4.3 Deploy to the game `AddOns/` folder, visually confirm no change in Who's Playing dot colours via `/hcbb demo` — confirmed in-game 2026-07-21
- [x] 4.4 Add a smoke-test note recording the presence dots are now data-driven
