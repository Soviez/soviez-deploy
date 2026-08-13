# Image Ownership Model

Managed Soviez ERP images must carry labels:
- `com.soviez.managed`
- `com.soviez.product=erp`
- `com.soviez.release-id`
- `com.soviez.image-digest` (when present)

Missing/ambiguous labels → classification `ownership_ambiguous` → **not deleted**.
Unlabeled third-party images are out of scope for automatic cleanup.
