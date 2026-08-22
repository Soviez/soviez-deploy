# Initialization (`--init`)

**Approved contract:** [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md) §4

## Purpose

Prepare and harden the server for Soviez:

- OS validation (Ubuntu 22.04/24.04 LTS)
- Package/security update preflight (apt wait-or-fail)
- Docker Engine
- Soviez platform installation and filesystem layout
- Docker networks
- Nginx
- Firewall (default deny; 22/80/443 public)
- AppArmor validation
- Fail2Ban
- Unattended security updates
- ClamAV + YARA/native security integration (baseline)
- System services and security validation
- Idempotent re-run

**Must never:** install Webmin or Virtualmin.

## Syntax

```bash
sudo soviez.sh --init
```

Use the `soviez.sh` on PATH (`/usr/local/bin/soviez.sh`).

## Implementation status

| Path | Status |
|------|--------|
| Dual Production wizard `--init` | **CERTIFIED_LIVE** (Ubuntu 22.04/24.04) |
| Modular PATH CLI `--init` | **APPROVED_NOT_IMPLEMENTED** (convergence in progress) |

During convergence, host bootstrap may route through the dual wizard compatibility layer after public bootstrap install. See [IMPLEMENTATION_STATUS_MATRIX.md](../IMPLEMENTATION_STATUS_MATRIX.md).

## Prerequisites

- Root
- Ubuntu 22.04 or 24.04 amd64
- Network for package download (connected bootstrap)

## Effects

Creates/updates host packages and services required for Production. Does **not** create a tenant by itself.

## What it does NOT do

- Does not install Webmin/Virtualmin
- Does not open 8069/8071/8072/5432 publicly
- Does not kill apt/dpkg or delete lockfiles

## Resume

Re-run `--init` if interrupted. Missing components are completed idempotently where implemented.
