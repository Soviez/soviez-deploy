# EXISTING_DOMAIN_SSL_CAPABILITY_INVENTORY.md

Inventory of primitives relevant to Phase 18. Classification: **reusable** / **refactor** / **unsafe** / **obsolete** / **duplicate**.

| # | Primitive | File / function | Owner phase | Side | Exact-target | Local/connected/offline | Secrets | Cert/key | Ops engine | Reboot | Mutates live DNS? | Mutates source routing? | Issues cert? | Starts/stops ERP? | Class |
|---|-----------|-----------------|-------------|------|--------------|-------------------------|---------|----------|------------|--------|-------------------|-------------------------|--------------|-------------------|-------|
| 1 | SSL challenge create/verify/consume/abort | `src/ssl/challenge.sh` `soviez_ssl_challenge_*` | 12 | either (env-bound) | env+domain+host+op | local; no provider mutate | nonce in 0600 JSON; no private keys | binding digest only | via SSL ops | state on disk | **No** (manual place) | No | No | No | **reusable** (extend for pair binding) |
| 2 | ACME provider abstraction | `src/ssl/provider.sh` | 12 | dest/prod/stage | env domain | fixture local; LE connected stub | ACME account intended local | issues via fixture/local_ca; LE cmd file | yes | inventory | No | No | Yes (fixture/local) | No | **reusable** + **refactor** for mig-subdomain |
| 3 | Let's Encrypt command render | `src/ssl/letsencrypt.sh` | 12 | host | domain | connected host tooling | email in cmd file risk | renders certbot cmdline | indirect | n/a | No | No | Intended | No | **refactor** (avoid argv secrets; DNS-01 path) |
| 4 | SSL policy (CA/wildcard/renewal) | `src/ssl/policy.sh` | 12 | both | env | local | flags only | denies self-signed final | n/a | n/a | No | No | No | No | **reusable** |
| 5 | Inventory atomic write | `src/ssl/inventory.sh` | 12 | both | env_id | local | no keys in inventory | paths only | yes | survives | No | No | No | No | **reusable** (separate mig inventory) |
| 6 | Monitor / expiry / hostname / perms | `src/ssl/monitor.sh` | 12 | both | env | local | key path checks 0600 | validate | yes | yes | No | No | No | No | **reusable** |
| 7 | Promote / rollback cert+nginx | `src/ssl/promote.sh` | 12 | both | env | local | keys local | promote | yes | rollback paths | No | **Can** change nginx for that env | Yes promote | No | **refactor** — must not touch **source** Production in Phase 18 |
| 8 | Temp HTTP readiness | `src/ssl/readiness.sh` `soviez_ssl_provision_temp_http` | 12 | provision | domain | local | none | incomplete HTTP | yes | marker file | No | Can stage temp HTTP for **that** env | No | No | **unsafe** if applied to live Production domain during migration; **reusable** only for mig subdomain |
| 9 | Backoff / env lock | `src/ssl/backoff.sh` | 12 | both | env lock | local | none | n/a | yes | yes | No | No | No | No | **reusable** |
| 10 | Local CA | `src/ssl/local_ca.sh` | 12 | private deploys | env | local | CA key local | issues | optional | yes | No | No | Yes private | No | **reusable** only with explicit policy |
| 11 | SSL engine renew/repair | `src/ssl/engine.sh` | 12 | both | env | local+fixture | none in state | drives challenge+issue | yes | recovery_required | No auto DNS | Can reload owned nginx | Yes | No | **refactor** for migration ops types |
| 12 | Nginx stub render | `src/nginx/render.sh` | early/8 | either | domain | local | none | none | no | n/a | No | Writes stub conf | No | No | **obsolete** for production; keep as stub |
| 13 | Nginx ownership promote/reload/rollback | `src/nginx/ownership.sh` | 12 | either | env+domain | local | none | ssl paths in conf | yes | yes | No | **Yes** for owned site | No | No | **reusable** with **exact migration-site** ownership; **unsafe** if broad cleanup |
| 14 | Migration pair object | `src/migration/pairing/engine.sh` | 17 | pair | exact pair | local+offline | trust keys 700 | pair certs | migration ops | recovery_required | **false** flag | No | Pair mTLS only | No | **reusable** prerequisite |
| 15 | Destination bootstrap | `src/migration/bootstrap/engine.sh` | 17 | destination | bootstrap_id | local | device keys | installer digest | yes | yes | No | No | No Production | No | **reusable** prerequisite |
| 16 | Migration readiness / abort | `src/migration/readiness/engine.sh` | 17 | pair | pair_id | local | none | report sig | yes | yes | asserts dns_changed=false | asserts no maintenance | No | No | **reusable** pattern; Phase 18 adds domain readiness object |
| 17 | Discovery domain/ssl inspect (read) | `src/migration/discovery/collectors.sh` | 17 | source | production_id | local/fixture | none | status fields only | discovery op | n/a | No | No | No | No | **reusable** for source inspection |
| 18 | Signed report store | `src/migration/common/report.sh` | 17 | local | object | local | signing via device | n/a | n/a | yes | No | No | No | No | **reusable** for routing readiness report |
| 19 | Ops conflict / sync | `src/ops/*` | 14 | both | env locks | local | none | n/a | core | yes | No | No | No | No | **reusable** |
| 20 | Stage DNS/SSL gate fixtures | Stage modules | 11 | stage | stage_id | fixture/local | none | stage SSL | stage ops | yes | Fixture only | Stage nginx | Stage certs | Stage only | **do not reuse** for Production migration cutover |
| 21 | SaaS Stage origin certificate | saas `origin-certificate.ts` | 10/11 | SaaS↔installer | stage | connected | signing keys server | origin cert metadata | stage authorize | n/a | No | No | Origin evidence only | No | **not** Migration Token / not Phase 18 domain ownership |
| 22 | SaaS migration_token capability | saas commercial | 3/20 | commercial | account/license | connected | none for Phase 18 | n/a | n/a | n/a | No | No | No | No | **forbidden** consume in Phase 18; eligibility read-only if needed |
| 23 | Legacy `--formssl` / `--change-domain` | `soviez-deploy/soviez.sh` | legacy | tenant | tenant ref | connected LE | certbot on host | issues LE/selfsigned | n/a | n/a | Operator DNS assumed | **Yes** repoints nginx/domain | Yes | Can stop web for maintenance containers | **unsafe/obsolete** for Phase 18 defaults — must not be copied as cutover |
| 24 | Legacy maintenance containers | legacy `run_odoo_maintenance*` | legacy | source | tenant | local docker | none special | n/a | n/a | n/a | No | Stops web ERP | No | **Yes** stops web | **unsafe** — not Phase 18 landing |
| 25 | Caddy/Traefik | (collision detect only in legacy) | — | — | — | — | — | — | — | — | — | — | — | — | **not present** as supported proxy; Nginx mandatory initial |
| 26 | DNS provider credential model | — | — | — | — | — | — | — | — | — | — | — | — | — | **absent** — Phase 18 must invent local-only adapter contract |
| 27 | Maintenance landing page | — | — | destination | — | — | — | — | — | — | — | — | — | — | **absent** — new Phase 18 deliverable |
| 28 | Authoritative/public DNS resolvers | — | — | — | — | — | — | — | — | — | — | — | — | — | **absent** — new Phase 18 DNS check modules |

## Summary

- **Reusable:** Phase 12 challenge/policy/inventory/monitor/backoff/nginx ownership; Phase 17 pair/bootstrap/report/abort patterns; Phase 14 ops locks.  
- **Refactor:** LE issuance path; SSL promote to refuse source Production mutation; challenge binding must add migration_pair_id + bootstrap_id.  
- **Unsafe/obsolete:** legacy `--change-domain`, stopping ERP for maintenance, applying temp HTTP to live Production domain, broad nginx cleanup.  
- **Missing (new):** landing content/container, DNS authoritative/public checks, routing-plan object, migration-specific ops types, provider-neutral DNS adapter.
