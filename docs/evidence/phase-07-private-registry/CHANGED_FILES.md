# Changed files — Phase 7

## Created (soviez-saas)

- `supabase/migrations/083_private_registry_pull_foundation.sql`
- `src/lib/registry/constants.ts`
- `src/lib/registry/codes.ts`
- `src/lib/registry/ticket.ts`
- `src/lib/registry/release-manifest.ts`
- `src/lib/registry/keys.ts`
- `src/lib/registry/util.ts`
- `src/lib/registry/digest-verify.ts`
- `src/lib/registry/offline-bundle.ts`
- `src/lib/registry/service.ts`
- `src/lib/registry/index.ts`
- `src/lib/registry/logic.test.ts`
- `src/lib/registry/e2e/harness.ts`
- `src/lib/registry/e2e/certification.test.ts`
- `src/app/api/installer/registry/releases/resolve/route.ts`
- `src/app/api/installer/registry/pull-sessions/route.ts`
- `src/app/api/installer/registry/pull-sessions/refresh/route.ts`
- `src/app/api/installer/registry/pull-sessions/complete/route.ts`
- `src/app/api/installer/registry/pull-sessions/revoke/route.ts`

## Modified (soviez-saas)

- `package.json` — `test:phase7`, `test:phase7-db`, `test:phase7-all`
- `src/types/database.ts` — generated types for registry tables

## Created (soviez-sh)

- `services/registry-gateway/` — full Node gateway package
  - `src/server.ts`, `auth.ts`, `ticket.ts`, `denial.ts`, `graph.ts`, `proxy.ts`, `config.ts`, `redact.ts`, `mock-upstream.ts`, `index.ts`
  - `test/gateway.test.ts`
  - `package.json`, `README.md`
- `docs/ai/PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`
- `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`
- `docs/evidence/phase-07-private-registry/**`

## Modified (soviez-sh)

- `docs/ai/PRIVATE_REGISTRY_ARCHITECTURE.md` — ADR pointer
- `docs/dev/REGISTRY_GATEWAY.md` — implemented (was Planned)
- `docs/user/WHEN_SOVIEZ_CONNECTS_ONLINE.md`
- `docs/user/OFFLINE_OPERATION.md`
- `docs/user/PRIVACY_AND_SOVEREIGNTY.md`
- `docs/ai/CURRENT_STATE.md`, `DECISION_LOG.md`, `MASTER_IMPLEMENTATION_PLAN.md`
- `docs/ai/SOVEREIGNTY_FIRST_CONSTITUTION.md`, `DATA_EGRESS_CONTRACT.md`
- `docs/ai/CAPABILITY_AND_ENTITLEMENT_MODEL.md`, `DEVICE_AUTHORIZATION_MODEL.md`, `LICENSE_SLOT_RESERVATION_MODEL.md`
- `docs/dev/ENTITLEMENT_API_CONTRACT.md`, `DEVICE_AUTHORIZATION_PROTOCOL.md`
- `PROJECT_STATE.md`

## Created (Soviez ERP — prep only)

- `.github/workflows/phase7-registry-release-metadata.prep.yml`

## Explicitly NOT changed

- `local_license_guard` / installer runtime in `soviez-sh/src`
- Live Docker Hub repository visibility
- Production gateway deployment
