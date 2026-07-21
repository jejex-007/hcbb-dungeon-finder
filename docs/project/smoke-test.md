# In-game smoke test — release checklist

Run before tagging a release, on WoW Ascension (Bronzebeard / CoA). Anything
touching Comm or UI needs this (busted + luacheck don't exercise the WoW API).
Some steps are solo. The rest need a second player — **two real people, not
two clients side by side**: Ascension bans for multiboxing, and on a hardcore
realm that is not a risk anyone should take to test an addon. Wherever this
file says "two clients A + B", it means two humans, coordinated over
Discord/whisper.

## Validation log

The checklist below stays unticked on purpose — it is a template re-run at
every release. Record here what was actually observed, and when.

- **2026-07-16 — Presence (R25) confirmed in the wild.** Real beta players
  appeared in Who's Playing on Bronzebeard, so channel join, broadcast, receive
  and decode of the `W` type all work between distant clients — no second
  account needed to prove it. One player was watched through the full
  lifecycle: online, then logged off, went red, then dropped at the TTL, which
  also proves the sweep timer runs. Two corollaries: everyone visible in that
  tab is necessarily on 0.2.0 (0.1.x never pings, making the tab a rough
  adoption counter), and `Presence` demonstrably received its
  `HCBB_CHANNEL_UP` — so the AceEvent fix holds for at least one module.
- **Still unproven: matchmaking.** Nothing under the "Matchmaking" heading has
  been exercised with two real clients. That section alone gates the stable
  tag, and it is the only path that exercises `Session:OnPoolChanged` — the
  subscription that was dead before 0.2.0.

## Load & gate (R23)
- [ ] Both `HCBBDungeonFinder` and `HCBBDungeonFinder_Loader` present in the
  AddOns list; loader enabled.
- [ ] On a **non-enrolled** character: `/hcbb` does nothing, the main addon is
  not loaded (`/dump IsAddOnLoaded("HCBBDungeonFinder")` → false/nil).
- [ ] On an **enrolled** character (has the "Hardcore - Boss Blitz" debuff,
  spellId 93131): the addon loads, `/hcbb` opens the window, status dot green.
- [ ] `/hcbb auras` lists the debuff (sanity for the marker).

## UI (solo, `/hcbb demo`)
- [ ] Window renders correctly: gradient panels, gold title, role icons,
  red Search button, tabs aligned (try a longer locale via Options).
- [ ] **Regression (first user report, 2026-07-15)**: with **no role selected**,
  the red "Select at least one role" error shows and the grey roles hint is
  **gone** — they share one anchor, so any overlap is the bug. Tick a role: the
  error disappears and the hint comes back. Re-check in both game modes (the
  report came from Warcraft Reborn, but the anchor is mode-independent) and on
  a non-enrolled / already-grouped character (both paths hide the error).
- [ ] **Regression (2026-07-16)**: pick a dungeon in the "Who's Looking" filter
  → the **button label follows** the selection, not just the list. It read
  "All dungeons" forever until then, which looks exactly like a broken filter
  even though the list was filtering correctly.
- [ ] **Regression (2026-07-16)**: on a character at a **dead level** (28, 41,
  42 with the default table — no boss bracket covers them), the Search button
  is disabled **and** a red hint below it names the next level that opens. At
  **60** the same hint turns gold and reads as an achievement, not an error —
  the Blitz is over, not broken. The boss picker stays usable at those levels
  (shift-click still tracks cleared bosses).
- [ ] **Update banner (2026-07-17)**: `/run HCBB:SendMessage("HCBB_UPDATE_AVAILABLE")`
  with the window open → a pulsing accent bar appears under the title, the
  panes shift down without clipping, and the **status strip keeps showing live
  state** (the old strip hijack is gone). Clicking the banner opens the
  copyable-link popup with the direct zip URL pre-selected; the popup text
  says a full restart is required. Language switch relabels the banner.
- [ ] Window opens above WeakAuras; close button clickable; Esc closes.
- [ ] Boss picker: ineligible bosses disabled with tooltip; cleared bosses
  show a green check (not a "?"); default is first eligible uncleared.
- [ ] **R27 (2026-07-16)**: a boss whose *beyond* level you have already
  reached (any boss with `unlock <= your level`) shows ticked and **cannot be
  un-ticked** by shift-click; its tooltip reads "required to pass this level",
  not the toggle hint. A boss still within reach toggles normally. Check a
  mid-progress character so both cases are visible at once.
- [ ] `/hcbb demo` seeds listings in Who's Looking with class-colored names;
  the proposal popup shows, countdown text readable over the bar, Accept
  locks both buttons, footer swaps to "group forming".
- [ ] `/hcbb demo` also seeds two stale listings — **Gorven (yellow dot)** and
  **Halwyn (red dot)** — so the freshness bands are visible at a glance. They
  drift and expire within ~30 s (the demo is a snapshot; re-run to refresh).
  The counter itself ("N active (M total)") only shows during a live search,
  so validate that at the 2-client run, not in demo.
- [ ] **R28 (2026-07-17) — multi-select picker**: clicking an eligible boss in
  the list **toggles** it (gold tint + yellow text when selected) and the menu
  **stays open**; the picker button reads "Dungeon — Boss +N" past one
  selection and the bracket label empties. Deselecting everything disables
  Search. Selection survives `/reload` (saved prefs migrate from the old
  single-boss field). Every other `/hcbb demo` listing shows the "+N" form in
  Who's Looking, with one tooltip line per targeted boss; the dungeon filter
  matches a listing on ANY of its targets.
- [ ] Enter combat → window auto-closes; reopen with `/hcbb`, search intact.

## Who's Playing (R25)
> Freshness dots read dedicated `PRESENCE_FRESH_GREEN`/`PRESENCE_FRESH_YELLOW`
> constants (`presence-freshness` spec), no longer derived from
> `PRESENCE_PING`. Values are unchanged (120 s / 240 s), so every checkbox
> below should behave exactly as before.
- [ ] Tab lists **yourself** within ~1 min of login (your own ping loops back
  through the channel), with class colour, level, class and professions+rank.
- [ ] Professions match your skill sheet: **only the two primaries** — not
  Woodcutting / Woodworking (abandonable but excluded by the table), and not
  Cooking / Fishing / First Aid / Riding (excluded by `isAbandonable`).
- [ ] Switch language in Options → profession names follow (they are locale
  keys, not the enUS skill-line names).
- [ ] Right after login the tab says "Initializing", not "nobody online", and
  swaps to the real state once the first ping goes out.
- [ ] Hover → tooltip with the full profession list; right-click another
  player → native menu; right-click yourself → nothing.
- [ ] Options → uncheck "Show me in Who's Playing" → you vanish from your own
  list **at once**, and stop being broadcast; you still see everyone else.
  Re-check → you reappear immediately (not after the next 120 s ping). Peers
  only drop you at the 300 s TTL — a sent ping can't be recalled.
- [ ] Two clients: B appears in A's tab within ~2 min without either searching.
- [ ] B logs off → the dot goes yellow (~4 min), then red, then the line
  **disappears** at the 300 s TTL. A red line that never clears means the
  sweep timer is dead and the list will silently fill with ghosts.
- [ ] **Back-compat (critical)**: a **0.1.0** client must ignore `W` silently —
  no Lua error, and **no "update available" notice** (unknown *type* is not
  unknown *major*). Run one old client alongside a new one to confirm.
- [ ] **Back-compat R28 (critical)**: against a **0.2.0** client — (a) a 0.3.0
  player searching a **single** boss is visible to it and can match with it
  end-to-end (the wire is byte-identical); (b) a 0.3.0 player searching
  **several** bosses is silently absent from its Who's Looking — no Lua
  error, no phantom row; (c) a match mixing 0.2.0 members and a multi-target
  member elects a 0.3.0 leader (watch who sends the proposal).

## Matchmaking (two clients A + B, same bracket)
- [ ] Both search the same boss; each sees the other in Who's Looking within
  a heartbeat (~30 s), freshness dot green.
- [ ] **R26 (2026-07-16)**: only fresh (green) listings are matched. Hard to
  force on purpose — let one client go quiet (leave the channel / close it)
  without a clean BYE: within ~60 s its listing goes yellow in the browser and
  stops being matchable, and the Find-Group counter on the other client flips
  from "N searching" to "N active (M total)". A resumed heartbeat turns it
  green and matchable again.
- [ ] With a full valid composition, a proposal fires; leader election
  matches R11; all-accept → leader invites → party forms.
- [ ] Decline / timeout on one side → both auto-return to Searching, listing
  intact.
- [ ] Channel drop (leave/rejoin) → status shows Paused, then resumes.

## Browser actions (R24)
- [ ] Right-click a listing → native player menu (Invite / Suggest Invite /
  Whisper); own listing not actionable.
- [ ] As a non-leader in a group, Suggest Invite reaches the leader.

## Options / l10n
- [ ] Language switch applies instantly across the whole UI (EN/FR/DE/ES/IT).
- [ ] Minimap button toggle + sound toggle persist across `/reload`.

## Protocol hygiene
- [ ] A peer on an older/newer build still matches (HELLO class field is
  optional; no version break).
