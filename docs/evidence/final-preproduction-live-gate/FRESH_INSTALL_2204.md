# FRESH_INSTALL_2204

- captured_utc: 2026-08-16T16:20:38Z
- host: lima soviez-u2204 (Ubuntu 22.04.5 LTS Jammy)
- method: customer bootstrap 
- artifact_sha256: dc16a4cde22e2e6142706b0e5937237028931ca1c3e352b356a22bfd966e051b
- launcher:  → PASS
- payload:  mode 755 root:root → PASS
-  →  → PASS
- bare  from /tmp → FAIL ( at ssl paths init; product defect)
- with :  /  /  /  → PASS
- full Odoo/Postgres bootstrap → BLOCKED (not attempted; Docker Engine absent in VM)
