# Secret Scan CI

Canonical gate: `tools/secret_scan.sh` (also `tests/security/run_phase24_security.sh`).

Tool selection:
- **Authoritative on this host:** embedded pattern + entropy scanner (always available, local-first, no SaaS)
- **Preferred when installed:** Gitleaks (`gitleaks detect`) with `.gitleaks.toml` exact allowlists
- TruffleHog/detect-secrets not required

Coverage: `src/`, `dist/soviez.sh`, `tests/`, critical docs, build scripts.
Exclusions: exact synthetic fixture paths under `tests/security/fixtures/secrets/` and documented known disposable-key test generators.
Git history: scanned when commits exist; this repo currently has zero commits → N/A with tree scan authoritative.
