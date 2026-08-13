# State Machines

## Update (simplified)

```mermaid
stateDiagram-v2
  [*] --> Precheck
  Precheck --> Backup
  Backup --> Candidate
  Candidate --> Validate
  Validate --> Switch
  Switch --> Complete
  Validate --> Rollback
  Switch --> Rollback
  Rollback --> [*]
  Complete --> [*]
```

## Quarantine

```text
CREATED → SCANNING → REVIEW|FAILED|APPROVED_FOR_STAGE → APPROVED_FOR_PRODUCTION
                 ↘ REJECTED
```

## Stage retention

```text
created_at immutable → active countdown → Needs Action → final backup → Safe Shield delete
```

## Migration

Discovery → Pair → Readiness → Domain/TLS → Transfer → Auth/Rebind → Cutover → Stabilize → Archive (no auto purge)
