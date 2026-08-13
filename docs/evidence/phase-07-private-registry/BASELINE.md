# Baseline — Phase 7 Private Registry

| Field | Value |
|-------|-------|
| **Date** | 2026-07-30T07:30:00+03:00 |
| **Commit (soviez-saas baseline)** | `2f2f13c655ac42aa976764db56d939bf60a40094` |
| **Dirty count** | ~30 uncommitted files (Phases 3–7 preserved) |
| **Phase gate** | Phase 7 — Private registry & pull auth |
| **Prior phase** | Phase 6 PASS (25%) |
| **Target completion** | 31% (`2+3+5+4+6+5+6=31`) |

## Pre-phase state

- Phase 5 Device PoP: PASS
- Phase 6 License Slot reservation: PASS
- Public Hub pull `soviez/soviez-erp:latest` in legacy installer (unchanged)
- No private registry SaaS APIs
- No streaming gateway

## Phase 7 scope entered

- Migration `083_private_registry_pull_foundation.sql`
- SaaS `/api/installer/registry/*` routes
- `src/lib/registry/*` service layer
- `soviez-sh/services/registry-gateway/` Node service
- CI prep workflow (not live-run): `Soviez ERP/.github/workflows/phase7-registry-release-metadata.prep.yml`
- Evidence pack under `docs/evidence/phase-07-private-registry/`

## Explicit exclusions

- Installer runtime wiring
- `local_license_guard` modifications
- Live Supabase migrate against production (ENOTFOUND if attempted — correctly avoided)
- Docker Hub visibility cutover
- Commit / push / deploy
