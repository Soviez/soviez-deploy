# Migration Rollback Window Closure Protocol

Eligibility = automatic; commit requires explicit owner confirmation phrase:

```text
CLOSE ROLLBACK WINDOW <cutover-id>
```

After commit: `automatic_rollback_allowed=false`; DNS snapshot `manual_recovery_only`; source retained; no deletion; no runtime stop yet.
