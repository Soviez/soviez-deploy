# Stage backup live DB closure
`soviez_backup_stage_live_backup` attempts live `pg_dump` when PG available (integration asserts), closing Stage live-DB fixture debt.
Wired from `src/stage/lifecycle.sh`.
