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
- [ ] Full 2-client match run on Ascension (the checklist end-to-end) (S) —
  **gates promotion to stable**
- [x] Pre-release **v0.1.0-beta** published 2026-07-14 (GitHub Release, zip
  asset, `--prerelease`) so testers can grab it while the smoke test is pending.
  Also `download/HCBBDungeonFinder-latest.zip` for non-Git players.
- [ ] Promote to stable **v0.1.0** tag + release after the 2-client smoke test,
  then announce (S)

## M6 — Post-v0.1.0 enhancements (M–L)
- [x] **Version negotiation + mismatch notice** (NFR-C5) — done 2026-07-14
  (actual ~0.5h). The `ver` field already rode in every HELLO; added
  `Codec.isNewer` (pure, numeric semver compare) and wired `Comm:OnChannel`
  to fire the existing once-per-session `NoticeNewerVersion` when a peer's
  release is strictly newer than ours. Message `MSG_NEWER_PROTO` is already
  update-generic in all 5 locales. Distinct from the proto-major drop (same
  proto still interoperates). 4 Codec regression tests (incl. 0.1.10 > 0.1.9).
  In-game 2-version validation pending (part of M5 smoke test).
- [x] **Per-game-mode class/role model** (CoA vs Warcraft Reborn) — done
  2026-07-14 (actual ~0.5h). Mode detection settled: the two modes are
  **separate realms** whose names embed the mode, so `GetRealmName()`
  distinguishes them (confirmed in-game: `Vol'jin - Conquest of Azeroth`,
  `Bronzebeard - Warcraft Reborn`). WR is detected by the `Data.WR_REALM_TAG`
  substring (`"Warcraft Reborn"`), default = CoA (any realm without the tag
  keeps the full set). Core sets `NS.gameMode` once at init; roles are declared
  per mode in `Data.MODE_ROLES` (mode is the source of truth, not a Support
  flag). In WR the Support card is simply absent from the mode's role set and
  the 3 remaining cards re-space to fill the same width (fill formula
  reproduces the 4-card layout exactly). Class
  set/colors were already mode-agnostic (`GetClassColor` uses
  `RAID_CLASS_COLORS` for base classes, custom table for CoA; class is auto-
  read, never picked). Matcher/wire needed no change — Support is already
  optional (≤1), a Support-less pool forms T/H/D (existing matcher test).
  In-game validation on Bronzebeard pending (part of M5 smoke test).
- [x] **In-game community links** (Join our Discord + Report a Bug) — done
  2026-07-14 (actual ~0.5h). Shared copyable-link popup (`UI.CopyPopup`, a
  `StaticPopup` with a pre-selected edit box, since the client has no browser
  and rejects clickable URLs); Discord invite in `Data.LINKS`; Report a Bug
  directs users to `#bug-report`; 5 locale keys; `OKAY` whitelisted. Copyable
  popup validated in-game.
- [x] **Auto release announcements to Discord** — done 2026-07-14 (actual
  ~0.5h). `.github/workflows/discord-release.yml` posts a rich embed (title +
  release notes + link) to `#announcements` on every published release, via the
  `DISCORD_WEBHOOK_URL` repo secret; replaced GitHub's native `/github` webhook.
  Verified end-to-end with a throwaway pre-release. Discord server set up
  (`#announcements` read-only + pinned message, `#bug-report`).

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
