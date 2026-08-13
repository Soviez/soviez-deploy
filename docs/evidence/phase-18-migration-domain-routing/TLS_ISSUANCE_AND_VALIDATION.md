# TLS_ISSUANCE_AND_VALIDATION

- Mig FQDN only; Production pre-issue denied by default
- Self-signed rejected as final acceptance (unit)
- Inventory must not include private key material in status JSON
- Module: `src/migration/tls/{engine,acme,verify,policy,storage,pebble}.sh`
