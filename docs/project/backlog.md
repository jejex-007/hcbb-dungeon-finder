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

## M6 — Post-v0.1.0 enhancements (M–L)
- [ ] **Version negotiation + mismatch notice** (NFR-C5): carry the addon
  *release* version (distinct from the wire protocol tag `HCBB<n>`) in comm
  messages so a client can detect peers running a different version and show a
  one-time, localized "an updated version is available" notice. Wire: add an
  optional trailing version field to HELLO (backward-compatible, same pattern
  as the class field — no protocol bump); compare on receive; surface at most
  once per session. Codec test for the new field. (S–M)
- [ ] **Per-game-mode class/role model** (CoA vs Warcraft Reborn): HCBB runs in
  two game modes with different class systems —
  - **Conquest of Azeroth (CoA)**: the 21 custom classes, **with** the Support
    role.
  - **Warcraft Reborn**: the 9 base WoW Classic classes, **no** Support role.

  The same client build must adapt to the active mode: (a) show the correct
  class set + colors; (b) drop the Support role entirely in Warcraft Reborn
  across registration (role cards), the matcher composition rule (≤1 support →
  tank/heal/DPS only), and the browser. Data-driven in `Data.lua`; mode
  detection mechanism TBD (`GetRealmName()` vs probing the local class token
  set). Cross-mode matching is moot (players are isolated per mode). (M)

## Open questions
- ~~Exact Boss Blitz marker~~ — RESOLVED 2026-07-13: permanent **debuff**
  "Hardcore - Boss Blitz", **spellId 93131**. Pinned in `Data.CHALLENGE_AURAS`
  (spellId primary, name fallback).
- Exact default brackets per boss: current rule `[unlock−4, unlock]` — validate
  in-game against real Blitz population, retune in `Data.lua`.
- ~~Channel name collision~~ — RESOLVED 2026-07-14: renamed the broadcast
  channel to `HCBBDungeonFinder` (unique enough to avoid accidental collision
  with a community-created channel). Obscurity is not security — the name is
  public in the repo; peer trust stays in NFR-S validation. Still worth a
  quick in-game check that the 10-channel join limit isn't hit on a
  channel-heavy character.
- Support role: confirm how CoA players identify "Support" builds in practice
  (pure declaration assumed).
