# DNS_CUTOVER_FIXTURE — Phase 21

**Status:** STUB

## Design facts tested

- Exact single A record mutation only (`SOVIEZ_MIG_P21_DNS_ZONE_DIR/<fqdn>/A.txt`)
- Rollback restores `previous_dns_target`
- Wildcard FQDN forbidden
- Propagation observe: authoritative + two public views (fixture majority)
- Optional real DNS: `SOVIEZ_MIG_P21_REQUIRE_REAL_DNS=1` (not required for PASS)

## Evidence to attach

- [ ] `tests/integration/test_phase21_dns_authoritative.sh` output
- [ ] Zone file before/after/rollback
