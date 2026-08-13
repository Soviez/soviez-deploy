# Multi-Stage Retention Matrix
| Stage | Lifetime | Verified outcome |
|---|---:|---|
| A | 14 then 30 days | Safe Shield failure preserves it; partial deletion recovers |
| B | 30 then 60 days | Due deletion tombstones B; sibling remains |
| C | 60 days | Failure reattaches and completes independently |
| D | 14 days | Scheduler/reboot scan completes deletion |

Integration coverage confirms deleting one Stage preserves siblings and Production fixture data.
