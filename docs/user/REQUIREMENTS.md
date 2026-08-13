# Requirements

**Version:** `0.24.5.1-security-s5-corr1`

## Supported OS

| Item | Requirement |
|------|-------------|
| OS | Ubuntu **22.04** amd64, Ubuntu **24.04** amd64 |
| Architecture | **amd64** only (arm64 blocked by migration discovery gates) |
| Privileges | Root / sudo for install and most host operations |

## Capacity (guidance)

Exact sizing depends on workload. Practical baselines:

| Resource | Guidance |
|----------|----------|
| CPU | 4+ vCPU for Production |
| RAM | 8+ GiB Production; more if Stages run concurrently |
| Disk | SSD; plan headroom for images, backups, filestore, update candidates |
| Network | Public IPv4 for Production domain; outbound HTTPS for connected mode |

## DNS / domain

- A Production FQDN pointing to the server public IP (or Cloudflare AOP mode)
- Stage requires its own FQDN (`--stage-domain`)

## Ports (public)

| Port | Expectation |
|------|-------------|
| 22 | SSH (management) |
| 80 | HTTP / ACME / redirect |
| 443 | HTTPS (primary ERP edge) |

**Not public Production endpoints:** container Odoo **8069**, gevent/longpoll **8071/8072**, PostgreSQL **5432**. See [NETWORKING.md](NETWORKING.md).

## Docker

Docker is installed/configured by the Production wizard `--init` path. Modular operations assume a working Docker daemon.

## Connected vs offline preparation

| Mode | Prepare |
|------|---------|
| Connected | Outbound HTTPS to Soviez SaaS + Registry gateway |
| Offline | Signed offline trust package + offline update/Stage bundles on removable media |

## Explicitly NOT installed by Soviez.sh

```text
Soviez.sh NEVER installs Webmin or Virtualmin.
```

If already present, Soviez may **detect/classify** security posture. It does not blindly remove or reconfigure them. Port **10000** is not opened by Soviez.
