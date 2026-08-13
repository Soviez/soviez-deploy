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
./dist/soviez.sh --offline-bundle-inspect PATH
./dist/soviez.sh --offline-bundle-plan PATH|ID
./dist/soviez.sh --offline-bundle-import PATH
./dist/soviez.sh --offline-update-apply PATH|ID
./dist/soviez.sh --offline-update-status OP
./dist/soviez.sh --offline-update-result-export OP
./dist/soviez.sh --offline-update-result-show FILE
./dist/soviez.sh --offline-trust-inspect
./dist/soviez.sh --offline-trust-import PATH
```

## Guarantees

- Signature verification required
- Exact License/Device/environment binding
- No network required for apply when bundle + trust are local
- Runtime independent from later SaaS reconciliation
