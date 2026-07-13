# HCBB Dungeon Finder — project working agreement

WoW addon (WotLK 3.3.5a / WoW Ascension CoA) implementing a decentralized
group finder for the Hardcore Boss Blitz challenge. **Public GitHub repo.**

## Canonical docs — read before designing anything
- `docs/user-guide/business-rules.md` (R1…) — functional truth.
- `docs/user-guide/non-functional-requirements.md` (NFR-*) — technical truth.
- `docs/design/architecture.md` — module & protocol design.
- `docs/design/ascension-addon-environment.md` — platform ground truth.

## Stack & constraints
- Lua 5.1, WoW 3.3.5a API only (`## Interface: 30300`). No retail API.
- Ace3 embedded in `HCBBDungeonFinder/libs/` (pinned, see `libs/VERSIONS.md`).
- Addon folder `HCBBDungeonFinder/` at repo root; docs and tests never ship
  in release zips (packaging script excludes them).
- `Codec.lua` / `Matcher.lua` stay pure Lua (no WoW API) — testable in CI.

## Public-repo privacy (mandatory, before first commit)
- Git identity for this repo: `git config user.email
  "jejex-007@users.noreply.github.com"`; `user.name` = public handle.
- Author/credit in .toc, README, LICENSE: **KySeEtH** — never the real name.
- Grep for real name/email before every push.
- `.gitignore`: `.claude/`, `.vscode/`, `*.zip`, `libs/` upstream scratch.

## Language rules
- Everything checked in (code, comments, docs, commits): **English**.
- Chat with the maintainer: French.
- UI strings live only in `Locales/*.lua` (enUS complete; frFR, deDE, esES,
  itIT best-effort with English fallback).

## Definition of done
1. `luacheck` green (WoW globals whitelist in `.luacheckrc`).
2. busted tests green (Codec, Matcher) — bug fix ⇒ regression test.
3. In-game smoke test on Ascension for anything touching Comm/UI
   (checklist: `docs/project/smoke-test.md`).
4. Docs updated if rules changed (BR/NFR) + tracking trio
   (`docs/project/backlog.md`, `changelog.md`, `timesheet.md`).

## Release flow
- `main` always loadable in-game. Tag `vX.Y.Z` ⇒ GitHub release with a zip
  containing only `HCBBDungeonFinder/`.
- Protocol changes bump the wire version (`HCBB<n>`) and are called out in
  the changelog (older clients must degrade gracefully, NFR-C5).

## Ask before
- Creating/renaming the GitHub repo, pushing force, publishing a release.
- Any change to the wire protocol version or the Blitz data table defaults.
