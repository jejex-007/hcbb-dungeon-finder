# UX Design Prompt — HCBB Dungeon Finder

Self-contained prompt for a Claude design session. Paste everything below
the separator into a fresh conversation (claude.ai, artifacts enabled) and
iterate on the produced mockup. The output we want back is (1) an HTML
mockup artifact of every screen/state, (2) a component & interaction spec we
can translate 1:1 into WoW frame code.

---

You are designing the UI of **HCBB Dungeon Finder**, a World of Warcraft
addon for the WotLK 3.3.5a client (WoW Ascension, "Hardcore Boss Blitz"
mode). Produce an HTML/CSS mockup artifact that faithfully mimics the WotLK
look, plus a written component spec. The design must be translatable 1:1
into WoW `CreateFrame` code, so stick to the constraints below.

## Game context

Hardcore mode: characters have one life; the challenge is lost on any death.
Players must kill specific dungeon bosses, in order, to unlock further
levels. The native Dungeon Finder is disabled — this addon is how players
find groups. Users are often mid-leveling, slightly stressed (death = game
over), and want to find a group with minimal fiddling. Trust and clarity
beat density: the player must always understand *what will happen next*
(who invites, what role they were assigned, who the leader is).

## Hard technical constraints (WotLK UI toolkit)

- Single main window ~ 480×420 px, draggable, closable with Esc; standard
  WotLK dark parchment/slate styling, gold accents, `Friz Quadrata`-style
  serif for titles, plain sans for body. No custom images/textures beyond
  what solid colors, borders and the game's standard atlas can express.
- Widgets available: buttons, checkboxes, radio buttons, dropdowns,
  sliders, single-line edit boxes, scrollable lists (virtualized rows),
  tabs, tooltips, modal popup dialogs. No animations beyond simple
  fade/glow. No web fonts, no images.
- Everything must work at 1024×768 with default UI scale.
- All labels come from a localization table (EN default; FR/DE/ES/IT) —
  leave room for German strings (~+35% width vs English).
- Performance: lists must be virtualized (fixed number of row frames);
  avoid layouts that require per-frame relayout.

## Functional flows to design

### 1. Registration panel (main tab "Find Group")
- **Target boss picker**: 25 bosses in fixed progression order, grouped by
  dungeon wing (e.g. "SM: Library — Arcanist Doan"). Bosses outside the
  player's level bracket are visible but disabled with a tooltip
  ("Requires level 33–37 — you are 29"). Auto-suggest the first eligible
  boss for the player's level.
- **Roles**: multi-select among Tank / Healer / Support / DPS (icon +
  label). At least one required.
- **Minimum group size**: radio 3+ / 4+ / 5 only, with a one-line hint
  ("5-player groups are always preferred; smaller sizes widen your match").
- **Leader opt-in**: checkbox "I'm willing to lead the group".
- **Primary action**: big Search / Cancel Search toggle button with clear
  searching state (elapsed time, pool count for the selected boss:
  "7 players searching in your bracket").

### 2. Pool browser (tab "Who's looking")
Read-only virtualized list of current listings for context: player name,
level, roles (icons), target boss, min size, leader flag, freshness dot
(green < 60 s, yellow < 120 s, red about to expire). Filter dropdown by
dungeon. This tab reassures the player that the system is alive.

### 3. Match proposal (modal popup — the critical moment)
Shows: target boss + dungeon, the 3–5 members with name/level/assigned
role icons, crown on the designated leader, **the role YOU were assigned**
highlighted, and a 30-second countdown bar. Buttons: Accept / Decline.
Every member sees the same popup; the group forms only if all accept.
Design the three follow-up states: all accepted (leader is inviting you —
watch for the party invite), someone declined (back to search, slot being
refilled), timed out.

### 4. Status strip (persistent, bottom of main window)
One line that always tells the truth: Idle / Searching (mm:ss) / Proposal
pending / Group forming / In group. Plus channel health indicator
(connected to the matchmaking channel or reconnecting) with tooltip.

### 5. Options (small tab)
Language dropdown (English, Français, Deutsch, Español, Italiano — default
"Auto"), heartbeat/expiry visible as read-only info, minimap button toggle,
sound-on-proposal toggle.

## Deliverables

1. **HTML artifact**: one page showing every screen and state side by side
   (registration idle, searching, pool browser, proposal popup ×4 states,
   options), pixel styling close to WotLK (dark #1a1410 panels, #c8aa6e gold
   accents, beveled 2px borders, serif titles).
2. **Component spec**: per screen, a table of components (type, label key,
   size hint, behavior, disabled/tooltip rules) + the interaction flow as a
   short state diagram (Idle → Searching → Proposal → Forming → InGroup,
   with failure edges).
3. **Rationale notes**: 5 lines max on the key choices (what you optimized
   for stressed hardcore players).

Iterate with me: start with the registration panel and proposal popup —
they carry 90% of the UX value.
