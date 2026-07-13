# Backlog — HCBB Dungeon Finder

Effort scale (owner+Claude pair velocity): S < 1h · M 1–2h · L 3–5h · XL 6–8h.

## M0 — Bootstrap & environment validation (S–M)
- [x] Environment survey (client 3.3.5a, Ace3/AceComm proven, channel pattern) — done 2026-07-13
- [x] BR / NFR / architecture / UX prompt — done 2026-07-13
- [x] Local repo scaffolding: git init + noreply identity, LICENSE (MIT,
  KySeEtH), README, `.gitignore`, `.luacheckrc`, `.luarc.json`, CI workflow,
  packaging script — done 2026-07-13 (actual: bundled into impl session)
- [x] Create the public GitHub repo (`jejex-007/hcbb-dungeon-finder`) + first
  push, CI green — done 2026-07-14 (identity audit clean: KySeEtH/noreply)
- [ ] In-game smoke test with 2 accounts: custom channel join/hide/send/receive,
  AceComm whisper, InviteUnit popup (S) — **gates the release**

## M1 — Skeleton & data — done 2026-07-13 (actual ~0.5h)
- [x] Embedded pinned libs (copied from proven Ascension addons) + VERSIONS.md;
  .toc; AceAddon bootstrap; `/hcbb` slash (AceLocale dropped for a hand-rolled
  locale proxy: manual override R21 + instant switch)
- [x] `Data.lua`: 25-boss table, brackets + SavedVariables overrides, timings
- [x] `Locales/`: enUS/frFR/deDE/esES/itIT complete

## M2 — Comm layer — done 2026-07-13 (actual ~0.5h)
- [x] `Codec.lua` + spec suite (13 tests)
- [x] `Comm.lua`: channel lifecycle, routing, chat filter, health events
- [x] `Pool.lua`: replica, TTL, cap, dedupe, rate limit

## M3 — Matchmaking — done 2026-07-13 (actual ~0.5h)
- [x] `Matcher.lua` + spec suite (13 tests): windows, backtracking roles,
  deterministic election (hashed DPS), findForSelf peeling
- [x] `Session.lua`: 7-state machine incl. FORMING watchdog + PAUSED

## M4 — UI — done 2026-07-13 (actual ~1h, from the Claude design mockup)
- [x] Design mockup imported + archived (docs/reference/sources/)
- [x] MainFrame (tabs, status strip, channel dot) + Registration tab
- [x] Proposal popup (countdown, you-banner, auto-decline) + minimap button
- [x] Browser tab (virtualized) + Options tab (language hot-switch)
- [x] `/hcbb demo` solo visual smoke mode

## M5 — Beta & release (M)
- [x] In-game load test on Ascension — done 2026-07-14 (iterated extensively:
  UI fidelity, class colors, native menu, combat/group behaviours, bracket fix)
- [x] `docs/project/smoke-test.md` checklist written — done 2026-07-14
- [ ] Full 2-client match run on Ascension (the checklist end-to-end) (S)
- [ ] v0.1.0 tag, GitHub release zip (scripts/package.ps1), announce (S)

## Open questions
- ~~Exact Boss Blitz marker~~ — RESOLVED 2026-07-13: permanent **debuff**
  "Hardcore - Boss Blitz", **spellId 93131**. Pinned in `Data.CHALLENGE_AURAS`
  (spellId primary, name fallback).
- Exact default brackets per boss: current rule `[unlock−4, unlock]` — validate
  in-game against real Blitz population, retune in `Data.lua`.
- Channel name `HCBBLFG`: check in-game for collisions with existing community
  channels before freezing the constant.
- Support role: confirm how CoA players identify "Support" builds in practice
  (pure declaration assumed).
