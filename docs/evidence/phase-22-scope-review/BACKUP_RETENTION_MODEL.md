# Backup Retention Model

Do **not** merge these concepts:

| Artifact | Origin | Phase 22 action |
|----------|--------|-----------------|
| Source pre-migration backup | Phase 16 | Retain |
| Phase 19 pinned rollback backup | Phase 19 | Remain pinned through archive verification |
| Phase 21 source rollback backup | Phase 21 | Retain |
| Destination post-cutover backup | Phase 21 | Retain + freshness gate |
| Phase 22 source archive | Phase 22 | Create + verify; retention clock starts after verified creation |
| Stage backups | Stage product | Unchanged retention rules |

## Policy fields (per artifact)

minimum retention · retention start · retention expiry · legal hold · owner hold · storage target · encryption · checksum · restore-test requirement · deletion authority · automatic deletion behavior

## Recommended defaults

- **No backup deletion in Phase 22**
- Source rollback backup pinned through archive verification
- Destination backup retained
- Archive retention starts only after verified archive creation
- Purge/delete policy belongs later
