# TLS_PREPARATION_MODEL.md

## Pre-cutover policy

- Public trusted CA default (Let's Encrypt via Phase 12 provider abstraction)  
- Exact hostname = migration FQDN only (default)  
- No wildcard unless OD + `SOVIEZ_SSL_ALLOW_WILDCARD`  
- No self-signed final acceptance  
- Private CA only if explicit enterprise policy  
- Private key local `0600`; never argv/logs/state/evidence  
- ACME account key local-only  
- CAA checked before order  
- Clock skew gate (reuse Phase 17 5-minute skew)  
- Chain + hostname validation required  
- OCSP stapling where Nginx supports — optional enhancement  

## What Phase 18 issues

| Certificate | Default |
|-------------|---------|
| Migration-subdomain cert | **Mandatory** for routing readiness PASS |
| Production-domain cert pre-issue | **Deferred / deny by default** (OD-18) |

## Renewal before cutover

Renewal for migration subdomain allowed if still within Phase 18 validity window; must not attach to Production domain. On Abort, revoke/remove mig cert.

## HTTP-01 vs DNS-01

- **Ownership:** signed TXT (Phase 18 challenge)  
- **ACME:** DNS-01 preferred when possible; HTTP-01 allowed on migration FQDN **only after** A/AAAA points to destination and landing/nginx can serve challenge — never on Production apex in Phase 18  

## Storage

Separate inventory namespace: `migration_tls/<pair_id>/<fqdn>.json` — paths to cert/key; keys under `secrets/` 0700.
