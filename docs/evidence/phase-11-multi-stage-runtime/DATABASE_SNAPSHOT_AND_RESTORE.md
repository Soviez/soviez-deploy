# DATABASE_SNAPSHOT_AND_RESTORE

| Requirement | Status |
|-------------|--------|
| Uses pg_dump custom format (prod path) | ✅ |
| Never copies live PG data dir | ✅ |
| Never mutates Production DB | ✅ |
| Stage DB restore isolated | ✅ |
| Live disposable Postgres E2E | ✅ `LIVE_POSTGRES_E2E.md` — PGDMP magic, row counts, FK, UUID rotation |
| Fixture path retained for unit/multi | ✅ `SOVIEZ_TEST_MODE` without `SOVIEZ_STAGE_USE_LIVE_PG` |

Prior PARTIAL note superseded by gap-closure PASS on 2026-07-30.
