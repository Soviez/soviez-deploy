# Backup Scheduler Protocol (Phase 16)

## Default
Daily Full backup at **02:00 server-local** timezone (`hour_local=2`, `minute_local=0`).

## Schedule object
Fields include: `schedule_id`, `production_id`, `enabled`, `cadence=daily`, `hour_local`, `minute_local`, `timezone`, `destination_profile`, `backup_type=full`, `resource_profile`, `created_at`.

Default id pattern: `sched-<production-id>-daily`.

## Behavior
- Local schedules only; no SaaS cron / phone-home
- Due schedules enqueue/run `production_backup` through local ops engine subject to conflict locks (one Production backup conflict class)
- Failures leave Needs Action / retryable op state — do not silently skip forever without status

## CLI
`--backup-schedule-add <production-id> [--destination PROFILE]`  
`--backup-schedule-list`
