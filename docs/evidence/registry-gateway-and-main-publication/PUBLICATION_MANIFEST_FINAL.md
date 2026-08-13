# PUBLICATION_MANIFEST_FINAL — Registry Gateway + Main Publication

## Mission artifact

| Field | Value |
|-------|-------|
| Version | `0.24.5.3-registry-gateway` |
| SHA256 | `60b7e320777df5ef95ba192247d3e5b22b34078c2dfb2b1d9fc9955caf7e24dc` |
| Baseline | `0.24.5.2-postcert-corr1` / `af5b6c09ece36fd9a6a9b89cdcac09a16880bfeaff4619f821812dd99497359c` |

## Publication decision (D130)

| Component | Publish path | Repository |
|-----------|--------------|------------|
| Registry Gateway | `services/registry-gateway/` | `Soviez/soviez-deploy` |
| Dual wizard | `soviez.sh` | `Soviez/soviez-erp` + `Soviez/soviez-deploy` |
| Installer + docs + tests | full soviez-sh tree | soviez-sh (remote **PENDING** PP-01) |
| SaaS registry APIs | lifecycle-expanded set | soviez-saas |

**No separate GitHub repo** for registry-gateway.

## Per-repository publish set

### soviez-sh

| Classification | Publish? | Notes |
|----------------|----------|-------|
| `dist/soviez.sh` + `.sha256` | **YES** | New artifact hash |
| `VERSION` | **YES** | `0.24.5.3-registry-gateway` |
| `src/**`, `tests/**`, `tools/**` | **YES** | Registry integration + regression |
| `docs/**` | **YES** | Includes this evidence pack |
| `services/registry-gateway/**` | **YES** | Mirror for deploy publish (excl. node_modules, dist) |
| `.gitignore` | **YES** | PP-02 closure |

### Soviez/soviez-deploy

| Path | Publish? |
|------|----------|
| `services/registry-gateway/**` | **YES** (canonical) |
| `soviez.sh` | **YES** (dual wizard parity) |

### Soviez/soviez-erp

| Path | Publish? |
|------|----------|
| `soviez.sh` | **YES** (PP-04 scoped) |

### soviez-saas

| Path | Publish? |
|------|----------|
| `src/lib/registry/**` | **YES** |
| `src/app/api/installer/registry/**` | **YES** |
| Related migrations (078–090 registry/stage) | **YES** |

## Representative new entries (this cycle)

| repository | relative path | classification | why |
|------------|---------------|----------------|-----|
| soviez-sh | `services/registry-gateway/` | PUBLISH_REQUIRED | Gateway package mirror |
| soviez-deploy | `services/registry-gateway/` | PUBLISH_REQUIRED_CROSS_REPO | Canonical gateway publish |
| soviez-sh | `docs/dev/REGISTRY_GATEWAY_ARCHITECTURE.md` | CANONICAL_DOCUMENTATION | Architecture |
| soviez-sh | `docs/user/REGISTRY_GATEWAY.md` | CANONICAL_DOCUMENTATION | Operator guide |
| soviez-sh | `docs/evidence/registry-gateway-and-main-publication/**` | CERTIFICATION_EVIDENCE | This mission |
| soviez-sh | `dist/soviez.sh` | GENERATED_ARTIFACT | `60b7e320…` |

## Push status

| Repo | Main SHA | Status |
|------|----------|--------|
| soviez-sh | PENDING | Not pushed |
| soviez-deploy | PENDING | Not pushed |
| soviez-erp | PENDING | Not pushed |
| soviez-saas | PENDING | Not pushed |

See `MAIN_BRANCH_SHAS.md`.
