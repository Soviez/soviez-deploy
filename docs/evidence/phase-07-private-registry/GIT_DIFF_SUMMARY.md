# Git diff summary — Phase 7

**Date:** 2026-07-30  
**Note:** Changes uncommitted by design.

## soviez-saas (implementation)

| Area | Files | Summary |
|------|-------|---------|
| Migration | `083_private_registry_pull_foundation.sql` | +3 tables, RLS, capability seed |
| Library | `src/lib/registry/**` | ~12 modules + 2 test files |
| API routes | `src/app/api/installer/registry/**` | 5 POST routes |
| Types | `src/types/database.ts` | Registry table types |
| Scripts | `package.json` | test:phase7* |

**Approximate:** ~3,500+ lines added (implementation + tests)

## soviez-sh (gateway + docs)

| Area | Files | Summary |
|------|-------|---------|
| Gateway | `services/registry-gateway/**` | Node OCI proxy service |
| AI docs | `docs/ai/PRIVATE_REGISTRY_*` | Model + ADR pointer |
| Dev docs | `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`, `REGISTRY_GATEWAY.md` | Protocol |
| User docs | `docs/user/*` | Pull auth user-facing |
| Evidence | `docs/evidence/phase-07-private-registry/**` | 20 artifacts |
| State | `PROJECT_STATE.md` | 31% completion |

## Soviez ERP (prep)

| File | Summary |
|------|---------|
| `.github/workflows/phase7-registry-release-metadata.prep.yml` | CI candidate metadata |

## Untouched (explicit)

- `soviez-sh/src/**` installer runtime
- `local_license_guard`
- Production Supabase migrations apply
- Live Hub visibility

## Branch state

- soviez-saas: dirty on `main`, commit baseline `2f2f13c…`
- soviez-sh: local docs + gateway, uncommitted
