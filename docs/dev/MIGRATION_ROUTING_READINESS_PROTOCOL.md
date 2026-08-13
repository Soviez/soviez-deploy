# Migration Routing Readiness Protocol

Commands:

- `sudo soviez.sh --migration-routing-readiness <pair-id>`
- `sudo soviez.sh --migration-routing-show <plan-id>`

## Result

| Result | Meaning |
|--------|---------|
| PASS | Pair valid; DNS challenge verified; landing healthy; mig TLS valid; source unchanged |
| WARNING | Soft issues (e.g. slow propagation recovered; IPv6 broken while IPv4 ok) |
| BLOCKED | Pair/challenge/landing/TLS failure or source drift |

## Validity

Signed routing plan TTL **24h**, or immediate invalidation on material drift (pair revoke, source DNS change, dest identity change, landing/TLS change).

## Hard denials

`soviez_migration_assert_no_transfer` / cutover guards — Phase 19+ only.
