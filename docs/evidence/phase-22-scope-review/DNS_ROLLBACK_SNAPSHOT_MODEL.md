# DNS Rollback Snapshot Model

## Retain

- Prior source A/AAAA/CNAME
- TTL, authoritative nameservers, DNSSEC, CAA
- Source certificate fingerprint, source route reference
- Rollback operation evidence

## Phase 22 action

May mark snapshot:

```text
manual_recovery_only
```

after rollback-window closure.

**Must not delete** DNS rollback history in Phase 22.
