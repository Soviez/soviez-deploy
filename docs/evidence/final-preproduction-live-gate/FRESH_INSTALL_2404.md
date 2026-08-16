# FRESH_INSTALL_2404

- captured_utc: 2026-08-16T16:20:38Z
- host: lima soviez-u2404 (Ubuntu 24.04.4 LTS Noble)
- method: same staging bootstrap as 2204
- artifact_sha256: dc16a4cde22e2e6142706b0e5937237028931ca1c3e352b356a22bfd966e051b
- launcher  → PASS
- bare PATH invocation → FAIL ( unbound)
- with : version/list/stage-list/tune --dry-run → PASS
- Docker Engine in Lima → BLOCKED (not installed; )
- listeners 8069/8072 / nginx websocket 101 → BLOCKED (no Docker/Odoo stack)
