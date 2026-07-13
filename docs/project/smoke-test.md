# In-game smoke test — release checklist

Run before tagging a release, on WoW Ascension (Bronzebeard / CoA). Anything
touching Comm or UI needs this (busted + luacheck don't exercise the WoW API).
Two accounts (A, B) both enrolled in the Boss Blitz challenge are ideal;
some steps are solo.

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
- [ ] Window opens above WeakAuras; close button clickable; Esc closes.
- [ ] Boss picker: ineligible bosses disabled with tooltip; cleared bosses
  show a green check (not a "?"); default is first eligible uncleared.
- [ ] `/hcbb demo` seeds listings in Who's Looking with class-colored names;
  the proposal popup shows, countdown text readable over the bar, Accept
  locks both buttons, footer swaps to "group forming".
- [ ] Enter combat → window auto-closes; reopen with `/hcbb`, search intact.

## Matchmaking (two clients A + B, same bracket)
- [ ] Both search the same boss; each sees the other in Who's Looking within
  a heartbeat (~30 s), freshness dot green.
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
