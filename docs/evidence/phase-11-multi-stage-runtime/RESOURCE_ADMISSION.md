# RESOURCE_ADMISSION

| Rule | Result |
|------|--------|
| Commercial limit | `unlimited` in admission JSON |
| Disk formula | `(db+fs)*2.5 + 2GiB` |
| Memory floor | MemAvailable ≥ 1GiB |
| Codes | `INSUFFICIENT_DISK`, `INSUFFICIENT_MEMORY`, `RESOURCE_ADMISSION_FAILED` |
| Force flag | `SOVIEZ_STAGE_ADMISSION_FORCE=1` for non-TTY warnings |

Certified in unit + integration (force in integration).
