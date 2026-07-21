# Design: presence-freshness-thresholds

## Context

`Playing.freshColor` computes its bands from `PRESENCE_PING` (`< ping` green,
`< 2×ping` yellow); `Browser.freshColor` already reads dedicated constants
(`FRESH_GREEN` / `FRESH_YELLOW`). Both live in `Data.CONST` (NFR-A3: all
tunables are declarative data).

## Goals / Non-Goals

**Goals:**
- Presence display bands become dedicated data, decoupled from the emission
  interval. Same shape as the browser's pattern.
- Zero behaviour change: new constants carry today's effective values.

**Non-Goals:**
- No retune of any value (ping stays 120 s — settled 2026-07-17, the 60 s
  option buys nothing during the 0.2.0 cohabitation window).
- No merge of browser and presence constants: the two lists ride different
  emission rhythms and must keep separate values.
- No UI change beyond the constant read.

## Decisions

### Decision 1: Two new CONST entries, prefixed PRESENCE_

`PRESENCE_FRESH_GREEN = 120`, `PRESENCE_FRESH_YELLOW = 240`, placed in the
existing PRESENCE block of `Data.CONST` with a comment stating the invariant
(`FRESH_GREEN >= PING`) and pointing at the spec. Prefix mirrors the existing
`PRESENCE_*` family so the block reads as one unit.

### Decision 2: No shared helper between the two freshColor functions

Browser and Playing keep their own three-line `freshColor`. Factoring a
common helper would need colour-threshold parameters and save nothing —
three similar lines beat a premature abstraction.

## Testing

Not unit-testable (UI + WoW API, outside the pure Codec/Matcher CI scope) —
covered by a smoke-test note; `/hcbb demo` already seeds stale presence
entries only in the pool, so the visual check rides the normal demo pass.
