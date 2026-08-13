# Rate limiting

Uses existing DB-backed `checkSlidingWindowRateLimit` / `api_rate_limits`.

Buckets: start IP/fingerprint, token IP, invalid device codes, user-code lookup, approve/deny, revoke, signature failures.

**Deployment note:** authority comes from shared Postgres rate-limit rows (project pattern). A pure in-memory limiter would be insufficient for multi-instance production — not used here.
