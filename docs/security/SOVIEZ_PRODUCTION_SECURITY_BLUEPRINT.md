# Soviez Production Security Blueprint

**Based on:** Odoo Docker Production Server Security Blueprint v1.0  
**Adapted for:** Soviez.sh / Soviez ERP architecture  
**Authority:** [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md)

This document is the **Soviez-specific authoritative** security blueprint. The generic external Blueprint v1.0 remains an immutable reference; this file documents deliberate Soviez adaptations.

---

## 1. Host baseline

| Control | Soviez adaptation |
|---------|-------------------|
| Ubuntu LTS only | 22.04 / 24.04 amd64 validated |
| Minimal host | No Webmin/Virtualmin; Soviez manages Nginx/Docker |
| Unattended security updates | Enabled; no uncontrolled Production reboot; no do-release-upgrade |
| apt safety | Wait-or-fail; never `killall apt` / delete lockfiles |

---

## 2. Network & ingress

| Control | Soviez rule |
|---------|-------------|
| Firewall | UFW default deny; public 22, 80, 443 |
| PostgreSQL | Never public `:5432` |
| Odoo | Loopback `127.0.0.1:8069` (HTTP); `127.0.0.1:8072` when multi-worker |
| Nginx | Sole public TLS ingress; `nginx -t` before reload |
| Production outbound | Generally allowed (ZATCA, SMTP, APIs) |
| Quarantine | External egress denied |

---

## 3. Container hardening

- No `--privileged`
- No Docker socket in Odoo/PostgreSQL containers
- No host networking
- `NoNewPrivileges`, reduced capabilities
- Explicit non-root runtime users where compatible
- Read-only source/addons; writable paths minimized
- Private backend Docker networks
- No `chmod 777`

---

## 4. PostgreSQL least privilege

| Role | Purpose |
|------|---------|
| `soviez_admin` | Bootstrap/migrations only |
| `soviez_app` | Odoo runtime: NOSUPERUSER, NOCREATEROLE, NOCREATEDB, NOREPLICATION, NOBYPASSRLS |

No dangerous predefined roles for the app user. Odoo administrator compromise must not imply PG superuser or host root.

---

## 5. Odoo runtime topology (adaptive)

Generic Blueprint may assume fixed worker counts. **Soviez uses automatic sizing:**

- Small hosts: `workers=0` fallback (single process)
- Larger hosts: multi-worker + gevent on `8072`
- Nginx adapts routing; must not proxy to non-listening `8072`

---

## 6. Malware & integrity

| Layer | Soviez |
|-------|--------|
| ClamAV | Baseline AV (daemon + signatures + scheduled scan); not "installed = operational" |
| YARA | Full complementary scanner (addons, webshells, IOCs) — not replaced by ClamAV |
| Native scanners | DB, technical-model, process, network, IOC, filesystem integrity |
| Response | Detect → evidence → quarantine → review; **no auto-delete** |
| AIDE | Not mandatory where Soviez native FIM equivalent exists |

Do not scan PostgreSQL PGDATA in realtime with ClamAV on-access.

---

## 7. AppArmor & Fail2Ban

- AppArmor: must remain **enabled**; disabling is not a supported troubleshooting step
- Fail2Ban: SSH, Odoo login abuse, Nginx scanner abuse — verified regex only

---

## 8. Backup, restore, acceptance

- Backups: PostgreSQL + filestore + metadata + checksums
- Untrusted restore: quarantine pipeline before promotion
- Production acceptance: evidence-based gates; **Needs Action** on failure

---

## 9. Release & supply chain

- ERP from Docker Hub `repository@sha256:digest`
- Named releases immutable (`Sam0.x`)
- Platform self-update: Ed25519 + SHA256 mandatory
- Future private images: short-lived pull auth; no permanent registry creds on host

---

## 10. Blueprint alignment status

| Generic Blueprint principle | Soviez status |
|----------------------------|---------------|
| Supported Ubuntu LTS | PASS |
| Minimal host | PASS |
| Least privilege DB | PASS (live matrix) |
| Loopback Odoo | PASS |
| Nginx TLS | PASS (`--init`) |
| Container hardening | PASS (design); live Odoo pending image |
| No Docker socket | PASS |
| AppArmor | PASS |
| Firewall | PASS |
| Fail2Ban | PASS |
| ClamAV | PARTIAL (on-demand install policy) |
| Backup verification | PARTIAL (live restore-test pending) |
| Quarantine | PASS (design); live pending |
| No chmod 777 | PASS |
| No secret leakage | PASS |
| Evidence-based acceptance | PASS (contract) |

**Remaining conflicts:** ClamAV not yet mandatory on every `--init` path; full stack live certification blocked on ERP image availability.
