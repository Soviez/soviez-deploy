# SECURITY_THREAT_MODEL.md

| Threat | Mitigation |
|--------|------------|
| Forged / replayed / stale DNS challenge | Sign binding; expiry; consume; nonce |
| Wildcard abuse | Single FQDN only; deny `*` |
| Subdomain takeover | Require A/AAAA/CNAME exact match to dest plan; detect dangling CNAME |
| DNS rebinding | Pin expected addresses; short TTL checks |
| Wrong pair/License/dest | Exact IDs in signature |
| Cert misissuance | CAA; public CA; hostname verify; no self-signed final |
| ACME/TLS/DNS-provider key leakage | Local 0600/0700; never SaaS; never argv/logs/evidence |
| Nginx config injection | Escape server_name; owned templates only |
| Host-header / open redirect / XSS / HTML injection | Exact Host; no user HTML; CSP; escape placeholders |
| Cache poisoning | no-store status; careful Vary |
| SSRF via domain checks | Allowlist schemes; block link-local/metadata IPs for fetchers; DNS resolve only |
| Resolver poisoning | Authoritative + multi public agreement |
| Command injection / path traversal / symlink | No shell-interp of DNS values; realpath checks |
| Broad nginx/cert cleanup | Exact owned paths only |
| Auto Production-domain mutation | Hard ban Phase 18 |
| Source disruption / premature cutover | Source guards; cutover codes deny |
| Hidden tracking / SaaS traffic relay / payload transfer | Static gates; landing CSP; no proxy |
| Malicious Root | Root can always bypass local gates; product still refuses automated unsafe defaults and documents Root boundary honestly |
