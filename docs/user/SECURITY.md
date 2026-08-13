# Security (Operator)

Soviez is **security-hardened and certified**, not "unhackable".

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
| PASS | No blocking findings |
| REVIEW | Operator judgment required |
| FAIL | Must not promote / must remediate |

## Commands

```bash
./dist/soviez.sh --security-status
./dist/soviez.sh --security-scan
./dist/soviez.sh --security-scan-db
./dist/soviez.sh --security-check
./dist/soviez.sh --security-harden
./dist/soviez.sh --security-report
./dist/soviez.sh --security-update-check
./dist/soviez.sh --security-backup-check
```

## Webmin / Virtualmin

```text
Soviez.sh NEVER installs Webmin or Virtualmin.
```

Detection/classification only. See `docs/security/WEBMIN_VIRTUALMIN.md`.

## Malware stack (honest)

**Implemented:** native DB scanner, FIM/integrity, targeted YARA, Fail2Ban, firewall/Nginx/SSH hardening, process/miner IOC observation.  
**Optional/supporting (not claimed installed by default):** auditd, Lynis, AIDE.  
**Not installed by default:** ClamAV, Wazuh, Falco, osquery, CrowdSec.
