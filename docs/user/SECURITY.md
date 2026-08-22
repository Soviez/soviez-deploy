# Security (Operator)

Soviez is **security-hardened**, not "unhackable".

**Blueprint:** [../security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md](../SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md)

## Platform composition (S1–S6)

| Gate | Focus |
|------|-------|
| S1 | PostgreSQL least privilege, private Odoo binding, Docker containment |
| S2 | Host/edge: firewall, Nginx, SSH, Fail2Ban, Webmin detect |
| S3 | Compromise detection (DB/host/YARA/process) |
| S4 | Migration/restore quarantine |
| S5 | Update/backup/network/PDF safety + apt wait-or-fail |
| S6 | Integrated certification |

## Scanner statuses

| Status | Meaning |
|--------|---------|
| PASS | Operational validation passed |
| REVIEW | Operator judgment required |
| FAIL | Must not promote / must remediate |

`--security-status` reports **operational state**, not merely installed packages.

## Commands

```bash
soviez.sh --security-status
soviez.sh --security-scan
soviez.sh --security-scan-db
soviez.sh --security-check
soviez.sh --security-harden
soviez.sh --security-report
soviez.sh --security-update-check
soviez.sh --security-backup-check
```

## Webmin / Virtualmin

```text
Soviez.sh NEVER installs Webmin or Virtualmin.
```

Detection/audit only. See `docs/security/WEBMIN_VIRTUALMIN.md`.

## Malware protection (ClamAV + YARA)

| Layer | Role |
|-------|------|
| **ClamAV** | Intended security baseline: daemon, signatures, scheduled scan, filestore protection where supported. Package install alone ≠ operational. |
| **YARA** | Full complementary scanner (addons, Python, webshells, IOCs) — **not** replaced by ClamAV |
| **Native scanners** | DB, technical-model, process, network, IOC, filesystem integrity |

**Response policy:** detect → preserve evidence → quarantine → classify. **Never** auto-delete suspicious business files or signing keys.

Do not scan PostgreSQL PGDATA with ClamAV realtime on-access.

**Current implementation:** ClamAV may be installed on-demand via security harden paths; full `--init` baseline integration is approved and converging — see [IMPLEMENTATION_STATUS_MATRIX.md](../IMPLEMENTATION_STATUS_MATRIX.md).

## AppArmor

Must remain **enabled**. Disabling AppArmor is not a supported troubleshooting step.

## PostgreSQL boundary

Odoo runs as least-privilege `soviez_app`. Compromise of an Odoo admin account must **not** automatically grant PostgreSQL superuser, host root, or Docker control.

## Optional third-party tools

auditd, Lynis, AIDE may be used where equivalent native controls exist. AIDE is not mandatory when Soviez native FIM is in place.

Not part of default Soviez baseline: Wazuh, Falco, osquery, CrowdSec.
