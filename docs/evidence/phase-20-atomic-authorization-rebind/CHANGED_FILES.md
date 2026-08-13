# CHANGED_FILES — Phase 20

## soviez-sh (primary)
- VERSION → 0.20.0-phase20
- dist/soviez.sh (+sha256) regenerated
- build/assemble.sh MODULES
- src/cli/parse.sh, src/entrypoint.sh
- src/migration/authorization/{codes,model,readiness,engine,offline}.sh
- src/migration/token/eligibility.sh
- src/migration/rebind/engine.sh
- src/migration/activation/engine.sh
- src/migration/phase21_readiness/engine.sh
- src/migration/commands/cli.sh
- services/migration-authorization-ledger/ledger.py
- tests/helpers/phase20_fixture.sh
- tests/unit/test_phase20_authorization_unit.sh
- tests/integration/test_phase20_authorization_e2e.sh
- tests/integration/test_phase20_concurrency_and_recovery.sh
- tests/security/test_phase20_static_forbidden.sh
- docs/ai|dev|user migration authorization docs
- docs/evidence/phase-20-atomic-authorization-rebind/*
- PROJECT_STATE.md, docs/ai/DECISION_LOG.md, docs/ai/CURRENT_STATE.md

## soviez-saas
- supabase/migrations/087_migration_authorization_atomic.sql
- src/lib/migration-authorization/{commit.ts,index.ts}
- scripts/phase20-disposable-pg-commit-proof.sh

Frozen SaaS UI: not modified for Phase 20.
