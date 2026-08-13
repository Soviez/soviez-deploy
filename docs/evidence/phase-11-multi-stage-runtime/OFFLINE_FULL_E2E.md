# OFFLINE_FULL_E2E

**Date:** 2026-07-30  
**Result:** **PASS**

## Flow exercised

```text
--stage --offline-request
→ disposable signed package (issue_offline_package.mjs)
→ --stage --offline-import <package>
→ binding verify
→ tooling digest pin
→ helper verify + local ledger consume
→ Stage create (SOVIEZ_STAGE_BLOCK_SAAS=1)
→ neutralization + origin certificate
→ completed local inventory
```

No SaaS base URL on target (`SOVIEZ_SAAS_BASE_URL` / `SOVIEZ_API_BASE_URL` unset; `SOVIEZ_STAGE_BLOCK_SAAS=1`).

## Commands

```bash
bash tests/integration/test_stage_offline_full_e2e.sh
```

## Proven

| Case | Result |
|------|--------|
| Request export includes nonce/protocol/bindings | PASS |
| Package has no private keys | PASS |
| Import → certified Stage | PASS |
| Ledger replay denied | PASS |
| Wrong Production fingerprint denied | PASS |
| Expired `start_before` denied | PASS |

## CLI

- `soviez.sh --stage --offline-request`
- `soviez.sh --stage --offline-import <package-path>`
