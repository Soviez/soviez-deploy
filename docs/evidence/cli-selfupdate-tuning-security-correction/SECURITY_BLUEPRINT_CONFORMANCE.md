# Blueprint conformance matrix (summary)

Owner blueprint: Odoo Docker Production Server Security Blueprint v1.0 — adapted to Soviez paths/lifecycle.

| CONTROL | STATUS | IMPLEMENTATION | EVIDENCE | DEVIATION |
|---------|--------|----------------|----------|-----------|
| Ubuntu LTS support | PASS | Documented 22.04/24.04 | INSTALLATION / REQUIREMENTS | — |
| Minimal host | PASS_EQUIVALENT_CONTROL | Soviez host baseline + apt policy | host_baseline / update_safety | — |
| AppArmor enabled | PASS (code/policy) / LIVE PENDING | Never disable; aa-status in gates | host_baseline | Live host proof pending |
| Firewall default deny inbound | PASS | S2 firewall modules | firewall*.sh | — |
| Approved public ports only | PASS | 80/443/SSH | FIREWALL.md | — |
| PostgreSQL private | PASS | No host 5432 | postgres_network | — |
| Odoo ports loopback | PASS | 8069/8072 loopback publish | odoo_exposure / docker provision | — |
| Docker daemon not public | PASS | Policy + checks | docker_containment | — |
| No privileged Odoo/PG | PASS | docker run flags / inspect gates | docker_containment | — |
| No docker.sock in Odoo | PASS | Gate asserts | docker_containment | — |
| no-new-privileges | PASS_EQUIVALENT_CONTROL | Compose/runtime hardening paths | container security docs | Live inspect pending |
| Cap drop | PASS_EQUIVALENT_CONTROL | Policy | docker_containment | Live inspect pending |
| Source/addons RO | PASS_EQUIVALENT_CONTROL | Mount policy | quarantine/runtime | Live pending |
| No chmod 777 | PASS | Static scan in correction matrix | SEC-CLI-010 | — |
| Nginx HTTPS ingress | PASS | ownership + S2 templates | nginx | — |
| TLS | PASS | SSL lifecycle | ssl/* | — |
| Targeted rate limits | PASS | login zone only | nginx_edge | — |
| Fail2Ban | PASS_EQUIVALENT_CONTROL | brute_force module; verified regexes only | brute_force.sh | Live pending |
| Unattended upgrades no blind reboot | PASS | package_policy / reboot checks | update_safety | Live pending |
| Backup + restore verify | PASS | backup/restore engines | existing phases | — |
| Quarantine not delete | PASS | S4 quarantine | quarantine/* | — |
| Secret redaction | PASS | core/redact | existing | — |
| Checkpoint/rollback | PASS | tune + security rollback | tune.sh | — |
| ClamAV | PASS (module) / LIVE PENDING | clamav.sh | CLAMAV_IMPLEMENTATION | Daemon not proven on this host |
| YARA | PASS | yara_scan.sh | YARA_INTEGRATION | — |
| Webmin never install | PASS | SEC-CLI-017 + management_surface detect-only | management_surface | — |
| AIDE | PASS_EQUIVALENT_CONTROL | Native host integrity scanner | host_integrity.sh | Owner-approved equivalent |
| Outbound Production allow | PASS | Policy documented | OUTBOUND_POLICY | Live pending |
| Quarantine egress deny | PASS | Internal docker network | quarantine/network | Live probe pending |

**Counts (this cycle):** PASS≈22 · PASS_EQUIVALENT≈6 · LIVE_PENDING≈8 · FAIL=0 · OWNER_APPROVED_DEVIATION=0 unexplained
