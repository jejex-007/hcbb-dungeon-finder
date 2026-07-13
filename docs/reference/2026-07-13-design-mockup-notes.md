# Design mockup — import notes

**Source:** [sources/2026-07-13-hcbb-dungeon-finder.dc.html](sources/2026-07-13-hcbb-dungeon-finder.dc.html)
(original, bit-for-bit as exported from a private Claude design project
"HCBB Dungeon Finder UI"; viewer runtime archived as
[sources/2026-07-13-support.js](sources/2026-07-13-support.js)).

Context: produced by Claude design from `docs/design/ux-design-prompt.md`,
shared on 2026-07-13 with instruction "Implement".

## Contents (screen ids in the mockup)

- 1a–1c Registration: idle, boss-picker open (disabled row + tooltip),
  searching.
- 1d–1g Proposal popup: pending / all accepted / declined / timed out.
- 1h Pool browser, 1i Options, 1j Status strip.
- 1k Component spec (widget, L-key, size, behavior — translates 1:1 to
  CreateFrame), 1l interaction flow, 1m rationale.

## Key spec points adopted into the docs

- Main window 480×420, 3 bottom tabs, Esc closes (UISpecialFrames);
  **closing never cancels the search**.
- Proposal popup 384×330, DIALOG strata, no close button; "you-banner"
  with the player's assigned role is the most prominent element; countdown
  StatusBar 30→0 s, red under 10 s, **auto-decline at 0**.
- State machine gains **FORMING (≤ 20 s invite watchdog)** and **PAUSED
  (channel lost: listing paused, auto-resume + rebroadcast)** states.
- Boss picker: 25 bosses fixed order, wing headers, ineligible = visible +
  disabled + tooltip, cleared = ✓, default = first eligible uncleared.
- Pool browser: freshness dots green < 60 s / yellow < 120 s / red,
  own row pinned gold, empty-state copy seeds the pool.
- Every visual is flat color + 2 px bevel + standard atlas glyphs — no
  custom textures needed.

## Deviations decided at import (design showed 20 s / 120 s)

- **Heartbeat 30 s, expiry 120 s** (design said 20 s): 20 s triples channel
  traffic for no matching benefit; 30 s keeps the yellow-dot semantics and
  the 120 s expiry intact. BR R17 / NFR-P2 updated accordingly. The options
  tab renders these values from `Data.lua`, so the UI stays truthful.
