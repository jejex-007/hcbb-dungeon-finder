# Proposal: presence-freshness-thresholds

## Why

The Who's Playing freshness dots derive their thresholds from `PRESENCE_PING`
(an *emission* constant): green < ping, yellow < 2×ping. Display semantics are
therefore a side effect of the transmission interval — retuning the ping
(discussed and deferred during the M8 design pass, 2026-07-17) would silently
repaint the dots and permanently mark slower-pinging older clients as stale.
Who's Looking already separates the two concerns (`FRESH_GREEN` /
`FRESH_YELLOW` vs `HEARTBEAT`); Who's Playing should follow the same pattern.

These display thresholds are also **specified nowhere** — R17 covers the
searching-pool dots, but the presence dots exist only in code. This change
writes the rule down as its spec.

## What Changes

- Two dedicated display constants, `PRESENCE_FRESH_GREEN` (120 s) and
  `PRESENCE_FRESH_YELLOW` (240 s) — today's effective values, so **zero
  behaviour change**.
- `Playing.freshColor` reads them instead of computing from `PRESENCE_PING`.

Same *shape* as the browser's constants, deliberately **not** the same
values: each list judges freshness against its own emission rhythm (HELLO
every 30 s vs ping every 120 s — a 60 s green window would mark a perfectly
alive presence stale between two pings).

## Capabilities

### New Capabilities

- `presence-freshness`: how presence freshness is displayed (dot bands) and
  how it relates to, but stays independent from, the ping interval and expiry.

## Impact

- `HCBBDungeonFinder/Data.lua`: two new CONST entries next to the PRESENCE block
- `HCBBDungeonFinder/UI/Playing.lua`: `freshColor` reads the new constants
- No wire change, no locale change, no behaviour change
