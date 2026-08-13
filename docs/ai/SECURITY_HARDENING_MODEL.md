# Security Hardening Model (Phase 24)

## Policy (production-default)

- Unsigned protected artifacts => DENY
- Invalid / unknown / wrong-purpose / revoked signer => DENY
- Digest/checksum match is integrity only — not authorization
- Soft `STRICT_SIG=0` / `ALLOW_UNSIGNED` / fixture-token escapes are denied outside disposable test bypass
- Test bypass requires: `SOVIEZ_TEST_MODE=1` AND disposable env AND not production target; denied when `SOVIEZ_PHASE24_FORBID_TEST_BYPASS=1`

## Ownership

| Concern | Owner modules | Phase |
|---------|---------------|-------|
| Connected update signatures | `src/update/release.sh` + `src/security/signatures.sh` | 15+24 |
| Offline bundle crypto | `src/offline_trust/*` + Phase 23 import | 23+24 |
| Ticket replay stores | existing update/offline/migration nonce ledgers + `src/security/replay_audit.sh` | 15/23/24 |
| Registry credentials | `src/offline_bundle/export/registry.sh` + `src/security/registry_hygiene.sh` | 7/23/24 |
| Secret scan | `tools/secret_scan.sh` + `src/security/dist_scan.sh` | 24 |
| Phase 25 readiness | `src/security/readiness.sh` (informational only) | 24 |

## Non-goals

No new update/backup/entitlement/Registry/ticket engines. No Phase 25. No live rollout.

Generated: 2026-08-09T21:22:30Z
