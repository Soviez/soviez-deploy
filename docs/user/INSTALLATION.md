# Installation

**Version:** `0.24.6.1-platform-cli`

## Canonical customer command

```bash
soviez.sh --help
soviez.sh --version
soviez.sh --list
```

Preferred install location:

```text
/usr/local/bin/soviez.sh   → stable launcher
/opt/soviez/platform/current/soviez.sh   → versioned platform payload
```

Works from any directory (including `/tmp`). Customers must not rely on repository paths such as `soviez.sh`.

## Bootstrap

```bash
curl -sSL https://soviez.sh | sudo bash
```

Public bootstrap installs the modular platform payload and PATH launcher. It does **not** leave the legacy unsigned wizard as the public runtime.

## Modular platform artifact

**Path (after install):** `/opt/soviez/platform/current/soviez.sh`  
**Version:** `0.24.6.1-platform-cli`  
**Build SHA256 (dist):** see `dist/soviez.sh.sha256` in the deploy repository after assemble.

Provides Stage, update, backup/restore, migration, offline, security, SSL, tuning, and operations.

## What Soviez installs/configures

- Docker Engine + Compose tooling as required
- Nginx reverse proxy on 80/443
- Certbot for Let's Encrypt (when domain validates)
- Firewall baselines (22/80/443 public)
- PostgreSQL in Docker (not published publicly)
- Odoo/Soviez ERP container (loopback-published only: 8069 HTTP, 8072 evented when multi-worker)
- Optional ClamAV packages when security harden/auto-install is enabled

## What Soviez does NOT install

```text
Soviez.sh NEVER installs Webmin or Virtualmin.
```

## Platform self-update vs ERP update

| Kind | Blocked by Technical Support expiry? |
|------|--------------------------------------|
| Soviez.sh platform / security / compatibility self-update | **No** |
| ERP product/image update | **Yes** (entitlement-gated) |

## Failure / retry

- APT locks: **wait-or-fail** — Soviez does **not** `killall` apt/dpkg or delete lockfiles.
- After failure: check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) and [RECOVERY.md](RECOVERY.md).

## Verify installed CLI

```bash
command -v soviez.sh
soviez.sh --version
```
