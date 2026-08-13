# TEST_PLAN.md

Implementation-ready matrix (no tests written in this review).

## Domain targeting
exact pair · invalid/expired/revoked pair · wrong domain · wildcard denied · cross-tenant denied · already-bound · source inspection · source unchanged

## DNS challenge
valid TXT · missing/wrong TXT · expired · replay · wrong dest/pair · auth/public mismatch · propagation pending · DNSSEC valid/invalid · CNAME/A/AAAA mismatch · IPv4-only · broken IPv6 · exact cleanup

## Landing
Nginx isolated site · security headers · no external assets · healthz · English-only · XSS/host-header injection · no ERP route · no customer DB · reboot · exact cleanup

## TLS
public CA fixture success · CAA allow/block · bad chain · hostname mismatch · expired · wrong key perms · challenge retry · duplicate-order deny · private CA explicit · no self-signed final · reboot

## Routing readiness
PASS/WARNING/BLOCKED · source unchanged/drift · landing+TLS+challenge+pair · report signature/expiry/invalidation

## Abort
challenge revoked · mig cert removed · exact route removed · source unchanged · owner DNS preserved · provider-created exact cleanup · idempotent · reboot

## Security
SSRF · rebinding · subdomain takeover · cert substitution · secret leakage · config injection · broad cleanup · premature cutover · source disruption · payload-transfer static gate

## Integration
disposable source+dest · real Nginx · DNS test zone/fixture · challenge propagation · ACME fixture/staging · real TLS · public mig landing · Try Again · Abort · host reboot · source healthy · no payload · token unchanged · dest ERP inactive
