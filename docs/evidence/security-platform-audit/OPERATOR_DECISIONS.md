# Operator decisions required before implementation

| ID | Decision | Default recommendation |
|----|----------|------------------------|
| OD-SEC-01 | Authorize Security Gate S1 implementation after this audit | Yes — critical containment |
| OD-SEC-02 | PG app role redesign: new non-superuser vs ALTER existing | Prefer new role + migrate grants; maintenance window |
| OD-SEC-03 | Odoo publish: 127.0.0.1 bind vs private proxy network | 127.0.0.1:${port}:8069 for Nginx-on-host |
| OD-SEC-04 | CrowdSec vs keep Fail2Ban | Keep Fail2Ban for S2; CrowdSec optional |
| OD-SEC-05 | EDGE_MODE default (direct/cloudflare/cloudflare_aop) | direct; CF optional |
| OD-SEC-06 | Restrictive egress allowlist as Production default? | No — observable first |
| OD-SEC-07 | SSH password/root disable automation | Staged + verified only |
| OD-SEC-08 | Webmin: allowlist / VPN / accept public / ignore | Detect+report; owner chooses |
| OD-SEC-09 | Off-host backup mandatory for Production cert? | Recommend Yes |
| OD-SEC-10 | Phase 25 resume only after which gate? | After S6 PASS (or explicit residual-risk accept) |
| OD-SEC-11 | Dual installer ownership: migrate provision into soviez-sh? | Plan in S1 |
| OD-SEC-12 | Monitoring stack footprint (AIDE+YARA+auditd+Lynis) | Accept minimal stack |
