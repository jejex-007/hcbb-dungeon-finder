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
  AceComm whisper, InviteUnit popup (S) — **gates the release**. Partly done
  2026-07-16: **channel join/send/receive proved between distant clients** by
  real beta players showing up in Who's Playing (see the smoke-test validation
  log) — no second account was needed. AceComm whisper and the InviteUnit popup
  still need the matchmaking path.

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
  **gates promotion to stable**. Narrowed 2026-07-16: the comm half is proved
  in the wild (presence pings, TTL, sweep); what remains is strictly the
  matchmaking path — two players registered on the **same boss, same bracket,
  at the same time** → proposal → invite → party. Who's Playing now doubles as
  the recruiting tool for it: the peers listed there are online, on 0.2.0, and
  whisperable (one answered on 2026-07-16).
  **This needs two real people — Ascension bans for multiboxing**, so a second
  client side by side is not an option on a hardcore realm. That makes player
  adoption (guild message, forum, Discord) the critical path to a stable tag,
  not a marketing side quest: the gate cannot be forced open by working
  harder, only by more Blitz players running the addon in the same bracket.
- [x] Pre-release **v0.1.0-beta** published 2026-07-14 (GitHub Release, zip
  asset, `--prerelease`) so testers can grab it while the smoke test is pending.
  Also `download/HCBBDungeonFinder-latest.zip` for non-Git players.
- [x] Pre-release **v0.2.0** published 2026-07-15 (Who's Playing + the event
  fix), announced automatically in Discord `#announcements` by the release
  workflow, plus a forum follow-up. Still a pre-release: the event fix cannot
  be verified solo.
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

- [x] **Who's Playing tab** (R25) — done 2026-07-15 (est. L, actual ~1.5h).
  Online-presence list (name, class, level, 2 primary professions + rank),
  independent of any search. New wire type `W`, additive under the same
  protocol major (adding a type must never bump the major — a `HCBB2` bump
  would make 0.1.x reject even HELLO). `W` carries `ver`, making the update
  notice reliable from 0.2.0 onwards. Own `Presence` store (separate
  lifecycle from `Pool`), ping 120 s + jitter on first `CHANNEL_UP`,
  ChatThrottleLib BULK, opt-out in Options. Professions via `isAbandonable` +
  `PROF_ABBREV` (both filters needed; Ascension's Woodcutting/Woodworking are
  abandonable but excluded), localized via `PROF_*` keys. Shipped in
  **pre-release v0.2.0** (`.toc` bumped — without it `ver` stays 0.1.0 and no
  notice fires).

## M7 — Post-beta user reports (rolling)

Bugs and requests from real users, starting with the 2026-07-15 beta
announcement (forums + community Discords). Reports land in `#bug-report`.

- [x] **Event subscriptions silently overwritten (critical)** — found
  2026-07-15 while wiring R25, fixed same day (actual ~0.4h). `CallbackHandler`
  keeps one callback per (message, object), so modules sharing `NS.addon`
  overwrote each other with no error. `Session:OnPoolChanged` was dead →
  **reactive matching was broken** (only 91 s/181 s timers fired; nothing at
  all past 181 s); `Session:OnChannelUp/Down` dead → PAUSED never resumed;
  `ProposalPopup` lost `HCBB_STATE_CHANGED`. Every module now owns its
  AceEvent target (`UI.Listener()` / `Embed`). **Still unverified in-game** —
  needs the 2-client run, since it cannot reproduce solo. Likely explains any
  "matching seems broken" report on pre-0.2.0 builds.
- [x] **Roles hint / error text overlapped** — reported 2026-07-15 (first user
  ticket), fixed same day (actual ~0.2h). `hintRoles` and `errText` share one
  anchor by design (no room for both above `MIN_LABEL`), but `validate()` only
  ever showed the error and never hid the hint, so they rendered on top of each
  other with no role ticked. Fixed via `setRoleError()` (mutual exclusion, also
  wired into the not-enrolled / already-grouped early returns). Affected both
  modes since the start, not WR-specific. Not unit-testable (UI layout, no WoW
  API in CI) — regression pinned in `docs/project/smoke-test.md`.

- [x] **Red freshness dot unreachable in Who's Looking** (cosmetic, S) — found
  2026-07-16, fixed same day. `FRESH_YELLOW` == `EXPIRY` == 120 s meant a
  listing was evicted at the exact moment it would turn red. Dropped
  `FRESH_YELLOW` to 90 s, giving red a real 30 s window [90, 120) without
  touching the 120 s eviction (R17 updated). Purely a browser colour band —
  matching and the counter use `FRESH_GREEN`, so nothing else moved. Surfaced
  and fixed while making `/hcbb demo` show a yellow and a red listing to
  validate R26.
- [x] **Fresh-only matching + active/total counter** (R26, S) — 2026-07-16.
  Matching ignores listings older than `FRESH_GREEN` (60 s), so a quiet client
  is never proposed into a group it can't answer. `Pool:CountBracket` returns
  (fresh, total); the Find-Group line reads "N active (M total)" when some are
  stale. Validated in-game ("6 active (8 total)" during a live search). The
  matching-exclusion half still wants the 2-client run to confirm end-to-end.
- [x] **Cleared tick locked past a boss's level** (R27, S) — 2026-07-16. A boss
  whose unlock level you've reached is auto-ticked and can't be un-ticked
  (killing it was required to level past it); tooltip explains instead of
  offering the toggle. Validated in-game on a level-29 character.

## M8 — Multi-dungeon selection (L–XL)

- [ ] **Register for several dungeons at once** — designed 2026-07-16, not
  built. The Find-Group list becomes multi-select (all bosses the level allows;
  e.g. at 30: RFK and/or Gnomeregan and/or SM:GY). Matching priority: (1)
  largest feasible group, (2) tie-broken by earliest boss in the progression
  order (not the player's click order). The ACK round-trip already absorbs the
  divergence when players' target sets overlap (a member gone elsewhere replies
  "busy" → clean retry, no dead end), which is what makes it feasible serverless.
  **Gates**:
  - **Wire decision (blocking, needs an explicit call).** HELLO carries one
    `bossId`. Options: (a) list in the field `id,id,id` — clients ≤ 0.2.0 stop
    seeing those listings (invisibility, not a crash); recommended, we're
    pre-release and everyone's on 0.2.0. (b) a new additive type like `W` —
    full compat, doubles the emit logic. Do not touch the wire without a go.
  - **Matcher rework**: loop `findForSelf` per targeted boss + a priority layer;
    more failed proposals when target sets overlap (bounded by the ACK filter).
  - **UI**: picker mono → multi-check; **effort L, possibly XL with tests.**

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
