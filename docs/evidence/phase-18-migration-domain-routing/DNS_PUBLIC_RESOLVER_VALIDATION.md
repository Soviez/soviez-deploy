# DNS_PUBLIC_RESOLVER_VALIDATION

E2E starts **two** recursive CoreDNS forwarders (`public_a`, `public_b`) that must agree with authoritative before challenge verify succeeds.

`src/migration/dns/public_resolvers.sh` implements multi-resolver agreement policy (OD-09).
