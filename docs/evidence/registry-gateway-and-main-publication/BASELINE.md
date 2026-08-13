# BASELINE — Registry Gateway + Main Publication Mission

| Field | Value |
|-------|-------|
| Mission start (UTC) | 2026-08-13 |
| Mission | Registry Gateway installable + artifact `0.24.5.3-registry-gateway` + main publication prep |
| Prior certified artifact | `0.24.5.2-postcert-corr1` |
| Prior SHA256 | `af5b6c09ece36fd9a6a9b89cdcac09a16880bfeaff4619f821812dd99497359c` |
| New artifact | `0.24.5.3-registry-gateway` |
| New SHA256 | `60b7e320777df5ef95ba192247d3e5b22b34078c2dfb2b1d9fc9955caf7e24dc` |
| Phase 25 certification | PASS (inherited) |
| Post-cert corrective | PASS (inherited) |
| Registry Gateway | IMPLEMENTED / INSTALLABLE / TESTED |
| Gateway unit tests | **20/20 PASS** |
| REAL_PRIVATE_IMAGE_PULL | **PASS** (`gateway_http_oci_disposable_upstream`) |
| Full `run_all` on new artifact | **PENDING** (in progress) |
| Main branch SHAs | **PENDING** (push not done) |
| Commercial release | **NOT AUTHORIZED** |
| Git mutations this mission | Local evidence + artifact build only (no commit requested) |

## Scope delta from baseline

| Area | Baseline (`0.24.5.2-postcert-corr1`) | This mission |
|------|--------------------------------------|--------------|
| Installer artifact | Post-cert corrective only | Adds registry-gateway integration surface |
| Deploy repo publish | Dual wizard `soviez.sh` only | + `services/registry-gateway/` tree |
| SaaS | Registry pull-session APIs (Phase 7) | Contract frozen for gateway verification |
| Gateway service | Not present | New installable package (byte-synced) |

## Evidence root

`docs/evidence/registry-gateway-and-main-publication/`
