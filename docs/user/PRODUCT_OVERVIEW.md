# Product Overview

**Audience:** operators · **Platform build:** `0.24.6.3-platform-cli`  
**Contract:** [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md)

## What Soviez.sh is

Soviez.sh is the **sovereign host installer and operations plane** for **Soviez ERP** (Odoo 18–based enterprise ERP). It is a **CLI**, not a permanently running daemon. It installs and manages Production and Stage environments, TLS, Docker, PostgreSQL, Nginx, updates, backups, migration, and security controls on Ubuntu servers.

**Customer command:**

```bash
soviez.sh ...
```

Installed at `/usr/local/bin/soviez.sh`.

## Relationship to Soviez ERP

| Component | Role |
|-----------|------|
| Soviez ERP | Business application (Odoo 18 + Soviez addons), deployed from **Docker Hub** images by digest |
| Soviez.sh | Public PATH CLI for host prep, lifecycle, Stage, backup, restore, migration, security, tuning |
| Soviez SaaS | Entitlement resolver (Stripe is a commercial origin, not the authority); not required for ERP runtime |

ERP is **not** deployed by GitHub source checkout in normal customer flows.

## What it manages

- Ubuntu host hardening (`--init`): Docker, Nginx, Certbot, UFW, AppArmor, Fail2Ban, security updates, ClamAV/YARA baseline (per contract)
- Production ERP + PostgreSQL containers (private network, loopback backends)
- Stage environments with resource isolation and retention (14d default, 60d max)
- Named releases (`Sam0.x`) → immutable image digests; `latest` is not deployment authority
- Domains, TLS, Nginx edge (including adaptive WebSocket routing)
- Platform self-update (Ed25519 + SHA256) vs ERP product update (entitlement-gated)
- Backups / restores (quarantine for untrusted)
- Soviez-to-Soviez migration (`--migration-*` only; legacy merge-in interface not supported)

## Connected vs offline

- **Connected:** SaaS for activation, entitlements, release metadata, migration authorization.
- **Offline:** signed offline bundles; ERP, backup, restore, and diagnostics continue without SaaS.

## Production vs Stage

- **Production:** customer live ERP (one License → one Production slot).
- **Stage:** isolated non-production environments; failing Stage must not take down Production.

## Sovereignty invariants

```text
ERP runtime does not depend on continuous SaaS connectivity.
Technical Support expiry does not stop ERP, backup, or restore.
Stage entitlement expiry blocks new Stage mutations only.
No hidden telemetry or periodic phone-home.
Soviez.sh NEVER installs Webmin or Virtualmin.
```

## Security posture

Soviez is **security-hardened**, not "unhackable". See [SECURITY.md](SECURITY.md) and [../security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md](../security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md).

## Feature availability

See [IMPLEMENTATION_STATUS_MATRIX.md](../IMPLEMENTATION_STATUS_MATRIX.md) before claiming features like `--doctor` or `--release-status` are available today.
