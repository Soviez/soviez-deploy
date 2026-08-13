# Migration Discovery and Bootstrap Model

Phase 17 delivers non-destructive Soviez-to-Soviez migration **preparation**:

1. Exact source Production discovery  
2. Destination host bootstrap with signed installer + temporary identity  
3. Trust pairing (Device Auth + app-signed objects + mTLS credentials)  
4. Signed readiness assessment (PASS / WARNING / BLOCKED)

**Never in Phase 17:** payload transfer, DNS/maintenance, Migration Token reserve/consume, destination Production activation, source deactivation.

**Status:** PASS (2026-08-01 final certification closure). Progress **89%** (84+5). Installer `0.17.0-phase17`. Evidence: `docs/evidence/phase-17-final-certification-closure/`.

## Modules

`src/migration/{common,discovery,bootstrap,pairing,readiness,commands}/`

`src/ops/migration.sh` remains the Phase 14 operation-state schema remapper only.

## Defaults

| Setting | Value |
|---------|-------|
| Pair / bootstrap / discovery / readiness TTL | 24h |
| Clock skew max | 5 minutes |
| Capacity margin | 25% |
| Backup age warning | >24h verified → WARNING |
| Architectures | amd64 only |
| OS | Ubuntu 22.04 / 24.04 LTS |

## Outcome banner

```text
SOURCE DISCOVERY — COMPLETE
DESTINATION BOOTSTRAP — COMPLETE
MIGRATION PAIR — TRUSTED
READINESS — PASS / WARNING / BLOCKED
NO DATA TRANSFER STARTED
SOURCE REMAINS ACTIVE
MIGRATION TOKEN NOT CONSUMED
DESTINATION PRODUCTION NOT ACTIVATED
```
