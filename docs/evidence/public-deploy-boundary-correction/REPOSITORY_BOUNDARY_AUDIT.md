# REPOSITORY_BOUNDARY_AUDIT

## Policy

```text
Soviez/soviez-deploy = CLIENT-SIDE DEPLOYMENT REPOSITORY ONLY
```

Inclusion rule: does this file need to exist on the customer side (or be available to the customer/operator) for Soviez.sh supported lifecycle operations?

## Top-level classification (post-policy)

| Path | Class | Notes |
|------|-------|-------|
| `soviez.sh` | GENERATED_CLIENT_ARTIFACT | Dual wizard |
| `VERSION` | CLIENT_REQUIRED | |
| `README.md` | PUBLIC_DOC | Policy updated |
| `PRODUCT_CONSTITUTION.md` | PUBLIC_DOC | Boundary clause added |
| `PROJECT_STATE.md` | PUBLIC_DOC | |
| `.gitignore` / `.gitleaks.toml` | CLIENT_REQUIRED | Hygiene retained |
| `dist/` | GENERATED_CLIENT_ARTIFACT | Client only |
| `src/` | CLIENT_REQUIRED | Includes `src/registry/` client |
| `build/` `tools/` `schemas/` `share/` | CLIENT_REQUIRED | |
| `scripts/` `tooling/` | CLIENT_OPTIONAL | |
| `tests/` | PUBLIC_TEST | |
| `docs/` | PUBLIC_DOC (+ HISTORICAL_EVIDENCE under evidence/) | |
| `services/registry-gateway/` | INTERNAL_SERVICE | **REMOVED** from public main |

## Pre-correction counts (tracked)

See `PUBLIC_FILE_CLASSIFICATION.md`.

- CLIENT_REQUIRED: 501
- CLIENT_OPTIONAL: 8
- PUBLIC_DOC: 367
- PUBLIC_TEST: 245
- GENERATED_CLIENT_ARTIFACT: 3
- HISTORICAL_EVIDENCE: 1913
- INTERNAL_SERVICE: 40
- INTERNAL_OPERATIONS: 0 as separate tracked class (Gateway ops docs lived inside INTERNAL_SERVICE package; 7 files under `docs/`)
- UNCLEAR: **0**

## Other internal-only scan

Searched for SaaS server code, issuer private keys, Hub PATs, private CI deploy scripts, monitoring configs, incident tooling beyond Gateway.

Result: **no additional INTERNAL_SERVICE trees** beyond `services/registry-gateway/`. Historical evidence packs retain descriptive references (classified HISTORICAL_EVIDENCE; superseded note added).

PUBLIC_BOUNDARY_AUDIT = PASS
UNKNOWN_FILES = 0
