# GIT_DIFF_SUMMARY

Working tree remains uncommitted (no commit/push authorized).

Material Phase 18 delta vs Phase 17 baseline:

- New `src/migration/{domain,dns,landing,tls,routing}/**`
- CLI parse + assemble wiring
- Phase 18 unit/security/integration tests
- `VERSION=0.18.0-phase18` + regenerated `dist/soviez.sh`
- Docs + evidence pack under `docs/evidence/phase-18-migration-domain-routing/`
- One test fix: reboot matrix JSON key `plan_id` (was `domain_plan_id`)
