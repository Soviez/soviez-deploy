# Phase 16 Overlap Review

## Reusable from Phase 16

| Capability | Use in Phase 22 |
|------------|-----------------|
| Verified / restore-tested backup states | Independent recovery copy alongside source archive |
| Pin protection | Keep Phase 19/21 rollback backups pinned through archive verification |
| Encryption + checksum manifests | Archive package crypto model |
| Retention matrix (7/4/12) | Inform archive retention policy; **do not auto-delete in Phase 22** |
| S3 / SFTP / local targets | Archive storage targets |
| Typed confirm for `--backup-delete` | UX pattern for closure / suspend (not for purge in Phase 22) |

## Must not conflate

- Backup **filestore archive** packaging ≠ **source retirement archive**
- Backup retention cleanup ≠ source purge
- Phase 16 restore-test of a backup ≠ Phase 22 archive restore-test (may reuse engine, different operation ID / target)

## Overlap rule

Phase 22 **reuses** Phase 16 primitives for package creation/verification; it **does not** treat every backup as a retirement archive and **does not** delete backups as part of PASS.
