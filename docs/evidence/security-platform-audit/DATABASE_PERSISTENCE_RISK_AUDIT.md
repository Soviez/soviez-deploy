# Database technical persistence risk

Current capability: **ABSENT** as a read-only security scanner for:
- ir.actions.server, ir.config_parameter, ir.ui.view, ir.cron, base.automation
- res.users/groups, ir.module.module
- Pattern detection: COPY PROGRAM, os.system, subprocess, eval/exec, curl/wget, reverse shells, xmrig, stratum, encoded payloads

Phase 22+ quarantine markers ≠ DB IOC scan.

Future: detection-first, read-only, no auto-delete.
