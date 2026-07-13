# Embedded libraries — provenance & pinning

All libraries were copied verbatim from addons proven to run on WoW
Ascension (client 3.3.5a), taken from a live install on 2026-07-13.
Do not edit them; replace wholesale when upgrading and update this table.

| Library | Copied from (proven addon) |
|---|---|
| LibStub | LootCollector/libs/LibStub |
| CallbackHandler-1.0 | AdiBags/libs/CallbackHandler-1.0 |
| AceAddon-3.0 | LootCollector/libs/Ace3 |
| AceEvent-3.0 | LootCollector/libs/Ace3 |
| AceDB-3.0 | LootCollector/libs/Ace3 |
| AceComm-3.0 (+ ChatThrottleLib) | LootCollector/libs/Ace3 |
| AceConsole-3.0 | LootCollector/libs/Ace3 |
| AceTimer-3.0 | AdiBags/libs/AceTimer-3.0 |

AceLocale was considered and dropped: the manual language override (R21)
and instant in-place switching are simpler with the addon's own 20-line
locale proxy (see Core.lua).
