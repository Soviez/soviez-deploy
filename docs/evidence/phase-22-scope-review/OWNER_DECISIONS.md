# Owner Decisions Required (Phase 22 Scope)

All items **OPEN** unless noted. Recommendations are non-binding until owner approval.

| ID | Decision | Recommendation |
|----|----------|----------------|
| OD-01 | Exact Phase 22 title | Rollback Window Closure, Source Archive, License Finalization, and Safe Retirement Readiness |
| OD-02 | Archive only vs archive + host suspension | Archive + ERP runtime suspension (host preserved) |
| OD-03 | Purge excluded from Phase 22? | **Yes — exclude** |
| OD-04 | Which later phase owns purge? | **OPEN** — master-plan Phase 23 is Offline bundles; do **not** silently assign purge there; dedicate later decommission phase or explicit replan |
| OD-05 | Immediate rollback-window duration | Keep Phase 21 default **30 minutes** |
| OD-06 | Stabilization-period duration | **24 hours** |
| OD-07 | Owner confirmation to close rollback? | **Required** |
| OD-08 | Automatic closure? | Eligibility automatic; commit **not** automatic |
| OD-09 | Destination sustained-health period | Equal to stabilization (24h) |
| OD-10 | Destination backup freshness | Within policy window at closure and at archive commit |
| OD-11 | Source backup freshness | Pinned rollback backup valid through archive verify |
| OD-12 | Source archive restore-tested? | DB restore test **mandatory** |
| OD-13 | Full ERP restore test mandatory? | Strongly recommended; skip → WARNING/BLOCKED per policy |
| OD-14 | Minimum archive-copy count | **2** (archive + independent backup) where practical |
| OD-15 | Independent storage target | At least one non-local or offline copy where practical |
| OD-16 | Encryption requirements | Mandatory at rest for archive packages |
| OD-17 | Archive retention duration | OPEN (legal/commercial); no auto-delete in Phase 22 |
| OD-18 | Source rollback-backup retention | Through archive verification + hold policy |
| OD-19 | Destination backup retention | Retain; no delete in Phase 22 |
| OD-20 | Legal-hold handling | Blocks closure/archive destructive-adjacent steps; blocks future purge |
| OD-21 | Owner-hold handling | Same as legal hold for product gates |
| OD-22 | Source runtime after archive | Suspended (Option B) |
| OD-23 | Whether ERP stops | **Yes**, after archive verified |
| OD-24 | Whether PostgreSQL stops | Optional after verify; default allow stop |
| OD-25 | Whether whole host stops | Optional (Option C); not required for PASS |
| OD-26 | Provider suspension allowed? | Yes, optional, exact-target |
| OD-27 | Provider termination excluded? | **Yes — excluded from Phase 22** |
| OD-28 | Source License final state name | `migrated_source_archived` |
| OD-29 | LG capabilities after archive | Diagnostics + isolated restore; deny Production login |
| OD-30 | Internal diagnostics available? | Yes |
| OD-31 | Archived source restore for testing? | Isolated only; never second Production |
| OD-32 | Avoid second Production on restore | Slot/token invariants + LG archived mode |
| OD-33 | Source cert retention duration | Through archive verify + OPEN retention |
| OD-34 | Source cert renews? | No Production auto-renew; OPEN |
| OD-35 | Cert revocation deferred? | **Yes** |
| OD-36 | DNS rollback snapshot retention | Retain; mark manual_recovery_only |
| OD-37 | Source FQDN remains resolvable? | OPEN; public route disabled regardless |
| OD-38 | Source Nginx after archive | Public site disabled / archive maintenance |
| OD-39 | Credential rotation policy | Disposition inventory; rotate where dest owns |
| OD-40 | Credential revocation policy | Per-credential; no silent mass revoke |
| OD-41 | Payment credential disposition | Disable source; dest active; mark disposition |
| OD-42 | Webhook secret disposition | Disable source callbacks; mark |
| OD-43 | SMTP credential disposition | Disable source send; mark |
| OD-44 | DNS-provider credential disposition | Quarantine; retain for manual recovery |
| OD-45 | Backup credential disposition | Retain for archive/backup access |
| OD-46 | Stage archive policy | Exact Stage; no retention reset |
| OD-47 | Expired Stage archive policy | Explicit archive of expired Stage without lifetime extension |
| OD-48 | Optional Stage failure → PASS? | WARNING |
| OD-49 | Mandatory Stage archive failure | BLOCKED |
| OD-50 | Exact Phase 22 progress weight | Propose **1** (accounting); do **not** apply until implementation PASS |

## Destructive / legal / retention / credential policy

Must not be silently decided. OD-03/04/17/20/39–45 remain owner-gated.
