# LEGACY_MIGRATION_TRANSFER_REVIEW.md

**Date:** 2026-08-02  
**Scope:** Legacy `soviez-deploy` / historical “migrate” naming vs Phase 19 peer streaming

## Findings

| Legacy concept | Reality | Phase 19 stance |
|----------------|---------|-----------------|
| `--migrate-in` / “merge-in” | Planned name historically; not a complete Soviez↔Soviez streamer | New transfer plane; do not revive legacy tar drop as primary |
| Filesystem path “migration” (`/etc` drop-zone → `/soviez`) | Host filesystem layout move | **Not** streaming migration |
| Legacy `--backup` tar | Real `pg_dump -Fc` + filestore; local/admin oriented | Reuse dump idea via Phase 16 only; ban legacy tar as migrate path |
| Domain change (`--change-domain` / `--formssl`) | Local SSL/domain admin | Owned by Phase 12/18 patterns; not transfer |
| SCP/rsync ad-hoc admin copies | Untyped, no resume registry, no pair binding | SSH **admin fallback only**; not default protocol |

## Explicit bans carried forward

- Plain FTP / anonymous file drop  
- TOFU SSH/mTLS without pair-pinned identity  
- SaaS relay of DB/filestore  
- Giant single-archive “upload to cloud then download” as primary design  

## Conclusion

Legacy deploy backup/transfer habits inform **dump format** reuse only. Phase 19 primary path is **application-level mTLS chunked transfer** bound to Phase 17 pair + Phase 18 readiness. See `TRANSFER_PROTOCOL_MODEL.md`.
