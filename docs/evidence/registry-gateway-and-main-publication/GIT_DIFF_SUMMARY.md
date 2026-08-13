# GIT_DIFF_SUMMARY — Registry Gateway + Main Publication

## Mission scope

Local changes for artifact `0.24.5.3-registry-gateway` and registry gateway publication. **No commit performed** in this evidence mission.

## Artifact delta

| Field | Baseline | This mission |
|-------|----------|--------------|
| Version | `0.24.5.2-postcert-corr1` | `0.24.5.3-registry-gateway` |
| SHA256 | `af5b6c09ece36fd9a6a9b89cdcac09a16880bfeaff4619f821812dd99497359c` | `60b7e320777df5ef95ba192247d3e5b22b34078c2dfb2b1d9fc9955caf7e24dc` |

## soviez-sh (primary)

| Area | Change |
|------|--------|
| `VERSION`, `dist/soviez.sh`, `dist/soviez.sh.sha256` | Bumped to registry-gateway artifact |
| `services/registry-gateway/` | **NEW** — full gateway package (synced with local ops) |
| `.gitignore` | **NEW** — PP-02/03 closure |
| `docs/dev/REGISTRY_GATEWAY_ARCHITECTURE.md`, `docs/user/REGISTRY_GATEWAY.md` | Gateway documentation |
| `docs/ai/DECISION_LOG.md`, `PROJECT_STATE.md`, cert helpers | Version/hash sync |
| `docs/evidence/registry-gateway-and-main-publication/` | **NEW** — this evidence pack |
| `src/**`, `tests/**` | Registry integration + expected hash updates |

## soviez-registry-gateway (local ops)

Byte-synced with `soviez-sh/services/registry-gateway/` — same gateway source + operator packaging.

## Soviez/soviez-deploy (expected publish)

| Path | Change |
|------|--------|
| `services/registry-gateway/**` | **ADD** (canonical) |
| `soviez.sh` | Dual wizard parity |

Wizard SHA: `4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841`

## Soviez/soviez-erp (expected publish)

| Path | Change |
|------|--------|
| `soviez.sh` only | PP-04 scoped |

## soviez-saas (expected publish)

Registry pull-session issuer (`src/lib/registry/**`, installer registry API routes) — already in tree; main diff **PENDING** until push.

## Blocker closure

| ID | Summary | Status |
|----|---------|--------|
| PP-01 | Remote / publish path | Mapped to deploy repo; push **PENDING** |
| PP-02 | `.gitignore` | **CLOSED** |
| PP-03 | Root secret exclusion | **CLOSED** |
| PP-04 | ERP path scope | **CLOSED** (discipline) |

## Remote diff status

| Repo | Main diff captured | Push |
|------|-------------------|------|
| soviez-sh | Local only | **PENDING** |
| soviez-deploy | See `DEPLOY_MAIN_DIFF.md` | **PENDING** |
| soviez-erp | See `ERP_MAIN_DIFF.md` | **PENDING** |
| soviez-saas | See `SAAS_MAIN_DIFF.md` | **PENDING** |

## Tests

| Suite | Result |
|-------|--------|
| Gateway 20 unit tests | **PASS** |
| REAL_PRIVATE_IMAGE_PULL | **PASS** |
| Full `run_all` | **PENDING** |

## Authorization

Commercial release: **NOT AUTHORIZED**
