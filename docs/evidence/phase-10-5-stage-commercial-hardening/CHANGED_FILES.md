# CHANGED_FILES — Phase 10.5 Stage Commercial Hardening

Known paths as of documentation pass (uncommitted work may add more).

## soviez-saas (implementation — sibling repo)

- `supabase/migrations/086_stage_operation_authorization.sql`
- `src/lib/stage-operation/constants.ts`
- `src/lib/stage-operation/ticket.ts`
- `src/lib/stage-operation/keys.ts`
- `src/lib/stage-operation/service.ts`
- `src/lib/stage-operation/neutralization.ts`
- `src/lib/stage-operation/origin-certificate.ts`
- `src/lib/stage-operation/offline.ts`
- `src/lib/stage-operation/index.ts`
- `src/lib/stage-operation/logic.test.ts`
- `src/lib/stage-operation/routes.contract.test.ts`
- `src/lib/stage-operation/e2e/`
- `src/app/api/installer/stage/operations/authorize/route.ts`
- `src/app/api/installer/stage/operations/consume/route.ts`
- `src/app/api/installer/stage/operations/complete/route.ts`
- `src/app/api/installer/stage/operations/status/route.ts`
- `src/app/api/installer/stage/operations/revoke/route.ts`
- `src/app/api/installer/stage/operations/offline/package/route.ts`

## soviez-sh

- `services/stage-operation-helper/package.json`
- `services/stage-operation-helper/tsconfig.json`
- `services/stage-operation-helper/ARTIFACT.md`
- `services/stage-operation-helper/src/ticket.ts`
- `services/stage-operation-helper/src/ledger.ts`
- `services/stage-operation-helper/src/neutralization.ts`
- `services/stage-operation-helper/src/cli.ts`
- `services/stage-operation-helper/src/index.ts`
- `services/stage-operation-helper/test/helper.test.ts`
- `PROJECT_STATE.md`
- `PRODUCT_CONSTITUTION.md`
- `docs/ai/STAGE_COMMERCIAL_ENFORCEMENT_THREAT_MODEL.md`
- `docs/ai/STAGE_OPERATION_AUTHORIZATION_MODEL.md`
- `docs/ai/STAGE_LICENSE_COMMERCIAL_MODEL.md`
- `docs/ai/CURRENT_STATE.md`
- `docs/ai/DECISION_LOG.md`
- `docs/ai/MASTER_IMPLEMENTATION_PLAN.md`
- `docs/ai/SOVEREIGNTY_FIRST_CONSTITUTION.md`
- `docs/ai/DATA_EGRESS_CONTRACT.md`
- `docs/dev/STAGE_OPERATION_TICKET_PROTOCOL.md`
- `docs/dev/STAGE_TOOLING_ARTIFACT.md`
- `docs/dev/STAGE_LICENSE_PROTOCOL.md`
- `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`
- `docs/user/STAGE_LICENSE.md`
- `docs/user/STAGE_RETENTION.md`
- `docs/user/PRIVACY_AND_SOVEREIGNTY.md`
- `docs/evidence/phase-10-5-stage-commercial-hardening/*`

## Explicitly unchanged (this phase)

- Installer `--stage` wiring
- Stage containers / runtime
- `local_license_guard`
