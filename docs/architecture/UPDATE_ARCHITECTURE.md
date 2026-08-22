# Update architecture

See [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md) §7–8.

## ERP update

```bash
soviez.sh --update <production-id> --release Sam0.2
```

```text
platform self-update preflight
→ entitlement check (Product Updates)
→ named release → immutable digest
→ resource/storage preflight
→ backup / checkpoint
→ maintenance mode if required
→ pull + validate image
→ update target
→ DB / modules
→ HTTP + WebSocket validation
→ rollback if required
```

## Platform self-update

Separate from ERP update. Allowed when Technical Support expired. Ed25519 + SHA256 mandatory.

## Pre-update checks

DB compatibility, release compatibility, migration need, disk, resources, backup health, custom-addon risk, rollback viability.
