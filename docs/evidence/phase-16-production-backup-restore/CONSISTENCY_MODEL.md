# Consistency model
Full snapshot: `pg_dump -Fc` + filestore archive under ops lock. Not WAL/PITR.
Never copy live PG data directory; never share writable filestore with restore candidate.
See `docs/dev/BACKUP_CONSISTENCY_PROTOCOL.md`.
