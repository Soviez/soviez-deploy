# Compatibility Model — Phase 17

Readiness assessment produces **PASS / WARNING / BLOCKED**. Phase 17 **never** starts data transfer on WARNING or BLOCKED.

## Platform checks

| Check | Typical BLOCKED | Typical WARNING |
|-------|-----------------|-----------------|
| Supported OS (OD-09) | Unsupported distro/version | Near-EOL |
| Architecture (OD-10) | Unsupported arch change | Emulation |
| Docker / Compose | Missing/too old | Patch skew |
| PostgreSQL major | Incompatible major | Minor skew |
| Filesystem | Unsupported FS | Suboptimal |
| Free storage / inodes | Below required + margin (OD-12) | Tight margin |
| RAM / CPU | Below hard minimum | Below recommended |
| Network | No path source↔dest | High latency |

## Product checks

| Check | BLOCKED | WARNING |
|-------|---------|---------|
| ERP major | Incompatible | Upgrade recommended |
| Installer version | Unsigned / wrong digest | Older than source pin policy (OD-17) |
| Source/target image availability | Missing | Pull deferred |
| Addon / custom deps | Incompatible | Needs manual review |
| External mounts | Required missing | Remap needed |
| Domain/SSL model | N/A mutate | Dest not ready for Phase 18 |
| License Guard compatibility | Model mismatch | — |
| Backup readiness | Capability broken | Backup aged (OD-01/02) |
| Stage inventory | — | Unselected Stages pending owner |

## Migration-specific

| Check | BLOCKED |
|-------|---------|
| Exact source/destination identity | Mismatch |
| Conflicting active operation | Conflict |
| Connectivity | Failed synthetic test |
| Unsupported hardware change | Arch/OS |
| Staging capacity | Insufficient |

## Codes

`MIGRATION_COMPATIBILITY_WARNING`, `MIGRATION_COMPATIBILITY_BLOCKED`, `MIGRATION_DESTINATION_CAPACITY_INSUFFICIENT`, `MIGRATION_CONNECTIVITY_FAILED`, `MIGRATION_BACKUP_PREREQUISITE_MISSING`, `MIGRATION_ACTIVE_OPERATION_CONFLICT`.

## Policy note

Exact WARNING vs BLOCKED thresholds for capacity, backup age, and latency are **owner decisions** (OD-20) — this review does not silently decide commercial/destructive thresholds.
