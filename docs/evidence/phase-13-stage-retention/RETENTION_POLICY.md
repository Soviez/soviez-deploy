# Retention Policy
- Default lifetime: 14 calendar days from immutable original Stage creation.
- Absolute maximum: 60 calendar days from that same timestamp.
- `--days N` requests total lifetime `N`; extensions are monotonic and never reset creation.
- Retention is local-only and independent of Stage License/ticket entitlement.
- Ambiguity/failure prevents deletion and requires action or recovery.
