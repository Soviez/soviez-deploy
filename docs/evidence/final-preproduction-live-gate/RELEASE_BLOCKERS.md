# RELEASE_BLOCKERS

1. FAIL: SOVIEZ_ROOT unbound in non-test live CLI (bare PATH crash)
2. FAIL: chmod -p in platform install (breaks --platform-install / self-update apply)
3. BLOCKED: Docker/Odoo listeners 8069/8072 and nginx websocket 101 in Lima
4. BLOCKED: Vercel deployment listing / unprotected preview verification
5. FAIL: prior full regression tests/run_all.sh exit 1 (FULL_REGRESSION.md)
6. WARN: printf mishandles version_cmp -1 on GNU printf during some verifies
