# OWNER_DECISIONS.md

Status: **OPEN — recommendations only; not silently binding commercial/live-routing policy.**

| OD | Decision | Recommended default |
|----|----------|---------------------|
| 01 | Canonical domain strategy | Dedicated migration subdomain (Option A) |
| 02 | Default naming | `migrate.<production-domain>` |
| 03 | Soviez-controlled validation domains | Optional lab only; not canonical ownership |
| 04 | TXT vs TXT+reachability | TXT ownership + A/AAAA or CNAME reachability |
| 05 | Challenge validity | 30 minutes |
| 06 | DNS TTL recommendation | 300 seconds |
| 07 | Propagation WARNING | 15 minutes |
| 08 | Propagation BLOCKED | 60 minutes |
| 09 | Resolver agreement | Authoritative + ≥2 public must agree |
| 10 | DNSSEC | Validate when present; not globally mandatory |
| 11 | IPv6 | Optional unless configured; IPv4 mandatory |
| 12 | Automated DNS adapters in Phase 18 | Stub contract OK; full adapters deferred unless approved |
| 13 | Initial providers | None required |
| 14 | Auto-clean owner DNS on Abort | **No** — instructions only |
| 15 | Landing wording/branding | Soviez operational English templates; customer brand later OD |
| 16 | English-only | Yes this stage |
| 17 | Mig-subdomain TLS required for PASS | **Yes** |
| 18 | Production-domain cert pre-issue | **No** by default |
| 19 | ACME provider | Let's Encrypt default; fixture for tests |
| 20 | HTTP-01 vs DNS-01 ACME | DNS-01 preferred; HTTP-01 only on mig FQDN when safe |
| 21 | Private CA | Explicit policy only |
| 22 | Renewal before cutover | Allowed for mig FQDN only |
| 23 | Landing retention after Abort | Remove/disable by default |
| 24 | Log retention/privacy | Local short retention; no PII in URLs |
| 25 | Max Try Again frequency | Align Phase 12 backoff; min interval 30s |
| 26 | Nginx mandatory | Yes initial; no Caddy/Traefik support yet |
| 27 | Landing container permanence | Temporary |
| 28 | Public mig subdomain exposure | Allowed after DNS+TLS |
| 29 | Source drift checks | DNS + nginx checksum + cert digest + /web/login |
| 30 | PASS/WARNING/BLOCKED | See ROUTING_READINESS_MODEL |
| 31 | Disabled ERP route templates | Optional; default prepare stub disabled |
| 32 | Lower Production TTL in Phase 18 | **No** by default |
| 33 | Manual DNS cleanup ownership | Installer prints exact records; owner executes |
| 34 | Offline/manual cert import | Optional advanced; not default PASS path |
| 35 | Readiness report validity | 24h or material invalidation |
