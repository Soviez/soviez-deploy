# Target security architecture (14 layers refined)

Layer 1 Host — AIDE/auditd/Lynis; no auto-destructive clean
Layer 2 SSH/Admin — staged keys; Fail2Ban; Webmin detect
Layer 3 Firewall/Edge — UFW + DOCKER-USER; Nginx; EDGE_MODE
Layer 4 Docker isolation — no privileged/sock/link; private nets; loopback publish
Layer 5 PostgreSQL least privilege — NOSUPERUSER app role; no server program/file roles; no host :5432
Layer 6 Odoo production defaults — list_db=False; proxy_mode; strong secrets; no public 8069
Layer 7 Secrets — strong RNG; reduce inspect surface; rotation
Layer 8 Backup/restore — encrypt; off-host; restore-test
Layer 9 Migration quarantine — blocked egress; scan; acceptance
Layer 10 DB persistence detection — read-only technical IOC
Layer 11 FIM/host monitoring — baseline drift
Layer 12 Update safety — pre/post network + exposure gates (beyond containers Up)
Layer 13 Security evidence — bounded logs; no secrets
Layer 14 Incident response — evidence mode; migrate/quarantine over blind wipe

CLI concepts (names consistent with Phase 24):
`--security-status` (exists)
`--security-scan` (exists; extend)
`--security-check` (read-only posture)
`--security-harden` (mutable Gate S1/S2)
`--security-report`
`--security-incident`
