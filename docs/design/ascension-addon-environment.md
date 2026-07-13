# Ascension Addon Environment — Survey (2026-07-13)

Ground-truth survey of what addon development looks like on WoW Ascension
(Conquest of Azeroth realms), based on inspection of a live install
(`D:\Jeux\WoW Ascension\resources\client\Interface\AddOns\`) and public sources.

## Client & API baseline

- **Client:** WotLK 3.3.5a (build 12340), heavily customized by Ascension.
- **Interface version:** every installed addon declares `## Interface: 30300`.
  Our `.toc` must declare the same.
- **API surface:** the bundled `APIDocumentation` addon is a backport of
  Blizzard's API documentation for 3.3.5 — all standard WotLK systems
  (Channel, Chat, Party, Unit, LookingForGroup…). **No Ascension-specific
  `C_*` API was found** in the docs or in community addons. Assume vanilla
  3.3.5 API only.
- **Consequences of 3.3.5 API (vs retail):**
  - No `C_Timer` → use AceTimer-3.0 (or frame-based timers).
  - No `C_ChatInfo.RegisterAddonMessagePrefix` → prefixes are free-form.
  - `SendAddonMessage(prefix, msg, chatType, target)` supports
    `PARTY/RAID/GUILD/BATTLEGROUND/WHISPER` — **not `CHANNEL`**.
  - Chat messages (and addon messages) are limited to ~255 bytes.
  - `GetLocale()` can return `enUS/frFR/deDE/esES/esMX/ruRU/koKR/zhCN/zhTW` —
    **`itIT` does not exist on 3.3.5** (Italian client arrived in MoP).
    Italian support therefore requires a manual language override option.

## What demonstrably works (evidence from installed addons)

| Capability | Evidence |
|---|---|
| Ace3 full stack (AceAddon, AceEvent, AceTimer, AceDB, AceConfig, AceGUI, AceLocale) | AdiBags, VuhDo, Kui_Nameplates, AtlasLoot |
| **AceComm-3.0 + ChatThrottleLib** (addon messages, chunking, throttling) | AtlasLoot, **LootCollector** |
| Cross-player data sync between addon users | **LootCollector** (Modules/Comm.lua, Modules/DBSync.lua) |
| Custom hidden chat channel as global broadcast bus | LootCollector: `JoinPermanentChannel("BBLC25C")`, `ChatFrame_RemoveChannel` to hide it, `SendChatMessage(payload, "CHANNEL", nil, channelId)`, receive via `CHAT_MSG_CHANNEL` |
| Targeted addon whispers (invisible to recipient's chat) | LootCollector: `SendCommMessage(prefix, payload, "WHISPER", target)` |
| Printable-payload encoding for channel messages | LootCollector embeds LibBase64-1.0 |
| SavedVariables persistence, minimap/LDB buttons, WeakAuras-class UI complexity | Details, WeakAuras, TomTom run fine |

**Key pattern (LootCollector), which we will reuse:** global presence
broadcasts go over a hidden custom chat channel with a compact printable
payload; targeted negotiation goes over `SendAddonMessage` whispers via
AceComm (invisible, chunked, throttled). Fallback distribution
RAID > PARTY > GUILD when applicable.

## Boss Blitz context that shapes the addon

Official ruleset: [Hardcore Community Challenge: Boss Blitz](https://ascension.gg/en/news/hardcore-community-challenge-boss-blitz/531)
(archived summary in `docs/user-guide/business-rules.md`).

- Hardcore (one life for the challenge), level caps unlocked by killing
  specific dungeon bosses in order.
- **The native Dungeon Finder, mail, AH, guild bank and BG queues are
  prohibited for participants** → there is no in-game group-finding tool for
  this mode. That is precisely the gap this addon fills. We must NOT build on
  the 3.3.5 LFG system APIs — pure chat-channel matchmaking instead.
- Grouping restriction: members must be **within 3 levels of each other**,
  and only fellow challenge participants.
- Realm: Bronzebeard (CoA). CoA has 21 custom classes → roles cannot be
  inferred from class; players must declare their roles (tank/heal/support/DPS),
  which matches the product spec. "Support" is a first-class CoA role.

## Distribution & ecosystem

- Community addons are shared via GitHub (e.g. the
  [Ascension-Addons](https://github.com/Ascension-Addons) org) and installed
  by dropping folders into `Interface\AddOns\` — same as classic WoW.
  Manually installed community addons (LootCollector, MaloW*) run without
  any whitelisting problem on live realms.
- Wiki reference: [Project Ascension AddOns](https://project-ascension.fandom.com/wiki/Project_Ascension_AddOns).

## Risks / to verify in-game (M0 smoke test)

1. `SendAddonMessage` WHISPER between two accounts on Bronzebeard (should be
   fine — LootCollector relies on it).
2. Custom channel join limit / naming collisions; verify channel survives
   zoning and login (LootCollector re-joins on a timer after login).
3. Throughput: channel chat is server-rate-limited; heartbeats must stay slow
   (≥ 30 s) and payloads ≤ 255 bytes.
4. Whether Ascension fires standard `PARTY_INVITE_REQUEST` popups for
   `InviteUnit()` — expected yes.
