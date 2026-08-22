# Soviez.sh Implementation Status Matrix

**Contract:** [SOVIEZ_SH_PRODUCT_CONTRACT.md](SOVIEZ_SH_PRODUCT_CONTRACT.md)  
**Platform build:** `0.24.6.4-platform-cli`  
**Last reviewed:** 2026-08-22 (contract runtime implementation closure)

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
| `--security-status` (operational) | §3.1 | `IMPLEMENTED_NOT_CERTIFIED` | CI partial | Partial | security gates |
| `--init` (modular PATH) | §4 | `IMPLEMENTED_NOT_CERTIFIED` | test-mode smoke | No (not live-certified) | `src/commands/init.sh` |
| `--init` (dual wizard delegate) | §4 compat | `CERTIFIED_LIVE` | Lima 22.04/24.04 | Interim only | u2404_init.log |
| `--new` | §7 | `CERTIFIED_FIXTURE` | CI partial | Partial | catalog digest |
| `--update` | §3.3 | `CERTIFIED_FIXTURE` | CI | Partial | update tests |
| `--backup` / `--restore` | §3.3 | `IMPLEMENTED_NOT_CERTIFIED` | CI | Partial | backup tests |
| Stage commands | §3.4 | `CERTIFIED_FIXTURE` | CI stage e2e | Partial | stage tests |
| `--tune` / `--dry-run` | §9 | `CERTIFIED_LIVE` | Lima dry-run | Yes | CLI_FINAL.md |
| `--tune --explain` | §9 | `IMPLEMENTED_NOT_CERTIFIED` | test-mode | No | `src/commands/tune.sh` |
| `--tune` apply | §9 | `IMPLEMENTED_NOT_CERTIFIED` | — | No | — |
| `--releases` | §3.6 | `IMPLEMENTED_NOT_CERTIFIED` | catalog | No | `share/releases/catalog.json` |
| `--release-status` | §3.6 | `IMPLEMENTED_NOT_CERTIFIED` | test-mode | No | — |
| `--doctor` | §3.9 | `IMPLEMENTED_NOT_CERTIFIED` | test-mode | No | `src/commands/doctor.sh` |
| `--safe-mode` / exit | §3.8 | `IMPLEMENTED_NOT_CERTIFIED` | test-mode | No | `src/commands/safe_mode.sh` |
| `--migration-*` | §3.7 | `CERTIFIED_FIXTURE` | CI | Partial | migration tests |
| Legacy merge-in migration | Forbidden | N/A (not supported) | — | No | — |
| Ed25519 self-update | §8 | `CERTIFIED_FIXTURE` | CI | Yes | phase 24 |
| Named release + digest | §6 | `IMPLEMENTED_NOT_CERTIFIED` | catalog | No | `cert-0.24.6.4` |
| Adaptive workers / 8072 | §9 | `IMPLEMENTED_NOT_CERTIFIED` | — | Contract only | WEBSOCKET doc |
| ClamAV on `--init` | §11 | `IMPLEMENTED_NOT_CERTIFIED` | code | No | `soviez_clamav_init_baseline` |
| YARA native scanner | §11 | `CERTIFIED_FIXTURE` | CI | Partial | security gates |
| PG least privilege | §10 | `CERTIFIED_LIVE` | Lima disposable PG | Yes | POSTGRES_SECURITY_LIVE |
| Webmin never install | §2 | `CERTIFIED_FIXTURE` | CI | Yes | installer tests |
| Stage retention 14/60d | §12 | `CERTIFIED_FIXTURE` | CI | Yes | stage policy tests |
| Offline sovereignty | §2 | `CERTIFIED_FIXTURE` | CI | Yes | offline tests |
| Private Docker Hub pull | §5 future | `APPROVED_NOT_IMPLEMENTED` | — | Future | PRIVATE_IMAGE_DELIVERY |

---

## Approved but not implemented (summary)

- Private image short-lived pull authorization (future)

## Implemented but not live-certified (summary)

- Modular PATH `--init`, `--doctor`, `--releases`, `--release-status`, `--safe-mode`, `--tune --explain`
- ClamAV operational baseline on `--init`
- Full Odoo stack + WebSocket 101 on Lima
- `--tune` apply, Stage hard limits, connected self-update live verify
- `tests/run_all.sh` FAIL=0 on final 0.24.6.4 artifact

## Certified live (summary)

- PATH launcher, `--version`, `--list`, `--stage-list`, `--tune --dry-run`
- Dual wizard `--init` on Ubuntu 22.04/24.04 (delegates to modular when installed)
- PostgreSQL least-privilege matrix (disposable container)

## Public features withheld (lack certification)

- `--doctor`, `--release-status`, `--releases`, `--safe-mode`, `--tune --explain` as "available today"
- Modular `--init` live parity claims until Lima re-cert
- Full Production stack live acceptance without certification evidence

## Canonical ERP image (certification)

| Field | Value |
|-------|--------|
| Repository | `soviez/soviez-erp` |
| Digest | `sha256:ddee91810f0d22b7b78334e3404b8dc82f20200cce10a9f9656d9f2ff1111fab` |
| Named release | `cert-0.24.6.4` (certification channel) |
| `latest` as authority | **No** |
