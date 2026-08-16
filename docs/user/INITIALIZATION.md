# Initialization (`--init`)

**Surface:** Dual Production wizard only (`Soviez ERP/soviez.sh` / `soviez-deploy/soviez.sh`).  
**Not a modular `soviez-sh` CLI flag.**

## Purpose

Bootstrap the Ubuntu host so Production can be created:

- Package repositories / apt updates (wait-or-fail on locks)
- Docker
- Nginx
- Certbot
- UFW allow 22/80/443
- Supporting utilities

## Syntax

```bash
sudo soviez.sh --init
```

## Prerequisites

- Root
- Ubuntu 22.04 or 24.04 amd64
- Network for package download (connected bootstrap)

## Effects

Creates/updates host packages and services required by Production. Does **not** create a tenant by itself.

## What it does NOT do

- Does not install Webmin/Virtualmin
- Does not open 8069/5432 publicly
- Does not kill apt/dpkg processes to clear locks

## Resume

Re-run `--init` if interrupted. Missing components are completed idempotently where implemented.
