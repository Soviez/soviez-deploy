# Migration TLS Preparation Protocol

Commands:

- `sudo soviez.sh --migration-tls-prepare <pair-id> [--domain FQDN]`
- `sudo soviez.sh --migration-tls-status <operation-id>`
- `sudo soviez.sh --migration-tls-revoke <pair-id> [--fqdn FQDN]`

## Rules

- Certificate for **migration subdomain only** (PASS requires valid mig TLS)
- No Production-domain certificate pre-issue by default
- Prefer DNS-01 ACME; HTTP-01 only on mig FQDN when safe
- Private keys stored locally with restrictive permissions; never logged
- Self-signed rejected as final acceptance

## Test ACME honesty

E2E uses **Pebble 2.7.0** + **lego** with `PEBBLE_VA_ALWAYS_VALID=1`:

- Order / CSR / issue / chain are **real** ACME
- Validation Authority is **short-circuited** by Pebble test mode (documented; not production LE)
