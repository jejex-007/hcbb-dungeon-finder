# Changelog — HCBB Dungeon Finder

## 2026-07-15 — Who's Playing tab (R25) + pre-release v0.2.0
- New **Who's Playing** tab: every enrolled player currently online with the
  addon — name, class, level, and the two primary professions with rank —
  independent of any search. Right-click reuses the browser's native player
  menu. The point, now that the challenge is over: the population is thin
  enough that "is anyone even playing?" matters more than matchmaking itself.
- Wire: new **PRESENCE `W`** type, **additive under the same protocol major**.
  `Codec.decode` reports an unknown *type* separately from an unknown *major*
  and `Comm` drops the former silently, so a 0.1.x client ignores `W` without
  crashing or firing a false update notice. Bumping to `HCBB2` would instead
  make it reject *every* message, HELLO included — **adding a type must never
  bump the major**. `W` carries `ver` on purpose: every online client pings,
  whereas HELLO only goes out while searching, so the update notice (NFR-C5)
  becomes reliable instead of opportunistic — for 0.2.0+ peers only, since
  0.1.0 ignores `W` by design.
- Professions are read off the skill sheet (3.3.5 has no `GetProfessions()`),
  filtered on `isAbandonable` **and** on membership in `Data.PROF_ABBREV`.
  Both filters are needed: abandonability alone also matches Ascension's custom
  Woodcutting/Woodworking, filed under "Secondary Skills" yet costing a slot
  like a primary (verified in-game on both realms via a throwaway
  `/hcbb skills` dump, since removed). Names localized from `PROF_*` keys; the
  wire only carries `bs147`.
- `Presence` is its own store, separate from `Pool`: searchers (short TTL,
  HELLO/BYE) and online players (long TTL, ping) have different lifecycles. A
  BYE never touches it — "stopped searching" is not "logged off"; offline is
  TTL-detected, as a client can't reliably announce its own disconnect.
- Ping at 120 s + jitter, started on the first `CHANNEL_UP` (a ping fired
  before the channel join is dropped, and the player would then wait a full
  interval to appear). `Comm:Broadcast` now goes through **ChatThrottleLib at
  BULK** as NFR-P2 already required — with every online client pinging, volume
  scales with population and unthrottled sends risk an anti-spam disconnect.
- Opt-out in Options: removes you from your own list immediately; peers drop
  you at TTL (a sent ping can't be recalled). Re-enabling re-announces at once.
- **Version bumped to 0.2.0** — the wire `ver` comes from `GetAddOnMetadata`,
  so without the bump every client would still advertise 0.1.0 and no update
  notice would ever fire. Published as **pre-release v0.2.0**; the GitHub →
  Discord workflow announced it automatically (its first real use).
- Docs: R25, NFR-S3 (amended for class + professions), NFR-A2, NFR-P2,
  architecture §3/§4/§5, README, smoke-test. 4 new Codec tests (37 total).
- Known gap: the update notice barely reaches 0.1.0 clients (they only listen
  on HELLO, i.e. only while someone actively searches), so forum + Discord did
  the announcing this time.

## 2026-07-15 — Fix: modules silently overwriting each other's event subscriptions
- `CallbackHandler` stores **one callback per (message, object)** —
  `events[eventname][self] = func`; its own source comments "that one member
  may have been overwritten". Every module subscribed through the shared
  `NS.addon` object, so the last registration silently replaced the others.
  No error, no warning — the losing module simply became dead code.
- Three subscriptions were dead: **`Session:OnPoolChanged`** lost
  `HCBB_POOL_CHANGED` to the Browser, which **killed reactive matching** (only
  the 91 s/181 s grace timers still fired, so a peer arriving after 181 s could
  never be matched at all); **`Session:OnChannelUp/Down`** lost to MainFrame, so
  a search paused by a channel drop never resumed; **`ProposalPopup`** lost
  `HCBB_STATE_CHANGED`.
- It hid because the solo demo never exercises those paths and no two-client
  run had ever happened — there was nobody else online. Surfaced only because
  the R25 ping (registered the same way) never fired.
- Every module now owns its AceEvent target: `Session`/`Presence` embed it on
  themselves, UI modules take one from the new `UI.Listener()`. Firing
  (`SendMessage`) was never affected — only registration collides. Documented
  in architecture §8 and in project memory.
- **Not observable solo**: reactive matching and PAUSED resume need two
  clients, so this is reasoned from the library source, not yet verified
  in-game — which is why v0.2.0 ships as a pre-release.

## 2026-07-15 — Fix: roles hint and error text overlapped (first user report)
- The grey roles hint and the red "Select at least one role" error deliberately
  share a single anchor (there is no room for both lines above `MIN_LABEL`), so
  the error is meant to *replace* the hint. `validate()` only ever showed/hid
  the error and never touched the hint, so both rendered on top of each other
  whenever no role was ticked. New `setRoleError()` owns the swap and keeps
  exactly one visible; it is also wired into the not-enrolled and
  already-grouped early returns, which used to hide the error without bringing
  the hint back. Affected **both game modes** since the start (the anchor is
  mode-independent) — the report came from Warcraft Reborn.
- First bug reported by a real user after the 2026-07-15 beta announcement.
  UI layout is not unit-testable (the CI has no WoW API, `IsShown()` can't be
  asserted), so the regression is pinned as an explicit case in
  `docs/project/smoke-test.md` instead of a hollow mock. Validated in-game.

## 2026-07-14 — In-game Discord links + auto release announcements
- Options tab gained a **Community & support** section with two buttons:
  **Join our Discord** and **Report a Bug** (which points users at the
  `#bug-report` channel). Both open a shared copyable-link popup
  (`UI.CopyPopup`, a `StaticPopup` with a pre-selected edit box) — the client
  has no in-game browser and rejects clickable URLs, so the link sits ready for
  a one-keystroke Ctrl+C. URLs live in `Data.LINKS`. Five new locale keys
  (`OPT_COMMUNITY`, `OPT_DISCORD`, `OPT_REPORT_BUG`, `DISCORD_POPUP`,
  `REPORT_POPUP`) in all five languages; `OKAY` whitelisted (luacheck + luarc);
  README **Community & support** section; architecture.md note; download bundle
  refreshed. Copyable-popup mechanism validated in-game.
- **GitHub → Discord release announcements**: new
  `.github/workflows/discord-release.yml` posts a rich embed (title + release
  notes + link, gold accent) to `#announcements` on every published release,
  via the `DISCORD_WEBHOOK_URL` repo secret. Replaces GitHub's native `/github`
  webhook (a bare one-liner with no description). Verified end-to-end with a
  throwaway pre-release; the native webhook was removed to avoid duplicates.

## 2026-07-14 — Update notice as an accent banner in the status strip
- The version-mismatch notice was chat-only (easy to miss). It now also turns
  the window's status strip into an accent banner (dark-amber fill, gold text)
  while an update is pending — persistent for the session, the state dot still
  shows live state. `NoticeNewerVersion` sets `NS.updateAvailable` + fires
  `HCBB_UPDATE_AVAILABLE`; `UpdateStatus` gives it priority. New `ST_UPDATE`
  locale key in all five languages. Validated in-game (0.0.9 client seeing a
  0.1.0 peer). Refreshed `download/HCBBDungeonFinder-latest.zip`.

## 2026-07-14 — Pre-release v0.1.0-beta
- Published the first GitHub Release: **v0.1.0-beta** (`--prerelease`), with the
  packaged zip as an asset, so testers can install from the Releases page while
  the full 2-client smoke test is still pending. The `.toc` version stays
  `0.1.0` (the wire `ver` field requires strict `X.Y.Z`; only the Git tag
  carries `-beta`). NFR-C1 re-checked: Interface 30300, luacheck green.
  Promotion to stable v0.1.0 gated on the smoke test.

## 2026-07-14 — One-click download for players without Git
- Added `download/HCBBDungeonFinder-latest.zip` (both addon folders) plus a
  direct download link in the README install section, so players who don't use
  Git can install without cloning. `scripts/package.ps1` now builds the zip via
  .NET `ZipArchive` with explicit forward-slash entry names — Windows PowerShell
  5.1's `Compress-Archive`/`ZipFile` write backslash separators that 7-Zip and
  WinRAR mishandle — and refreshes this bundle on every run. `.gitignore` keeps
  `*.zip` out except this one. Regenerate before pushing addon code changes.

## 2026-07-14 — Per-game-mode role model (Warcraft Reborn, M6.2)
- HCBB runs in two modes on separate realms whose names embed the mode, so
  `GetRealmName()` (matched against `Data.WR_REALM_TAG`) sets `NS.gameMode` at
  init. Roles are declared per mode in `Data.MODE_ROLES`: **Conquest of Azeroth**
  keeps the Support role, **Warcraft Reborn** (9 base classes) drops it. The
  Registration role cards are built from the mode's set and re-space to fill the
  same width (fill formula reproduces the 4-card layout exactly). The demo
  mirrors the mode (base classes, no Support). Nothing downstream changed — the
  matcher already treats Support as optional; class colors were mode-agnostic.
- Detection settled after in-game testing: the realm name is the full string
  (e.g. `Bronzebeard - Warcraft Reborn`), so an exact-key lookup missed —
  switched to a case-insensitive substring match on the mode tag.
- Docs: BR header + R3 + R7, NFR-C6, README, architecture. luacheck 0/0,
  tests 33/0, CI green.

## 2026-07-14 — Version-mismatch update notice (NFR-C5, M6.1)
- A peer HELLO advertising a strictly newer release version now triggers a
  single per-session "update available" notice. Added `Codec.isNewer` (pure,
  numeric semver compare, so 0.1.10 > 0.1.9) wired into `Comm:OnChannel` via the
  existing once-per-session sink. Distinct from the proto-major drop (same proto
  still interoperates). 4 Codec regression tests.

## 2026-07-14 — UI polish (checkbox labels, proposal class tooltip)
- Checkbox labels are now clickable (shared `UI.Check` hit area, gated on the
  box being enabled) — lead opt-in and options toggles alike.
- The proposal popup shows a class tooltip on member hover, reusing the
  browser's mechanism (class resolved from the local pool, or `UnitClass` for
  self, since the P wire doesn't carry it).
- Demo fidelity: a demo group formation now ends a live search (no real party
  fires `OnParty`), so the demo mirrors leaving the queue; and the demo's fake
  proposal/pool honor the active mode (no Support member in Warcraft Reborn).

## 2026-07-14 — Rename broadcast channel (collision hardening)
- Renamed the hidden broadcast channel `HCBBLFG` → `HCBBDungeonFinder`
  (`Data.CONST.CHANNEL`) so it can't accidentally collide with a
  community-created chat channel of the same generic name. Purely collision
  hardening, not security — the name is public in the repo; peer trust stays
  in NFR-S validation. The channel is resolved by name everywhere, so no
  numbering assumptions change. Decided before v0.1.0 while there are no users
  (renaming after release would fragment the community). README + architecture
  + the backlog open question updated. luacheck 0/0, tests 29/0, CI green.
- Also groomed the backlog: added M6 (post-v0.1.0 enhancements) — version
  negotiation + mismatch notice (NFR-C5), and a per-game-mode class/role model
  (CoA 21 classes with Support vs Warcraft Reborn 9 base classes, no Support).

## 2026-07-14 — Harden diagnostic slash commands
- Removed `/hcbb debug`: its live "print every message" mode could flood the
  chat and lag the client under heavy channel traffic. Debug is now a silent
  capped ring buffer (50 events); the channel is always hidden from chat.
- `/hcbb log` prints at most the last 50 comm events (was up to 100).
- Removed `/hcbb auras` (one-shot used to discover the Boss Blitz debuff
  spellId 93131, now hard-coded). Docs/locales updated. CI green.

## 2026-07-14 — First public push (CI green)
- Created the public repo `jejex-007/hcbb-dungeon-finder` and pushed `main`.
  Commits authored/committed as KySeEtH <jejex-007@users.noreply.github.com>;
  full identity grep clean.
- CI fix: `luacheck` was linting the CI-installed `.luarocks` deps (1731
  third-party warnings) and failing the build; now lints explicit source
  dirs + excludes `.luarocks`. Lint + busted green on Ubuntu / Lua 5.1.

## 2026-07-14 — Documentation review before first public push
- Aligned the docs with the shipped implementation (public repo hygiene):
  - `architecture.md`: strict-charset validation (not `\c` escaping),
    heartbeat 30 s / expiry 120 s, added the SUGGEST (S) group message and
    the PARTY/RAID transport row, fixed the DPS-leader hash (member names,
    not matchId), COLLECTING→FORMING, removed the non-existent StatusStrip.lua,
    and a UI-behaviours section (class colors, native menu, combat close,
    grouped-disable, flat-tint rendering note).
  - NFR-A1 / NFR-L1: localization is a hand-rolled proxy, not AceLocale.
  - README: added `/hcbb log` and `/hcbb auras`, browser + behaviour features.
  - Created `docs/project/smoke-test.md` (was referenced but missing).
- Privacy hardening for the public repo: removed the first name from
  `CLAUDE.md` and the private design-project UUID from the mockup notes.
  Grep confirms zero real-name/email tokens across the tree.

## 2026-07-14 — Fix proposal countdown bar hiding its text
- The countdown fill lived in a child frame (higher frame level), so it drew
  over the timer text. Moved the fill to an ARTWORK texture on the bar frame
  itself; the text (OVERLAY) now renders above it.

## 2026-07-14 — Show player class (with class color) in the browser
- "Who's Looking" now colors each player's name by their class color and
  shows the class in the hover tooltip. CoA class tables (token ↔ 2-letter
  abbrev ↔ display name ↔ color) added to `Data.lua`, mirroring LootCollector;
  own class read via `UnitClass("player")`.
- **Wire:** HELLO gains an optional trailing class field
  (`…:<ver>[:<class>]`). Backward-compatible — decoder accepts 9 or 10
  fields, so NO wire-version bump and cross-version clients still match
  (a client without the field just shows no class). Codec test added.

## 2026-07-14 — Use Ascension's native player menu in the browser
- Clicking a listing (any mouse button) now opens the game's native player
  dropdown via `FriendsFrame_ShowDropdown` — the standard path used by the
  Who/friends/guild lists, which on Ascension includes "Suggest Invite"
  alongside Invite/Whisper, context-aware. Falls back to the custom menu
  (and its addon-message suggest path) if unavailable or it errors.
  (First attempt used `UnitPopup_ShowMenu("PLAYER")` on left-click only —
  didn't work on this client; switched to the friends dropdown + any-click.)

## 2026-07-14 — Clickable "suggest invite" via addon message
- The server rejects clickable player links in chat (`SendChatMessage`:
  "Invalid escape code"), so suggest-invite now sends an **addon** message
  to the party/raid (new wire type `S`, Codec + test). The leader's client
  (only one that can invite) pops a `StaticPopup` with a clickable **Invite**
  button. A plain-text chat line is still posted as a fallback for a leader
  without the addon. Verified no crash whether or not the leader runs the
  addon (clients without it silently ignore the addon message).

## 2026-07-14 — Behaviour: auto-close in combat, no search while grouped
- The window now auto-closes on entering combat (`PLAYER_REGEN_DISABLED`);
  hiding never cancels an active search (Session state is independent).
- "Search for Group" is disabled whenever the player is in a party/raid
  (with an explanatory hint); `Session:StartSearch` also refuses if grouped.
  `Session:OnParty` fires a new `HCBB_GROUP_CHANGED` message so the button
  updates even when no state transition occurs (idle + manually grouped).

## 2026-07-14 — Fix cleared/status marks rendering as green "?"
- The 3.3.5 game font lacks the ✓/✗ glyphs, so the cleared-boss marker (and
  proposal member status) rendered as a green "?". Replaced with inline
  ready-check textures (`UI.ICON.check/cross/wait`); proposal accept count
  now tracks a boolean flag instead of parsing the glyph.

## 2026-07-13 — Level brackets, lead icon, browser quick-actions
- **Brackets corrected** (R2/§7): a boss must be killed *before* its "beyond"
  level, so the ceiling is `unlock-1` and the floor `ceiling-3` →
  `[unlock-4, unlock-1]`. E.g. VanCleef (beyond 21) is now 17–20, not 17–21.
  Data-driven in `Data.lua`.
- **Lead icon**: added the leader crown next to the "I'm willing to lead the
  group" checkbox (design 1a).
- **Browser quick-actions** (new R24): left-click a listing in "Who's
  Looking" opens a contextual menu — Invite (when solo or leader), else
  Suggest to group leader (party/raid chat), plus Whisper. Own listing is
  inert. Tooltip gains a "Click for options" hint. New locale keys in all
  five languages.

## 2026-07-13 — Fix white button backgrounds (client ignores gradients)
- Root cause: the Ascension client honors `SetVertexColor` (status dots tint
  fine) but ignores `SetGradientAlpha`, which left fill textures white.
  Replaced all gradient fills with flat `SetVertexColor` tints in the
  gradient's average color (`UI.Fill` + new `UI.Recolor` for tabs/bars).
  Buttons, tabs, title bar, strip, countdown now show solid correct colors.

## 2026-07-13 — UI fixes (close button, button backgrounds)
- Close button: replaced the Blizzard `UIPanelCloseButton` (rendered blank /
  not clickable here) with a custom styled button, raised above the drag
  zone (title bar now stops short of it) so its whole area is clickable.
- Button backgrounds: buttons now use an edge-only backdrop (no white bgFile
  leaking under the gradient fill), and `UI.Fill` sets a solid base color
  before the gradient so buttons read correctly even if the client ignores
  SetGradientAlpha. Tabs get the same base-color fallback.

## 2026-07-13 — UI fidelity pass (match the design mockup)
First in-game test feedback → reworked the UI to follow the Claude design
mockup faithfully (docs/reference/sources):
- Shared widget factory rebuilt with vertical gradients (`SetGradientAlpha`),
  1 px bevels, gold serif title bar. Panels/buttons now gradient, not flat.
- **Role icons**: real game LFG role atlas for Tank/Heal/DPS + a spell icon
  for Support (replaces the letter badges) in registration, browser, popup.
- **Tabs**: flow layout — each tab sized to its text and chained, so longer
  localized labels no longer overlap.
- **Above WeakAuras**: main window strata DIALOG + toplevel + Raise on show;
  proposal popup strata FULLSCREEN_DIALOG.
- **Status strip** redesigned per 1j: pulsing state dot + colored state text
  on the left, channel dot + "LFG channel" label on the right.
- Registration: red "Search for Group" action button, role cards with icons,
  custom radios with the yellow center dot, black inset boss picker.
- Proposal: you-banner leads with the assigned role, gradient countdown bar
  (green on forming), **Accept now locks both Accept and Decline**, footer
  swaps in place with an Okay button.
- Locales: added the new keys (ST_SEARCH_FULL, CH_LABEL, PROP_TIMER, PROP_OF,
  BTN_OKAY, ROLES_HINT…) in all five languages; fixed PROP_YOU_ROLE to a
  label (role shown separately).
- luacheck clean (19 files), tests 26 green.

## 2026-07-13 — Load-time gate via loader addon (R23 hardening)
- Requirement sharpened: a non-participant character must not even *load*
  the addon. Since 3.3.5 loads every enabled addon at login and the debuff
  isn't readable that early, added the standard LoadOnDemand loader pattern:
  - New tiny always-loaded `HCBBDungeonFinder_Loader` (Loader.lua): scans
    for the marker (buff+debuff, spellId 93131 / name), `LoadAddOn` the main
    addon only if present; stops listening once loaded; handles a manually
    disabled main via EnableAddOn.
  - Main addon flagged `## LoadOnDemand: 1`; `OnEnable` now also checks
    eligibility immediately (it may load after PLAYER_ENTERING_WORLD).
  - Distribution is now two folders; package script, README install, and
    architecture updated. The runtime R23 gate stays as a safety net (an
    addon cannot unload if the debuff is lost mid-session).

## 2026-07-13 — Participation gate (R23)
- Bug report from first in-game look: any character could register. Added
  R23 (participants only) to the business rules and implemented the gate:
  aura detection (`Data.CHALLENGE_AURAS`, data-driven; UNIT_AURA rechecks
  debounced), channel join and StartSearch guarded, UI parked with a
  localized notice (status strip, red dot, disabled Find tab), search
  auto-cancelled if the marker disappears (challenge failed).
- Marker confirmed in-game: the mode is a permanent **debuff**
  "Hardcore - Boss Blitz" (spellId 93131). Scan covers both buffs and
  debuffs; `Data.CHALLENGE_AURAS` pins spellId 93131 (primary) + name
  (fallback). Debug helper `/hcbb auras` lists buffs and debuffs with
  spellIds.

## 2026-07-13 — Full v0.1.0 implementation (evening session)
- Imported the Claude design mockup (via DesignSync) and archived it as
  source of truth → `docs/reference/sources/2026-07-13-hcbb-dungeon-finder.dc.html`
  + import notes. Docs aligned: heartbeat 30 s / expiry 120 s, FORMING and
  PAUSED states.
- Implemented the complete addon under `HCBBDungeonFinder/`:
  - Pinned Ace3 libs copied from addons proven on Ascension (`libs/VERSIONS.md`).
  - `Data.lua` (25-boss table, brackets, protocol constants), `Codec.lua`
    (wire protocol v1, strict validation), `Pool.lua` (presence replica),
    `Matcher.lua` (deterministic windows + backtracking + leader election),
    `Session.lua` (7-state negotiation machine), `Comm.lua` (hidden channel
    + AceComm whispers), `Core.lua` (bootstrap, DB, hand-rolled locale proxy,
    cleared-boss tracking, `/hcbb demo`).
  - UI per the mockup spec: MainFrame + tabs + status strip, Registration,
    Browser (virtualized), ProposalPopup (countdown + auto-decline), Options
    (instant language switch), Minimap button.
  - Locales complete in EN/FR/DE/ES/IT.
- Quality rig: `.luacheckrc` (0 warnings / 0 errors on 21 files),
  busted-compatible specs (26 green) + zero-dependency `tests/run.lua`,
  GitHub Actions CI, `scripts/package.ps1`, README, MIT LICENSE (KySeEtH).
- Local git repo initialized with noreply identity. Not yet pushed —
  GitHub repo creation and in-game smoke test are next.

## 2026-07-13 — Project bootstrap (docs only)
- Environment survey of WoW Ascension addon platform (client 3.3.5a,
  Interface 30300, Ace3/AceComm proven, hidden-channel broadcast pattern
  validated via LootCollector) → `docs/design/ascension-addon-environment.md`.
- Business rules R1–R22 with the season's 25-boss progression table →
  `docs/user-guide/business-rules.md`.
- Non-functional requirements (compatibility, safety, architecture, perf,
  data, observability, tests, l10n) →
  `docs/user-guide/non-functional-requirements.md`.
- Decentralized architecture & wire protocol v1 (hidden channel + addon
  whispers, leader-acts coordination, deterministic matcher) →
  `docs/design/architecture.md`.
- UX design prompt for the Claude design session →
  `docs/design/ux-design-prompt.md`.
- Project working agreement (`CLAUDE.md`), backlog M0–M5, tracking files.
