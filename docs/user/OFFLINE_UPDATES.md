# Offline Updates

## Flow

```text
signed offline bundle
→ inspect / plan
→ import (quarantine/staging)
→ entitlement check (embedded)
→ backup
→ OCI/image import
→ DB/addon update on candidate
→ switch
→ result receipt export
```

## Commands

```bash
soviez.sh --offline-bundle-inspect PATH
soviez.sh --offline-bundle-plan PATH|ID
soviez.sh --offline-bundle-import PATH
soviez.sh --offline-update-apply PATH|ID
soviez.sh --offline-update-status OP
soviez.sh --offline-update-result-export OP
soviez.sh --offline-update-result-show FILE
soviez.sh --offline-trust-inspect
soviez.sh --offline-trust-import PATH
```

## Guarantees

- Signature verification required
- Exact License/Device/environment binding
- No network required for apply when bundle + trust are local
- Runtime independent from later SaaS reconciliation
