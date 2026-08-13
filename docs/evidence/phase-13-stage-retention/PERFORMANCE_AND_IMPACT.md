# Performance and Impact
The daily scan is inventory-linear and performs local JSON/date/banner work. Destruction is per selected Stage, serialised by a local lock.

Final backup is intentionally required before deletion and is the dominant I/O cost. It is retained outside the Stage directory. No SaaS, entitlement, or network dependency is introduced.
