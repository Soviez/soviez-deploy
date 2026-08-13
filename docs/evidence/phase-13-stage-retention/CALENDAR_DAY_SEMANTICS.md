# Calendar-Day Semantics
Creation timestamps persist in UTC. Deadlines are calculated by adding calendar dates in `SOVIEZ_RETENTION_HOST_TZ` and resolving at 23:59:59 local time, then persisted in UTC.

The daily countdown compares host-timezone dates, not elapsed 24-hour intervals. Unit coverage verifies 14/60-day dates, leap-year crossing, year boundary, and 14/7/1/0/overdue countdown states.
