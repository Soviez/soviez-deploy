# Security Blueprint Alignment

**Blueprint path:** `docs/security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md`

## PASS-aligned controls

Ubuntu LTS, minimal host, least-privilege PostgreSQL, loopback Odoo, Nginx TLS, container hardening, no Docker socket, AppArmor, firewall, Fail2Ban, apt wait-or-fail, quarantine model, no chmod 777, no secret leakage, evidence-based acceptance, backup/restore verification (contract).

## Soviez-specific adaptations documented

| Generic Blueprint | Soviez |
|-------------------|--------|
| Fixed worker sizing | Automatic `--tune` sizing engine |
| Fixed evented topology | Adaptive workers=0 or multi-worker 8072 |
| Generic paths | `/opt/soviez/`, `/usr/local/bin/soviez.sh` |
| AIDE | Native Soviez FIM where equivalent |
| Generic Odoo image | Docker Hub named release + digest |

## Remaining conflicts

| Item | Status |
|------|--------|
| ClamAV mandatory on every `--init` | PARTIAL — on-demand policy; approved baseline converging |
| Full live Odoo stack certification | BLOCKED — ERP image availability |
| Live restore-test | IMPLEMENTED_NOT_CERTIFIED |
