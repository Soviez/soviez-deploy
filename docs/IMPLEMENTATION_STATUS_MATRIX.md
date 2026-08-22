# Soviez.sh Implementation Status Matrix

**Contract:** [SOVIEZ_SH_PRODUCT_CONTRACT.md](SOVIEZ_SH_PRODUCT_CONTRACT.md)  
**Platform build:** `0.24.6.3-platform-cli`  
**Last reviewed:** 2026-08-22

**Status vocabulary**

| Status | Meaning |
|--------|---------|
| `APPROVED_NOT_IMPLEMENTED` | In product contract; no runtime yet |
| `IMPLEMENTED_NOT_CERTIFIED` | Code exists; not live-certified |
| `CERTIFIED_FIXTURE` | Certified in fixture/CI only |
| `CERTIFIED_LIVE` | Live-certified on Ubuntu 22.04/24.04 |
| `BLOCKED` | Cannot proceed (dependency / authorization) |

**Publicly documentable as available?** Only `CERTIFIED_LIVE` and `CERTIFIED_FIXTURE` for customer-facing claims unless explicitly marked "upcoming" per product policy.

---

| Feature | Product contract | Implementation status | Certification | Publicly available? | Evidence |
|---------|------------------|----------------------|---------------|---------------------|----------|
| PATH CLI `soviez.sh` | §3 | `CERTIFIED_LIVE` | Lima PATH bootstrap | Yes | `docs/evidence/final-live-runtime-closure/` |
| `--help`, `--version`, `--list` | §3.1 | `CERTIFIED_LIVE` | Lima | Yes | CLI_FINAL.md |
| `--operations` | §3.1 | `CERTIFIED_FIXTURE` | CI | Yes | run_all |
| `--security-status` | §3.1 | `CERTIFIED_FIXTURE` | CI | Yes | security gates |
| `--init` (modular PATH) | §4 | `APPROVED_NOT_IMPLEMENTED` | — | No (use wizard interim) | parse.sh lacks `--init` |
| `--init` (dual wizard) | §4 interim | `CERTIFIED_LIVE` | Lima 22.04/24.04 | Interim only | u2404_init.log |
| `--new` | §7 | `CERTIFIED_FIXTURE` | CI partial | Partial | blocked: ERP image |
| `--update` | §3.3 | `CERTIFIED_FIXTURE` | CI | Partial | update tests |
| `--backup` / `--restore` | §3.3 | `IMPLEMENTED_NOT_CERTIFIED` | S3 flake | Partial | backup tests |
| Stage commands | §3.4 | `CERTIFIED_FIXTURE` | CI stage e2e | Partial | stage tests |
| `--tune` / `--dry-run` | §9 | `CERTIFIED_LIVE` | Lima dry-run | Yes | CLI_FINAL.md |
| `--tune --explain` | §9 | `APPROVED_NOT_IMPLEMENTED` | — | No | — |
| `--tune` apply | §9 | `IMPLEMENTED_NOT_CERTIFIED` | — | No | — |
| `--releases` | §3.6 | `APPROVED_NOT_IMPLEMENTED` | — | No | — |
| `--release-status` | §3.6 | `APPROVED_NOT_IMPLEMENTED` | — | No | — |
| `--doctor` | §3.9 | `APPROVED_NOT_IMPLEMENTED` | — | No | — |
| `--safe-mode` / exit | §3.8 | `APPROVED_NOT_IMPLEMENTED` | — | No | — |
| `--migration-*` | §3.7 | `CERTIFIED_FIXTURE` | CI | Partial | migration tests |
| Legacy merge-in migration | Forbidden | N/A (not supported) | — | No | — |
| Ed25519 self-update | §8 | `CERTIFIED_FIXTURE` | CI | Yes | phase 24 |
| Adaptive workers / 8072 | §9 | `IMPLEMENTED_NOT_CERTIFIED` | — | Contract only | WEBSOCKET doc |
| ClamAV on `--init` | §11 | `IMPLEMENTED_NOT_CERTIFIED` | on-demand policy | Partial | tooling_policy |
| YARA native scanner | §11 | `CERTIFIED_FIXTURE` | CI | Partial | security gates |
| PG least privilege | §10 | `CERTIFIED_LIVE` | Lima disposable PG | Yes | POSTGRES_SECURITY_LIVE |
| Webmin never install | §2 | `CERTIFIED_FIXTURE` | CI | Yes | installer tests |
| Stage retention 14/60d | §12 | `CERTIFIED_FIXTURE` | CI | Yes | stage policy tests |
| Offline sovereignty | §2 | `CERTIFIED_FIXTURE` | CI | Yes | offline tests |
| Private Docker Hub pull | §5 future | `APPROVED_NOT_IMPLEMENTED` | — | Future | PRIVATE_IMAGE_DELIVERY |

---

## Approved but not implemented (summary)

- `--doctor`, `--release-status`, `--releases`, `--safe-mode`, `--tune --explain`
- Modular PATH `--init` (convergence from dual wizard)
- Private image short-lived pull authorization (future)
- Full `--tune` apply live certification

## Implemented but not live-certified (summary)

- Full Odoo stack + WebSocket 101 on Lima
- ClamAV operational baseline on `--init`
- Backup/restore live S3 paths
- Connected self-update from staging manifest (404 without push)

## Certified live (summary)

- PATH launcher, `--version`, `--list`, `--stage-list`, `--tune --dry-run`
- Dual wizard `--init` on Ubuntu 22.04/24.04
- PostgreSQL least-privilege matrix (disposable container)

## Public features withheld (lack certification)

- `--doctor`, `--release-status`, `--releases`, `--safe-mode`
- `--tune --explain`, `--tune` apply
- Claims that modular `--init` replaces wizard today
- Full Production stack without ERP image availability
