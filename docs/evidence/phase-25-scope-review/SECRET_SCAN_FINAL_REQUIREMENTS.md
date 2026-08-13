# Secret-scan final requirements

- Run authoritative `tools/secret_scan.sh all` (+ gitleaks if installed)
- Dist scan PASS
- Synthetic detection still green
- Historical: classify any findings; POTENTIALLY_LIVE/UNKNOWN blocks
- Exact allowlists only; no broad wildcards
