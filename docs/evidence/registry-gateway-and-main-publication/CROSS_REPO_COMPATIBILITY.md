# CROSS_REPO_COMPATIBILITY — Four-Repo Integration

## Repositories

| Repo | Role |
|------|------|
| soviez-sh | Installer source + gateway mirror + certification |
| soviez-saas | Pull session issuer + ticket signer |
| Soviez/soviez-deploy | Canonical gateway publish + dual wizard |
| Soviez/soviez-erp | Dual wizard (`soviez.sh`) |

## Contract alignment

| Contract point | soviez-saas | gateway | installer |
|----------------|-------------|---------|-----------|
| Ticket domain | `soviez.registry-pull-ticket.v1` | same | consumes via stage |
| Ticket format | Ed25519 custom (not JWT) | verifies offline | docker login password |
| Ticket TTL | 900s | enforces `exp` | — |
| Session max | 3600s | — | refresh via SaaS |
| Repository | `soviez/soviez-erp` | ticket-bound | pull target |
| Scope | `pull` only | denies push/catalog | pull only |
| Protocol | `registry-pull/v1` | Registry HTTP V2 subset | wired in dist |
| Upstream | env on gateway host | `registry-1.docker.io` | never sees Hub PAT |

## Dual wizard parity

| Path | SHA256 | Match |
|------|--------|-------|
| ERP `soviez.sh` | `4e162df0…` | — |
| deploy `soviez.sh` | `4e162df0…` | **YES** |

## Artifact chain

| Component | Version / hash |
|-----------|----------------|
| Installer | `0.24.5.3-registry-gateway` |
| SHA256 | `60b7e320777df5ef95ba192247d3e5b22b34078c2dfb2b1d9fc9955caf7e24dc` |
| Gateway package | `@soviez/registry-gateway` 0.1.0 |

## Test coverage by repo

| Repo | Tests | Status |
|------|-------|--------|
| soviez-sh gateway | 20 unit + real pull proof | **PASS** |
| soviez-saas registry | logic + e2e certification | In tree (CI **PENDING** post-push) |
| soviez-sh full suite | `run_all.sh` | **PENDING** |

## Live integration

End-to-end: SaaS authorize → ticket → gateway pull → stage deploy:

**PENDING** — requires staging SaaS + gateway VPS + Hub PAT.

## LIVE_FULL_CYCLE_READY_AFTER_PUBLISH

**NO** — see `LIVE_SIMULATION_READINESS.md`.

## Main SHAs (compatibility pin)

All four repo main SHAs after push: **PENDING** (`MAIN_BRANCH_SHAS.md`)
