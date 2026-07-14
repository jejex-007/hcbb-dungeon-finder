# HCBB Dungeon Finder — Architecture

Targets: WotLK 3.3.5a API (see `ascension-addon-environment.md`), rules in
`../user-guide/business-rules.md` (R*), constraints in
`../user-guide/non-functional-requirements.md` (NFR-*).

## 1. Big picture

Fully decentralized: every client maintains a local replica of the "who is
searching" pool from broadcasts, and any client whose player would be the
**leader** of a feasible match acts as the coordinator for that match. No
server, no elected super-node, no shared mutable state — coordination is
done with reservations + acknowledgements over whispers.

```
┌────────────────────────── client ──────────────────────────┐
│  UI (frames, popups)                                        │
│   │        ▲                                                │
│   ▼        │ callbacks (AceEvent messages)                  │
│  Session (proposal state machine)  ◄──── Matcher (pure)     │
│   │        ▲                                  ▲             │
│   ▼        │                                  │ pool snapshot
│  Comm (transport)  ────────────────────►  Pool (replica)    │
│   │  ▲                                                      │
└───┼──┼──────────────────────────────────────────────────────┘
    ▼  │
 hidden chat channel  "HCBBDungeonFinder"  (broadcast: presence)
 addon whispers       prefix "HCBB" (unicast: negotiation)
```

## 2. Addon layout

The distribution is two folders (R23): a permanent featherweight loader and
the LoadOnDemand main addon it pulls in only on enrolled characters.

```
HCBBDungeonFinder_Loader/       # always loaded, ~1 KB
├── HCBBDungeonFinder_Loader.toc
└── Loader.lua                  # scans for the Boss Blitz debuff (spellId
                                # 93131), LoadAddOn("HCBBDungeonFinder") if found

HCBBDungeonFinder/              # ## LoadOnDemand: 1 — never loads without the marker
├── HCBBDungeonFinder.toc          ## Interface: 30300, SavedVariables: HCBB_DB
├── libs/                          # embedded, pinned (NFR-A1) + VERSIONS.md
│   ├── LibStub, CallbackHandler-1.0
│   └── Ace3: AceAddon, AceEvent, AceTimer, AceComm(+ChatThrottleLib),
│              AceConsole, AceDB
├── Locales/enUS.lua frFR.lua deDE.lua esES.lua itIT.lua   # R20–R22
│   # hand-rolled locale proxy in Core.lua (manual override + hot switch)
├── Core.lua                       # AceAddon bootstrap, slash cmds, wiring
├── Data.lua                       # boss/bracket table §7 BR, timings, names
├── Codec.lua                      # pure Lua: encode/decode wire messages
├── Pool.lua                       # presence replica, TTL, caps, dedupe
├── Matcher.lua                    # pure Lua: deterministic matching
├── Session.lua                    # proposal/negotiation state machine
├── Comm.lua                       # channel join/hide, transport, routing
└── UI/
    ├── MainFrame.lua      # shell, tabs, status strip, shared widget factory
    ├── Registration.lua  Browser.lua  ProposalPopup.lua
    └── Options.lua  Minimap.lua
```

`Codec` and `Matcher` import nothing from the WoW API (NFR-A2/T1) — they are
unit-tested with busted on stock Lua 5.1 in CI.

## 3. Transport (Comm)

Two paths, mirroring the proven LootCollector pattern:

| Path | Mechanism | Used for |
|---|---|---|
| **Broadcast** | Hidden custom chat channel `HCBBDungeonFinder`: `JoinPermanentChannel` at login (+ rejoin timer), `ChatFrame_RemoveChannel` on all frames, send via `SendChatMessage(payload, "CHANNEL", nil, id)`, receive via `CHAT_MSG_CHANNEL` filtered on channel name | HELLO / BYE presence (small, loss-tolerant), heartbeat 30 s / expiry 120 s |
| **Unicast** | AceComm `SendCommMessage(prefix="HCBB", …, "WHISPER", target)` — invisible to chat, throttled, chunked | PROPOSE / ACK / NACK / CONFIRM / ABORT (reliable-ish, targeted) |
| **Group** | AceComm `SendCommMessage(prefix="HCBB", …, "PARTY"/"RAID")` | SUGGEST (suggest-invite fallback, R24) |

Rules: broadcast payloads ≤ 240 printable-ASCII bytes, one heartbeat per
30 s max (NFR-P2); ChatThrottleLib priorities BULK (heartbeat), NORMAL
(negotiation), ALERT (CONFIRM). Sender identity always from the event's
`sender` arg, never the payload (NFR-S2).

## 4. Wire protocol v1

Compact positional, `:`-separated. Values may not contain the separators
(`:` `;` `,` `|`) — enforced by strict per-field charset validation on
decode, not by escaping. Header `HCBB<proto>`, proto a single digit;
unknown major → drop (NFR-C5).

```
HELLO  HCBB1:H:<seq>:<bossId>:<level>:<roles>:<minSize>:<lead>:<ver>[:<class>]
BYE    HCBB1:B:<seq>
PROPOSE  (whisper)      HCBB1:P:<matchId>:<bossId>:<size>:<yourRole>:<name,role,lvl;…>
ACK    (whisper)        HCBB1:A:<matchId>
NACK   (whisper)        HCBB1:N:<matchId>:<reason>   -- busy|changed|declined
CONFIRM(whisper)        HCBB1:C:<matchId>            -- invites incoming
ABORT  (whisper)        HCBB1:X:<matchId>:<reason>   -- refill|timeout|cancel|…
SUGGEST(party/raid)     HCBB1:S:<target>:<bossId>    -- suggest-invite (R24)
```

- `bossId`: index in the Data table (locale-independent, R22).
- `roles`: bitmask T=1 H=2 S=4 D=8. `lead`: 0/1. `ver`: addon release version
  (semver). A received HELLO whose `ver` is a strictly newer release than ours
  (`Codec.isNewer`, numeric per component) triggers a single "update available"
  notice per session (NFR-C5), surfaced as a chat line **and** an accent banner
  in the window's status strip — distinct from the unknown-proto-major drop
  above: same proto still interoperates fully, the notice is just a nudge.
- `class`: optional trailing 2-letter CoA class abbreviation (e.g. `sa` =
  Bloodmage). Backward-compatible extension of HELLO — the decoder accepts 9
  or 10 fields, so no wire-version bump (older/newer clients interoperate;
  a client that omits it simply shows no class). Abbrev↔token↔color tables
  in `Data.lua`, mirroring the LootCollector ecosystem.
- `matchId`: `<leaderName>-<seq>` — unique enough, attributable.
- HELLO doubles as heartbeat and as update (fields replace the previous
  listing for that sender). BYE removes it. Heartbeat 30 s, expiry 120 s
  (R17).

## 5. Pool

`Pool[senderName] = {bossId, level, roles, minSize, lead, lastSeen, reservedBy}`.
Eviction: TTL expiry (R17), cap 200 with oldest-first eviction (NFR-P6),
per-sender rate limiting and dedupe by `seq` (NFR-S4). Emits local events
(`HCBB_POOL_CHANGED`) consumed by Matcher scheduling and the Browser tab.

## 6. Matcher (pure, deterministic)

Runs locally on every pool change, debounced (2 s), only while the local
player is searching.

1. Candidate set: same `bossId`, in-bracket (R2), pairwise level span ≤ 3
   (R9), not reserved (R16).
2. Enumerate compositions largest-first: 5 → 4 → 3 (R8); sizes below 5
   are only eligible once the local listing is older than the grace period
   (R14, 90 s). Every member's `minSize` ≤ size (R4).
3. Composition fill order: Tank, Healer, optional Support, DPS (R7). Role
   assignment: rarest-role-first among each candidate's declared roles
   (R15). Tie-breaks are **total-ordered and stable** (listing age, then
   name) so every client computes the same match from the same pool.
4. Leader election per R11 (tank-lead > heal-lead > support-lead > random†
   DPS-lead > tank). †"random" is made deterministic by hashing the sorted
   member names, so all clients pick the same DPS leader.
5. **Only the elected leader's client acts** on the computed match. Others
   do nothing — they will receive a PROPOSE. This removes the need for
   global consensus: pools may diverge transiently; a stale PROPOSE just
   gets NACKed.

## 7. Session state machine (per client)

```
IDLE ──register──► SEARCHING ──HELLO/heartbeat──┐
  ▲                    │◄───────────────────────┘
  │                    ├─ matcher says I'm leader ─► COLLECTING (sent PROPOSE, await ACKs, 30 s)
  │                    └─ PROPOSE received ────────► PROPOSED  (popup, player accepts/declines)
  │   COLLECTING: all ACK ─► FORMING (send CONFIRM + InviteUnit each member)
  │   COLLECTING: NACK/timeout ─► release reservations, back to SEARCHING (refill retry)
  │   PROPOSED: accept ─► ACK sent, FORMING (leader invites; ≤20 s watchdog, else back to SEARCHING + warn)
  │   PROPOSED: decline/timeout(auto-decline at 0 s) ─► NACK sent, back to SEARCHING
  │   ANY ─ channel lost ─► PAUSED (listing frozen; auto-resume + rebroadcast on rejoin)
  └── group joined / cancel / logout ─► BYE broadcast ─► IDLE
```

Race handling (R16): a client reserves itself for the **first** PROPOSE it
receives (`reservedBy = matchId`) and NACKs `busy` any concurrent one;
reservations expire with the proposal timeout. Two leaders proposing
overlapping matches therefore cannot both succeed; the loser refills.
Invites are sent only after CONFIRM, and accepting the party invite remains
a manual player action (R19/NFR-S1).

## 8. UI

Hand-built frames (NFR-A4): one main window (3 tabs: Find Group, Who's
Looking, Options), proposal modal, status strip, minimap button. UI reads
state only through AceEvent messages from Session/Pool — no logic in UI
files. All strings via `L[...]` (NFR-L2). Design source of truth: the
mockup produced from `ux-design-prompt.md` (archived under
`docs/reference/sources/`).

Notable behaviours:
- Registration disables Search while not enrolled (R23) or while already
  grouped; the window auto-closes on entering combat (search continues in
  the background — hiding never cancels it).
- Browser (Who's Looking) is virtualized via `FauxScrollFrame` + a fixed row
  pool (NFR-P4); names are class-colored (class carried on HELLO). Right-
  click a listing to open the game's native player menu (Invite / Suggest
  Invite / Whisper), with a custom menu + SUGGEST message as fallback (R24).
  Hovering a row shows a class tooltip; the proposal popup reuses the same
  tooltip, resolving each member's class from the local pool (the P message
  doesn't carry it) or `UnitClass` for the player themself.
- Checkbox labels are clickable (a transparent hit area over the label
  forwards to the box, gated on the box being enabled) — a shared `UI.Check`
  behaviour, so it applies to the lead opt-in and the options toggles alike.
- The Ascension client honors `SetVertexColor` but not `SetGradientAlpha`,
  so panels/buttons use flat vertex-color tints; status marks (✓/✗) use
  ready-check textures since the game font lacks those glyphs.
- Per-game-mode role model (M6.2): the game mode is the source of truth. The
  two HCBB modes are separate realms whose names embed the mode (e.g.
  `Bronzebeard - Warcraft Reborn`), so `GetRealmName()` — matched against the
  `Data.WR_REALM_TAG` substring at init — sets `NS.gameMode` (`CoA`/`WR`,
  default CoA). Roles are declared per mode in `Data.MODE_ROLES`, so Warcraft
  Reborn just has no Support entry; Registration builds cards from that set and
  they re-space to fill the same width (the fill formula reproduces the 4-card
  spacing exactly). Nothing downstream changes: the matcher already treats
  Support as optional (≤1), so a Support-less pool forms T/H/D groups, and no
  Support bit is ever broadcast.

## 9. Key decisions & alternatives considered

- **Custom hidden channel vs GUILD/YELL addon messages**: participants are
  spread across guilds and zones; a channel is the only global bus on
  3.3.5 (SendAddonMessage has no CHANNEL type). Proven by LootCollector.
- **Leader-acts coordination vs global deterministic consensus**: pools are
  eventually consistent, so pure "everyone computes, leader acts" can
  mis-fire on stale data — but the ACK round trip catches every divergence
  cheaply. Simpler and more robust than gossip-consensus for a v1.
- **Compact positional codec vs AceSerializer+Base64 on the channel**:
  AceSerializer output is verbose (~3× payload); positional fields keep
  HELLO ≪ 240 bytes and are trivially validatable field-by-field.
- **Per-boss registration vs per-dungeon**: the Blitz progression is a boss
  list (some dungeons hold several targets with different unlock levels);
  per-boss keeps brackets exact and the protocol single-purpose (R1).
