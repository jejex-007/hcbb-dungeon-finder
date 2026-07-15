# HCBB Dungeon Finder — Business Rules

Canonical functional rules. If the code contradicts this file, the code is
wrong. Rule IDs (R1, R2…) are stable — never renumber, only append.

Game mode reference: [Hardcore Boss Blitz ruleset](https://ascension.gg/en/news/hardcore-community-challenge-boss-blitz/531).
HCBB runs in two WoW Ascension game modes, each on its own realm(s):
**Conquest of Azeroth** (21 custom classes, includes the Support role) and
**Warcraft Reborn** (9 base WoW Classic classes, no Support role). One addon
build adapts to the active mode — see R3, R7 and NFR-C6.

## 1. Purpose

The addon is a decentralized group finder for the Hardcore Boss Blitz (HCBB)
challenge, where the native Dungeon Finder is prohibited. Players running the
addon advertise what they need; the addon matches compatible players and
automates group formation. There is no server component: all coordination
happens between addon clients over chat-based messaging.

## 2. Player registration (the "listing")

- **R1 — Target selection.** The player selects the **next Blitz boss they
  need** from the ordered progression table (§7). The UI groups bosses by
  dungeon/wing. One active target per character at a time.
- **R2 — Level bracket.** Each target has a default eligible level bracket
  (§7). A player whose level is outside the bracket cannot register for that
  target (e.g. a level 16 cannot register for Deadmines / VanCleef).
  Brackets are data-driven defaults, adjustable only in the addon's saved
  configuration (not in the UI), so the community can retune per season.
- **R3 — Roles.** The player declares one or more roles they can fill:
  **Tank, Healer, Support, DPS**. At least one role is required. Roles are
  declared, never inferred (CoA classes don't map to roles). **Support exists
  only in Conquest of Azeroth**; in Warcraft Reborn the choices are Tank,
  Healer, DPS (the role set is data-driven per mode — see NFR-C6).
- **R4 — Minimum group size.** The player picks the smallest group size they
  accept: **3+, 4+ or 5 only**. A match at size N requires every member's
  minimum ≤ N.
- **R5 — Leader opt-in.** The player declares whether they are willing to be
  group leader (boolean).
- **R6 — Search lifecycle.** Registration becomes visible to other players
  only when the player presses "Search". The player can cancel anytime.
  A listing expires automatically if the player logs out, stops
  heartbeating (§6), joins a group, or successfully forms a match.

## 3. Group composition

- **R7 — Mandatory composition.** A formed group always contains exactly
  **1 Tank** and **1 Healer**, **at most 1 Support**, and **DPS for every
  remaining slot**. Valid sizes: 3 (T/H/D), 4 (T/H/D/D or T/H/S/D),
  5 (T/H/D/D/D or T/H/S/D/D). In Warcraft Reborn (no Support role, R3) the
  feasible shapes reduce to T/H/D, T/H/D/D and T/H/D/D/D — the matcher already
  treats Support as optional, so nothing else changes.
- **R8 — Size priority.** The matcher always prefers the largest feasible
  group: 5 if possible, then 4, then 3. A smaller match is only proposed when
  no larger one is feasible with the current pool (see R14 for the timing
  rule).
- **R9 — Level coherence.** All members must be (a) individually inside the
  target's bracket (R2) and (b) within **3 levels of each other** (challenge
  rule: max(level) − min(level) ≤ 3).
- **R10 — Same target.** All members must be registered for the same target
  boss.

## 4. Leader election

- **R11 — Leader priority.** The leader of a match is, in order:
  1. the Tank, if they opted in as leader (R5);
  2. else the Healer, if opted in;
  3. else the Support, if present and opted in;
  4. else a random DPS among those opted in;
  5. else **the Tank** (default when nobody opted in).

## 5. Match & invitation flow

- **R12 — Proposal.** When a match is found, the elected leader's client
  sends a group proposal to every candidate. Each candidate sees a
  confirmation popup (target boss, composition, own assigned role, member
  levels) and accepts or declines within a timeout (default 30 s).
- **R13 — Formation.** When all candidates accept, the leader's client
  invites each member (standard party invite). Members who declined or timed
  out are released back to the pool; the matcher retries with replacements.
- **R14 — Size-priority timing.** A feasible 5-player match is proposed
  immediately. A 4-player (then 3-player) match is only proposed after no
  5-match was feasible for a grace period (default 90 s, configurable),
  giving larger groups a chance to assemble first.
- **R15 — Role assignment.** If a player declared several roles, the matcher
  assigns the one the composition needs; the assignment is shown in the
  proposal popup and is binding for that group.
- **R16 — One proposal at a time.** A player involved in a pending proposal
  is reserved and cannot appear in a concurrent proposal. Reservation is
  released on decline, timeout, or cancellation.

## 6. Presence & trust

- **R17 — Heartbeat.** Active listings are re-broadcast periodically
  (default every 30 s). A listing not refreshed for 120 s is dropped from
  every client's pool. Freshness display thresholds: green < 60 s,
  yellow < 120 s.
- **R18 — Validation.** Every incoming message is validated (protocol
  version, field types, bracket coherence, sender name matches the chat
  event's sender). Invalid messages are silently dropped.
- **R23 — Participants only.** The addon only activates on characters
  enrolled in the Hardcore Boss Blitz challenge, detected client-side by the
  permanent mode marker on the character — the debuff "Hardcore - Boss Blitz"
  (spellId 93131); marker list is data-driven, see `Data.CHALLENGE_AURAS`.
  - **Load-time gate.** A separate always-loaded loader addon
    (`HCBBDungeonFinder_Loader`) checks the marker and only then loads the
    main addon (which is `LoadOnDemand`). A character without the marker
    never loads the addon at all — no frames, no slash command.
  - **Runtime gate (safety net).** Once loaded, the main addon still guards
    channel join and search on the same marker, and if it disappears
    (death = challenge failed) it cancels any running search and parks
    itself — an addon cannot unload mid-session.
  - This gate is client-side courtesy only — the wire protocol still treats
    every peer as untrusted (NFR-S4).
- **R19 — No gameplay automation.** The addon never moves the character,
  casts spells, accepts invites, or performs any protected action on the
  player's behalf. Group invites are accepted by the player through the
  standard Blizzard popup. (Hardcore mode: the player must stay in control.)
- **R24 — Browser quick actions.** Clicking a listing in the "Who's Looking"
  browser opens a small menu, contextual to the clicker's group state:
  **Invite** when they can (solo, or party/raid leader), else **Suggest to
  group leader** (posts a suggestion to party/raid chat), plus **Whisper**.
  All actions are user-initiated on click; nothing is automated (R19). The
  player's own listing is not actionable.
- **R25 — Who's Playing.** A dedicated tab lists every enrolled player
  currently **online with the addon**, so the community can find each other
  outside of a group search. Each row shows **name, class, level and the
  character's professions with their rank**. Right-click opens the same native
  player menu as the browser (R24); nothing is automated (R19).
  - Presence is a **periodic ping**, independent of the search: a player shows
    up here simply by being online, not by looking for a group. Going offline
    is detected by expiry, never announced — a BYE means "stopped searching",
    not "logged off".
  - **Only the two primary professions** are shown. Ascension's custom
    Woodcutting/Woodworking are excluded even though they cost a slot and are
    abandonable exactly like a primary — as are Cooking, Fishing, First Aid and
    Riding. Identical in both game modes, so there is no per-mode profession
    set (contrast R3/R7 for roles).
  - Profession names are **localized for display**; the wire carries only a
    locale-independent abbreviation (R22).
  - **Opt-out**: a player may hide themselves from this tab (Options). They
    still see everyone else — the opt-out only stops their own broadcast. It
    takes effect **immediately on their own list**; peers, who already hold the
    last ping, drop them at expiry (a ping cannot be recalled). Re-enabling
    re-announces at once rather than waiting for the next interval.
  - Presence data never outlives the session and is never persisted (NFR-D2).

## 7. Blitz progression data (defaults, season 2026-06)

Bracket rule: `[unlock − 4, unlock − 1]`. The "Beyond" column is the level a
kill lets you pass, so the boss must be killed **before** reaching it — the
ceiling is `unlock − 1`, and the floor is `ceiling − 3`, keeping every group
inside the 3-level challenge span (R9). Example: Edwin VanCleef (beyond 21)
→ killable at 17–20. All values are data, not code.

| # | Target boss | Dungeon (wing) | Beyond | Bracket |
|---|---|---|---|---|
| 1 | Edwin VanCleef | The Deadmines | 21 | 17–20 |
| 2 | Mutanus the Devourer | Wailing Caverns | 22 | 18–21 |
| 3 | Archmage Arugal | Shadowfang Keep | 26 | 22–25 |
| 4 | Aku'mai | Blackfathom Deeps | 28 | 24–27 |
| 5 | Charlga Razorflank | Razorfen Kraul | 33 | 29–32 |
| 6 | Mekgineer Thermaplugg | Gnomeregan | 34 | 30–33 |
| 7 | Bloodmage Thalnos | SM: Graveyard | 34 | 30–33 |
| 8 | Arcanist Doan | SM: Library | 37 | 33–36 |
| 9 | Herod | SM: Armory | 40 | 36–39 |
| 10 | Amnennar the Coldbringer | Razorfen Downs | 41 | 37–40 |
| 11 | Archaedas | Uldaman | 47 | 43–46 |
| 12 | Lord Vyletongue | Maraudon: Purple | 47 | 43–46 |
| 13 | Chief Ukorz Sandscalp | Zul'Farrak | 48 | 44–47 |
| 14 | Razorlash | Maraudon: Orange | 48 | 44–47 |
| 15 | Celebras the Cursed | Maraudon: Inner | 49 | 45–48 |
| 16 | Princess Theradras | Maraudon: Inner | 51 | 47–50 |
| 17 | Shade of Eranikus | The Sunken Temple | 55 | 51–54 |
| 18 | Alzzin the Wildshaper | Dire Maul: East | 58 | 54–57 |
| 19 | Emperor Dagran Thaurissan | Blackrock Depths | 59 | 55–58 |
| 20 | King Gordok | Dire Maul: North | 60 | 56–59 |
| 21 | Prince Tortheldrin | Dire Maul: West | 60 | 56–59 |
| 22 | Overlord Wyrmthalak | Lower Blackrock Spire | 60 | 56–59 |
| 23 | Balnazzar | Stratholme: Live | 60 | 56–59 |
| 24 | Baron Rivendare | Stratholme: Undead | 60 | 56–59 |
| 25 | Darkmaster Gandling | Scholomance | 60 | 56–59 |

## 8. Localization

- **R20 — Languages.** The UI is fully localized in **English (default),
  French, German, Spanish, Italian**. Any missing key falls back to English.
- **R21 — Language selection.** Language auto-detects from the game client
  locale when possible, with a manual override in the options (mandatory for
  Italian, which has no 3.3.5 client locale).
- **R22 — Data names stay canonical.** Boss and dungeon names may be
  localized for display, but the wire protocol and saved data always use
  locale-independent identifiers.
