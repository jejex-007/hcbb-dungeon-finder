# HCBB Dungeon Finder

A decentralized group finder for the **Hardcore Boss Blitz** community
challenge on [WoW Ascension](https://ascension.gg) (Conquest of Azeroth).
The native Dungeon Finder is prohibited during the challenge — this addon
fills the gap: register what you need, and it matches you with compatible
players and forms the group.

No server, no website: coordination happens entirely between addon users
through a hidden chat channel and invisible addon whispers.

## Features

- **Per-boss registration** following the official Blitz progression
  (25 bosses), with level-bracket gating and cleared-boss tracking.
- **Role-based matching** — Tank / Healer / Support / DPS (declare one or
  more): groups always form as 1 tank, 1 healer, at most 1 support, rest DPS.
- **Challenge-legal groups**: members within 3 levels of each other,
  5-player groups preferred (3+/4+ opt-in per player).
- **Consent-first flow**: every member confirms a found group in a 30 s
  popup showing the composition and *your assigned role*; the designated
  leader then sends the party invites. The addon never accepts invites or
  automates gameplay — you stay in control (it is hardcore, after all).
- **Localized**: English (default), Français, Deutsch, Español, Italiano.
- Lightweight: event-driven, virtualized lists, one 30 s heartbeat while
  searching.

## Install

1. Download the latest release zip.
2. Extract **both** folders — `HCBBDungeonFinder` and
   `HCBBDungeonFinder_Loader` — into
   `<WoW Ascension>\resources\client\Interface\AddOns\`.
3. `/hcbb` in-game (or the minimap button) opens the window.

The addon only activates on characters enrolled in the Boss Blitz challenge
(it detects the "Hardcore - Boss Blitz" mode debuff). On any other character
the loader keeps it dormant — it never even loads. Everyone who wants to be
matched must run the addon, so share it with your bracket buddies.

## Slash commands

| Command | Effect |
|---|---|
| `/hcbb` | Toggle the main window |
| `/hcbb demo` | Seed fake listings + a fake proposal (visual tour, solo) |
| `/hcbb pool` | Dump the current matchmaking pool |
| `/hcbb debug` | Toggle verbose comm logging |

## How matching works (short version)

Searching players broadcast a tiny presence message on a hidden custom chat
channel (`HCBBLFG`) every 30 s. Every client mirrors that pool locally and
runs the same deterministic matcher; the player who would lead the group
(tank > healer > support > DPS among leader volunteers, else the tank)
proposes it to the others over addon whispers. Everyone accepts → the leader
invites. Anyone declines or times out → everyone else returns to searching
automatically. Full protocol and design docs live in
[docs/design/architecture.md](docs/design/architecture.md).

## Development

- WotLK 3.3.5a API (Interface 30300), Lua 5.1, Ace3 (embedded).
- `Codec.lua` and `Matcher.lua` are pure Lua with a busted test suite:
  `lua tests/run.lua` (any Lua ≥ 5.1, no dependencies) or `busted tests`.
- Lint: `luacheck .` — CI runs both on every push.
- Canonical specs: [business rules](docs/user-guide/business-rules.md) ·
  [non-functional requirements](docs/user-guide/non-functional-requirements.md).

## Credits

Made by **KySeEtH**. MIT licensed — see [LICENSE](LICENSE).
Boss Blitz is an official
[Ascension community challenge](https://ascension.gg/en/news/hardcore-community-challenge-boss-blitz/531).
