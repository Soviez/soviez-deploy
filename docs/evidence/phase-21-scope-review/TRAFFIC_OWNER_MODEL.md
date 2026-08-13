# TRAFFIC_OWNER_MODEL.md

## Definition

`traffic_owner` identifies which side is the **authoritative Production traffic-serving epoch** for anti-split-brain and License Guard policy.

| Value | Meaning |
|-------|---------|
| `source` | Customer Production traffic expected on source (Phase 20 default) |
| `destination` | Customer Production traffic expected on destination (Phase 21 commit) |

Related field: `licensed_future_owner=destination` (Phase 20) — commercial/license slot already moved; distinct from traffic.

## Epoch table

| Phase | traffic_owner | licensed_future_owner | Public ERP |
|-------|---------------|------------------------|------------|
| 19 staging | source | source | source |
| 20 post-commit | source | destination | source |
| 21 pre-commit | source | destination | source (dest internal) |
| 21 post-commit | **destination** | — | **destination** |
| 21 rollback | source | destination (unchanged) | source |

## Commit rules

**Flip to `destination` only when ALL true:**

1. Destination Production nginx route active.
2. Production TLS valid on destination.
3. Authoritative Production DNS points to destination (operator-confirmed).
4. Public health suite **PASS** on Production FQDN.
5. Source writes blocked (`cutover_maintenance` or equivalent).
6. No split-brain detectors firing.

## Persistence (recommended)

| Store | Field | Authority |
|-------|-------|-----------|
| Authorization ledger (SaaS/mock) | `traffic_owner` | Authoritative for audit |
| Local activation JSON | `traffic_owner` | Convergent apply |
| Source grace JSON | `traffic_owner` | Mirror |
| Phase 21 cutover report | `traffic_owner` | Signed outcome |

## Detection (fail closed)

Block cutover commit or flag BLOCKED if:

- Both sides serve Production ERP publicly.
- `traffic_owner=destination` but DNS still majority on source (propagation policy).
- `traffic_owner=source` but destination `public_route=true`.

## License Guard gap

ERP `local_license_guard` lacks first-class `traffic_owner`. Until LG ships:

- Installer binding JSON is operational truth.
- LG may WARN on destination during pre-cutover internal login.
- **OWNER DECISION REQUIRED** OD-38: block cutover on LG gap vs WARN-accept.

**Recommendation:** WARN-accept for internal validation only; **BLOCK** public commit if LG denies destination Production bind.

## Irreversibility note

`traffic_owner=destination` is the **true irreversible operational point** for customer traffic (see `COMMIT_BOUNDARY.md`). DNS alone insufficient if source still accepts writes.
