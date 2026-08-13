# Documentation synchronization plan

Compare runtime vs:
user docs, developer docs, CLI help, License/Stage/migration/backup/update/offline/security/sovereignty/deployment/release docs.

Detect: stale commands/options/versions; old policy; removed unsigned self-update; wrong entitlement/Stage retention; outdated migration; wrong progress; obsolete Odoo branding; missing warnings.

## States
| State | Meaning |
|-------|---------|
| DOC_SYNC_PASS | Spot-check + critical docs match runtime; no blockers |
| DOC_SYNC_WARNING | Non-blocking stale wording documented |
| DOC_SYNC_BLOCKED | Wrong security/sovereignty/CLI that would mislead operators |

Phase 25 implementation must drive to PASS or WARNING with inventory; BLOCKED fails certification.
