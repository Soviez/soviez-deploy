# PHASE24_PHASE25_BOUNDARY.md

| Concern | Phase 24 | Phase 25 |
|---------|----------|----------|
| Canonical title | Security hardening | Final certification |
| Primary work | Hardening gaps + security CI + security suite | E2E certification matrix; docs sync; release checklist; owner sign-off |
| New product engines | Forbidden | Forbidden |
| Progress credit | Proposed 0.5 (unapplied) | Proposed 0.5 (unapplied) |
| Live deploy / publish | Forbidden | Forbidden unless separately authorized after Phase 25 |
| Purge / host wipe | Forbidden | Forbidden unless separately authorized |
| Phase 11.5 visual acceptance | Out of scope | May be listed on release checklist; does not auto-credit progress |
| Offline bundles | Reuse Phase 23 (no redesign) | Regression in E2E matrix |
| Update/backup/migration | Reuse owners; harden only | Full matrix certification |
| Owner sign-off for release | Not Phase 24 | **Required** for Phase 25 acceptance |

## Handoff from Phase 24 → Phase 25

Phase 24 must leave:

- Signed-update enforcement fail-closed in production paths
- Secret-scan CI green
- Phase 24 security suite PASS
- Documented secret hygiene / key-hashing policy implemented as authorized
- Registry lockdown proofs
- Consolidated ticket-replay certification evidence
- No new unsigned self-update paths
- Installer candidate ready for Phase 25 matrix (version TBD by Phase 25 auth)

Phase 24 must **not** implement: release checklist execution, public artifact publish, owner release sign-off, E2E “everything green for launch” matrix as the phase goal.
