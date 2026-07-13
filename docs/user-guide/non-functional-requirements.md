# HCBB Dungeon Finder — Non-Functional Requirements

Canonical technical rules. They condition HOW we implement the business
rules. IDs are stable — never renumber, only append.
Environment ground truth: `docs/design/ascension-addon-environment.md`.

## NFR-C — Compatibility

- **NFR-C1.** Target client is WotLK 3.3.5a (`## Interface: 30300`), Lua 5.1.
  No API introduced after 3.3.5 (`C_Timer`, `C_ChatInfo`, `C_Map`…), no Lua
  5.2+ constructs (`goto`, bit operators…).
- **NFR-C2.** Wire messages never exceed **240 bytes** (hard client limit
  ~255 incl. prefix; AceComm chunking is allowed on whispers only, never on
  the broadcast channel).
- **NFR-C3.** Channel payloads use printable ASCII only (chat channel
  constraint). Field separator must be escaped or forbidden in values.
- **NFR-C4.** The addon must coexist with the common Ascension addon set
  (Details, WeakAuras, VuhDo, AdiBags, LootCollector…): no global namespace
  pollution (single global `HCBB`), no hooks on shared functions, embedded
  libraries loaded via LibStub with proper minor-version negotiation.
- **NFR-C5.** Must behave sanely when peers run different addon versions:
  every message carries a protocol version; newer-major messages are ignored;
  a newer-version notice may be shown to the user once per session.

## NFR-S — Safety & security

- **NFR-S1.** Never call protected functions from insecure paths; no
  automation of gameplay decisions (see R19). Party invites via
  `InviteUnit()` are allowed; accepting invites is always manual.
- **NFR-S2.** All inbound data is untrusted: length-check, type-check and
  range-check every field before use; drop silently on failure (no error
  spam an attacker can trigger). Sender identity is taken from the chat
  event's `sender` argument (server-authenticated), never from the payload.
- **NFR-S3.** No personal data beyond character name, level, and declared
  preferences ever leaves the client.
- **NFR-S4.** The broadcast channel is public by nature; assume hostile
  readers and writers. The addon must remain stable under malformed,
  flooding, or impersonating traffic (rate-limit per sender, dedupe).

## NFR-A — Architecture

- **NFR-A1.** Ace3 stack: AceAddon, AceEvent, AceTimer, AceComm (+
  ChatThrottleLib), AceConsole, AceDB. Libraries are embedded (no external
  dependency for users) and pinned; upstream source noted in
  `libs/VERSIONS.md`. Localization is a hand-rolled proxy in `Core.lua`
  (not AceLocale) — see NFR-L1.
- **NFR-A2.** Strict module boundaries: `Codec` (pure Lua, no WoW API),
  `Matcher` (pure Lua, no WoW API), `Comm`, `Pool`, `Session`, `UI`,
  `Data`, `Locale`. Pure modules must run under standalone Lua 5.1 for
  testing.
- **NFR-A3.** All game data (boss table, brackets, timings, channel name,
  prefix) lives in `Data.lua` as declarative tables — zero literals in logic.
- **NFR-A4.** Main UI is hand-built frames (not AceGUI) for performance and
  design control; the options panel may use AceConfig.

## NFR-P — Performance

- **NFR-P1.** Event-driven only: **no `OnUpdate` polling** while idle;
  timers via AceTimer at ≥ 1 s granularity.
- **NFR-P2.** Broadcast budget: ≤ 1 channel message per heartbeat interval
  (30 s) per client, plus event-driven messages (register/cancel/propose)
  throttled through ChatThrottleLib (`BULK` for heartbeats, `NORMAL` for
  negotiation, `ALERT` for invite confirmations).
- **NFR-P3.** No table/closure allocation in hot paths (CHAT_MSG handlers):
  reuse scratch tables, precompile patterns, avoid string concat chains
  (use `table.concat`).
- **NFR-P4.** UI lists (pool browser) render through a fixed row pool with
  `FauxScrollFrame` virtualization; frame count is bounded regardless of
  pool size.
- **NFR-P5.** Steady-state memory < 2 MB, no measurable per-second garbage
  while idle (checked with `/hcbb debug mem` and Details memory profiler).
- **NFR-P6.** Pool is capped (default 200 listings); above the cap, oldest
  non-matching entries are evicted first.

## NFR-D — Data

- **NFR-D1.** SavedVariables (`HCBB_DB` via AceDB) store: user preferences,
  language override, last registration, bracket overrides. Schema carries a
  `dbVersion`; migrations run at load, never destructive without backup.
- **NFR-D2.** The matchmaking pool is in-memory only — never persisted
  (stale presence must not survive a reload).

## NFR-O — Observability

- **NFR-O1.** `/hcbb debug` toggles a diagnostics mode: comm log ring buffer
  (last 100 messages in/out), pool dump, channel health, timer states.
- **NFR-O2.** User-facing errors are actionable and localized; internal
  errors go through a single `HCBB:Error()` sink (no raw `error()` reaching
  the user in release builds).

## NFR-T — Testability

- **NFR-T1.** `Codec` and `Matcher` have busted test suites runnable on
  standalone Lua 5.1 in CI (GitHub Actions). Every bug fix adds a regression
  test.
- **NFR-T2.** `luacheck` passes with the project `.luacheckrc` (WoW 3.3.5
  globals whitelist) on every commit.
- **NFR-T3.** An in-game smoke-test checklist (`docs/project/smoke-test.md`)
  is executed before each release: channel join, two-client match, invite
  flow, locale switch.

## NFR-L — Localization

- **NFR-L1.** A small locale proxy in `Core.lua` (a metatable over per-locale
  tables) with `enUS` as the complete base; `frFR`, `deDE`, `esES`, `itIT`
  may be partial (silent English fallback). AceLocale was dropped so the
  manual language override (R21, no `itIT` client locale) and instant
  in-place switching stay simple.
- **NFR-L2.** No user-visible string outside locale files (enforced by code
  review; UI code contains only `L["key"]` lookups).
- **NFR-L3.** Locale files are UTF-8; the 3.3.5 client renders UTF-8 chat
  fonts correctly — accented characters must never be ASCII-substituted.
