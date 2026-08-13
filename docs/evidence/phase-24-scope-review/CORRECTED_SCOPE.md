# CORRECTED_SCOPE.md

## Corrected title
**Security Hardening — Signed-Update Enforcement, Secret Hygiene, Ticket-Replay Consolidation, Registry Lockdown, and Secret-Scan CI**

## Corrected objective
Implement and certify the master-plan Phase 24 security hardening bullets by closing remaining gaps on top of Phases 1–23, without forking certified engines, without purge, without live rollout, and without absorbing Phase 25 final certification.

## Inclusions / exclusions
See `SCOPE_INCLUSIONS.md` and `SCOPE_EXCLUSIONS.md`.

## Success definition (implementation phase — future)
- Phase 24 security suite PASS
- Secret-scan CI PASS
- No unsigned self-update path
- Documented key/secret hygiene implemented per OD
- Registry lockdown fail-closed proofs
- Consolidated ticket-replay certification PASS
- `tests/run_all.sh` PASS
- No service-role credentials in dist
- Progress credit only if owner-approved weight applied on PASS
