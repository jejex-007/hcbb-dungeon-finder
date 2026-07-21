# presence-freshness

How the freshness of a Who's Playing presence entry is displayed, and how the
display bands relate to — but stay independent from — the emission interval
(`PRESENCE_PING`) and the eviction TTL (`PRESENCE_EXPIRY`).

Absorbs a rule that previously existed only in code: R17 (business-rules.md)
specifies the searching-pool dot bands, but the presence dots were never
written down anywhere.

## ADDED Requirements

### Requirement: Presence freshness display bands

Each Who's Playing row SHALL show a freshness dot derived from the entry's
age (seconds since the last ping was received), banded by two dedicated
display constants: `PRESENCE_FRESH_GREEN` (default 120 s) and
`PRESENCE_FRESH_YELLOW` (default 240 s).

#### Scenario: Alive presence shows green

- **WHEN** a presence entry's age is below `PRESENCE_FRESH_GREEN`
- **THEN** its dot renders green

#### Scenario: Quiet presence degrades through yellow to red

- **WHEN** a presence entry's age reaches `PRESENCE_FRESH_GREEN`
- **THEN** its dot renders yellow
- **AND** it renders red from `PRESENCE_FRESH_YELLOW` until eviction at
  `PRESENCE_EXPIRY` (300 s), so the red band is a real, observable window

### Requirement: Display bands are independent from the emission interval

The display thresholds SHALL be dedicated declarative data (NFR-A3), not
values computed from `PRESENCE_PING`. Retuning the ping interval SHALL NOT
change what the dots mean.

#### Scenario: Ping retune leaves the bands untouched

- **WHEN** `PRESENCE_PING` is changed (e.g. a future 120 s → 60 s retune)
- **THEN** the green/yellow/red band boundaries stay exactly
  `PRESENCE_FRESH_GREEN` / `PRESENCE_FRESH_YELLOW`
- **AND** a peer still pinging at the old interval keeps its current colours
  (older clients are never repainted stale by a local tuning change)

#### Scenario: Green covers a full ping interval

- **WHEN** the default values are retuned
- **THEN** `PRESENCE_FRESH_GREEN` stays greater than or equal to
  `PRESENCE_PING`, so a client pinging on schedule is never shown stale
