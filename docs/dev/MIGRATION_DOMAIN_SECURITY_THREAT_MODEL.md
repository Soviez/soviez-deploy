# Migration Domain Security Threat Model (Phase 18)

## Assets

Migration pair trust; DNS ownership proof; destination landing; mig TLS keys; routing-plan signatures; source Production availability.

## Threats → mitigations

| Threat | Mitigation |
|--------|------------|
| Spoofed DNS ownership | Signed challenge + auth+2 public resolver agreement + replay/expiry |
| Hijack Production domain | Mig subdomain only; Production FQDN/wildcard rejected |
| Source disruption | Read-only source inspection; static no-source-mutation gate |
| Premature transfer/cutover | Static no-payload gate; runtime assert denials |
| Token burn | No reserve/consume paths in Phase 18 modules |
| Landing XSS / leak | Neutral static content; security headers; no PII in URLs |
| Key exposure | Local 0600-style storage; never argv/logs |
| Multi-tenant cross-talk | Pair-scoped paths; isolation test |
| Abort residual | Exact cleanup + owner DNS marker preservation |

## Residual

Full Root on destination can replace verifier artifacts — disclosed, not DRM.
