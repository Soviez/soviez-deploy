# Stage Source Archive Model

For each migrated Stage:

- source/destination Stage IDs, parent License
- traffic-owner / route states
- retention deadline (unchanged — **no reset / no lifetime extension**)
- source Stage archive state + backup
- destination Stage health
- optional vs mandatory classification
- `purge_authorization=false`

## Requirements

- No entitlement duplication
- No source Stage deletion / automatic Stage purge
- Expired Stage archive policy explicit (OD-47)
- Source Stage runtime may stop only after destination validation
- Exact Stage targeting; no cross-Stage cleanup

## Pass criteria (recommended)

- Optional Stage archive failure → **WARNING**
- Mandatory Stage archive failure → **BLOCKED**
