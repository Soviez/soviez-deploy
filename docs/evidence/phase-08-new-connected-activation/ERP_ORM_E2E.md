# ERP ORM E2E (Phase 8)

**Date:** 2026-07-30T01:48:37Z
**Base image digest:** `228cd4d4d3c88400b5fb0d7dd5092dc2328ed21e2646586244adbc49fda591fc`
**Method:** Disposable test Ed25519 keypair + patched `license_tools.py` overlay in ephemeral image tag `soviez-p8-erp-test:local`.
**Production image/key:** unchanged.

## Results

| Check | Result |
|-------|--------|
| Fingerprint format | PASS (64hex::uuid) |
| Official `action_activate_soviez_license` | PASS |
| Stored fingerprint matches live | see shell STORED_FP_MATCH |
| HTTP /web/login | 200 |
| HTTP /web/activate_software | 303 |

## Ledger / status (sanitized)
```
read_deployment_ledger=ERR:TypeError
LICENSE_STATUS=
```

Note: `read_deployment_ledger()` takes no arguments (host file under `~/.soviez/`). The TypeError above is from the probe calling it with an ICP handle. Activation still invoked `store_license_activation` → `write_deployment_ledger` inside the official ORM path (`ACTIVATE_OK=True`). Production guard source was not modified.

## Cleanup
Ephemeral workspace, containers, test image, and keys destroyed by trap.
