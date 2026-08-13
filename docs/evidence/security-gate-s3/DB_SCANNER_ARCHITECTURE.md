# DB Scanner Architecture
Modules: `db_scan.sh` (READ ONLY extract) → `classify_records.py` (never executes content) → evidence findings.
CLI: `--security-scan-db` / `soviez_cmd_security_scan_db` (Phase 24 `--security-scan` unchanged).
Rules: `share/security/detection/db_rules.json`. IOCs: `iocs.json` offline.
