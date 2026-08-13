# Implementation gates S1–S6

## S1 Architecture & Critical Containment
PG least privilege; DB net isolation; Odoo public-port isolation; Docker net correctness; dangerous privilege checks; Odoo defaults; secure secrets.

## S2 Host & Edge
Firewall-safe orchestration; Nginx; Cloudflare modes; SSH staged; Fail2ban/CrowdSec OD; Webmin detect; SUID/systemd/cron audit.

## S3 Compromise Detection
DB persistence scanner; FIM; YARA; miner detection; evidence.

## S4 Quarantine & Recovery
Migration/restore quarantine; blocked egress; technical scan; incident evidence; ZATCA-safe RO.

## S5 Update, Backup & Network Safety
Update pre/post snapshots; Docker/firewall restart regression; PDF validation; off-host backup; OS update policy; disk cleanup.

## S6 Full Security Certification
All TEST-SEC; adversarial matrix; real runtime; reboot; idempotency; cleanup; security report.

Order: S1 → S2 → S3 → S4 → S5 → S6. Phase 25 Final Certification remains paused until S6 PASS (or owner OD to proceed with residual risk).
