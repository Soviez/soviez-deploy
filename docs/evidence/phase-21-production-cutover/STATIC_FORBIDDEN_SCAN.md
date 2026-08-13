# STATIC_FORBIDDEN_SCAN — Phase 21

**Status:** STUB

## Design facts tested

- `tests/security/test_phase21_static_forbidden.sh` scans cutover modules
- Forbids: SaaS relay, source purge/archive, cert revoke during window, broad DNS, wildcard Production, second token consume, Phase 22 archive implementation
- Allows: canonical `soviez_migration_cutover_start`
- Version assert: `0.21.0-phase21`

## Evidence to attach

- [ ] Static scan PASS output
- [ ] Phase 20 scan still forbids transfer-path cutover bypass
