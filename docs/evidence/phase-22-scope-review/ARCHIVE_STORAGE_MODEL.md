# Archive Storage Model

## Supported targets (assessed)

- Local encrypted storage
- S3-compatible storage
- SFTP
- Offline removable media
- Provider snapshot
- Multiple-copy strategy

Reuse Phase 16 backup primitives.

## Recommended minimum

```text
one verified archive
+
one independent retained backup
```

## Restore-test policy (recommended)

| Requirement | Level |
|-------------|-------|
| Source archive `VERIFIED` | **Mandatory** for PASS |
| Source database restore test | **Mandatory** |
| Filestore manifest validation | **Mandatory** |
| Full ERP startup restore test | **Strongly recommended** |
| If full ERP restore skipped | WARNING or BLOCKED per owner policy (OD-13) |

Checksum-only verification without data-level validation is **insufficient** for PASS.
