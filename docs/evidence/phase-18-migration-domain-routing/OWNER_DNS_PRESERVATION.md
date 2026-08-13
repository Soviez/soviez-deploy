# OWNER_DNS_PRESERVATION

Abort preserves owner DNS marker (`owner_dns_marker.txt` in tests).

Installer prints exact records for owner-managed cleanup; does not auto-delete owner DNS unless a Phase 18 provider adapter created the exact record (mock deletes only mock fixture records).
