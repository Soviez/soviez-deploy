# CHANGE_PROVENANCE

Because soviez-sh has **zero commits**, provenance is reconstructed from:

1. Decision log / PROJECT_STATE (D127 Phase 25, D128 docs canon, D129 post-cert)
2. Evidence packs listed in mission §9
3. Post-cert `RUNTIME_CORRECTIONS.md` + dual-wizard diffs
4. `tests/security/test_postcert_websocket_parity.sh` and allowlist updates
5. Artifact VERSION/SHA match
6. Timestamps only as weak signal (not authoritative)

## Cycle feature map → repos

| Feature | soviez-sh | ERP wizard | deploy wizard | saas |
|---------|-----------|------------|---------------|------|
| Lifecycle install/update/stage/backup/migration | YES | bootstrap wizard | same | entitlement APIs |
| Security S1–S6 + S5 apt-lock correction | YES | apt-lock safety in wizard | same | — |
| Post-cert WS/proxy_mode/workers | YES modular nginx + topology | YES | YES | — |
| Canonical docs | YES | — | — | — |
| Certification evidence | YES | — | — | phase scripts/docs optional |
| License/Device/slot/registry/stage/migration/offline | consumer | — | — | **producer** schema+API |

## Not this cycle (ERP)
Partner Subledger / Lugmety CHANGELOG and business modules → exclude from Soviez.sh publication commits.
