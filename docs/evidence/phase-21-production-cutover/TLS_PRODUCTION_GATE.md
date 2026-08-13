# TLS_PRODUCTION_GATE — Phase 21

**Status:** STUB

## Design facts tested

- Fixture openssl cert for exact FQDN (`SOVIEZ_MIG_TLS_ALLOW_SELF_SIGNED=1` in fixture)
- Hostname CN/SAN must match Production FQDN
- Wrong CN → `MIGRATION_TLS_HOSTNAME_MISMATCH`
- Expiry within 24h → `MIGRATION_TLS_PRODUCTION_EXPIRED`

## Evidence to attach

- [ ] Successful validate JSON
- [ ] Hostname mismatch inject error
