# Migration Domain Abort Protocol

Command: `sudo soviez.sh --migration-domain-abort <pair-id>`

## Exact cleanup (destination)

- Revoke local DNS challenge state
- Remove temporary landing site / nginx config generated for mig FQDN
- Revoke/remove mig-subdomain TLS material prepared by Phase 18
- Invalidate routing readiness objects

## Preservation

- **Owner DNS records are not auto-deleted** (instructions only)
- Source Production DNS, nginx, certificates, and traffic remain unchanged
- Migration Token untouched; no payload transfer; no Production cutover

Owner executes any DNS cleanup using printed exact records.
