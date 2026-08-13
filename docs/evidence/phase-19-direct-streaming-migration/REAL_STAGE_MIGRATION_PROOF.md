# REAL_STAGE_MIGRATION_PROOF.md

Path: real Stage DB + filestore + selection + mTLS + destination Stage staging restore.

Proven in certification E2E / Stage transfer:
- No Stage selected by default; explicit selection required
- Expired Stage denied
- Wrong-parent denied (unit/security coverage)
- Retention deadline unchanged / no auto-extension
- Source Stage unchanged; destination Stage internal/non-public
- Optional Stage failure → WARNING (rc=1)
- Mandatory Stage failure → BLOCKED (rc=2)
- Exact Stage cleanup; no cross-tenant payload
