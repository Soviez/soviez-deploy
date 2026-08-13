# Installation

**Version:** `0.24.5.3-registry-gateway`

## Installer surfaces

### A) Dual Production wizard (host + Production)

**Paths:** `Soviez ERP/soviez.sh` and `soviez-deploy/soviez.sh` (supported dual; keep byte-identical for APT-lock safety).

| Command | Effect |
|---------|--------|
| `--init` | Bootstrap host: apt packages, Docker, Nginx, Certbot, UFW baselines |
| `--new` | Provision Production ERP + PostgreSQL + Nginx site + TLS |

### B) Modular certified installer

**Path:** `soviez-sh/dist/soviez.sh`  
**Version:** `0.24.5.3-registry-gateway`  
**SHA256:** `68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460`

Provides Stage, update, backup/restore, migration, offline, security, SSL ops, operations engine.

## What Soviez installs/configures

- Docker Engine + Compose tooling as required by wizard
- Nginx reverse proxy on 80/443
- Certbot for Let's Encrypt (when domain validates)
- UFW baselines (22/80/443)
- PostgreSQL in Docker (not published publicly)
- Odoo/Soviez ERP container (loopback-published only)

## What Soviez does NOT install

```text
Soviez.sh NEVER installs Webmin or Virtualmin.
ClamAV, Wazuh, Falco, osquery, CrowdSec are not installed by default.
```

## Failure / retry

- Interrupted `--init` can be re-run; wizard is designed to resume missing pieces.
- APT locks: **wait-or-fail** — Soviez does **not** `killall -9 apt/dpkg`.
- After failure: check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) and [RECOVERY.md](RECOVERY.md).

## Verify artifact (modular)

```bash
sha256sum dist/soviez.sh
# expect: 68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460
```
