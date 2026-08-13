# Product Overview

**Audience:** operators · **Version:** `0.24.5.3-registry-gateway`

## What Soviez.sh is

Soviez.sh is the **sovereign host installer and operations plane** for **Soviez ERP** (Odoo 18–based enterprise ERP). It installs and manages Production and Stage environments, TLS, Docker, PostgreSQL, Nginx, updates, backups, migration, and security controls on Ubuntu servers.

## Relationship to Soviez ERP

| Component | Role |
|-----------|------|
| Soviez ERP | Business application (Odoo 18 foundation + Soviez addons) |
| Soviez.sh modular (`dist/soviez.sh`) | Certified operations CLI |
| Dual Production wizard (`Soviez ERP/soviez.sh` ≡ `soviez-deploy/soviez.sh`) | Host bootstrap (`--init`) and Production provision (`--new`) |
| Soviez SaaS | Entitlements, Registry tickets, offline bundle issuance, migration authorization |

## What it manages

- Ubuntu host packages (via wizard `--init`): Docker, Nginx, Certbot, UFW baselines
- Production ERP + PostgreSQL containers
- Stage environments (commercially entitled)
- Domains, TLS, Nginx edge
- Connected and offline updates
- Backups / restores (with quarantine for untrusted)
- Soviez-to-Soviez migration
- Security Platform (S1–S6 certified)

## Connected vs offline

- **Connected:** SaaS for activation, entitlements, Registry pulls, migration authorization.
- **Offline:** signed offline packages/bundles; ERP continues without SaaS.

## Production vs Stage

- **Production:** customer live ERP (one License → one Production slot).
- **Stage:** disposable non-production environments with retention (default 14 days, max 60 from original creation).

## Sovereignty invariants (operator-facing)

```text
ERP runtime does not depend on continuous SaaS connectivity.
Support expiry does not stop ERP.
Stage entitlement expiry does not stop/delete already-existing Stages.
LOCAL_ONLY backup = backup available, NOT disaster recovery.
Soviez.sh NEVER installs Webmin or Virtualmin.
Source purge is never automatic.
```

## Security posture

Soviez is **security-hardened and certified**, not "unhackable". See [SECURITY.md](SECURITY.md).

## Release note

Engineering certification is complete. **Public release / publish / production rollout remain NOT AUTHORIZED** until separate owner authorization.
