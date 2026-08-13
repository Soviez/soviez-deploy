# CHANGED_FILES — Phase 11

## Created (soviez-sh)

### Runtime source
- `src/stage/codes.sh`
- `src/stage/paths.sh`
- `src/stage/state_machine.sh`
- `src/stage/inventory.sh`
- `src/stage/admission.sh`
- `src/stage/production.sh`
- `src/stage/snapshot.sh`
- `src/stage/clone.sh`
- `src/stage/runtime.sh`
- `src/stage/neutralization.sh`
- `src/stage/domain_ssl.sh`
- `src/stage/engine.sh`
- `src/stage/lifecycle.sh`
- `src/commands/stage.sh`
- `src/commands/stage_offline.sh`

### Tests
- `tests/unit/test_stage_unit.sh`
- `tests/integration/test_stage_multi_integration.sh`
- (helpers as used by ticket fixtures)

### Docs (new)
- `docs/ai/MULTI_STAGE_RUNTIME_MODEL.md`
- `docs/dev/STAGE_RUNTIME_PROTOCOL.md`
- `docs/dev/STAGE_NEUTRALIZATION_PROFILE.md`
- `docs/user/STAGE_ENVIRONMENTS.md`
- `docs/evidence/phase-11-multi-stage-runtime/*`

## Modified (soviez-sh)

- `src/cli/parse.sh` — Stage CLI flags
- `src/entrypoint.sh` — Stage command dispatch
- `build/assemble.sh` — stage module inclusion
- `VERSION` → `0.11.0-phase11`
- `dist/soviez.sh` + `dist/soviez.sh.sha256` (regenerated)
- `PROJECT_STATE.md` → PASS 60%
- `PRODUCT_CONSTITUTION.md` — Phase 11 additive rules
- `docs/ai/CURRENT_STATE.md`, `DECISION_LOG.md`, `MASTER_IMPLEMENTATION_PLAN.md`
- `docs/ai/SOVEREIGNTY_FIRST_CONSTITUTION.md`, `DATA_EGRESS_CONTRACT.md`
- `docs/ai/STAGE_LICENSE_COMMERCIAL_MODEL.md`, `STAGE_OPERATION_AUTHORIZATION_MODEL.md`
- `docs/dev/STAGE_LICENSE_PROTOCOL.md`, `STAGE_OPERATION_TICKET_PROTOCOL.md`, `STAGE_TOOLING_ARTIFACT.md`
- `docs/user/STAGE_LICENSE.md`, `STAGE_RETENTION.md`, `PRIVACY_AND_SOVEREIGNTY.md`, `INSTALLATION.md`

## Not modified
- `soviez-saas` (no Phase 11 schema)
- `local_license_guard`
- Live Stripe / Supabase / Hub
