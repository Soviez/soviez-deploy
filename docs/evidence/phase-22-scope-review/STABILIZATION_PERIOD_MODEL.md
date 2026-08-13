# Stabilization Period Model

## Recommended model

```text
Immediate rollback window: 30 minutes
Stabilization observation: configurable, recommended 24 hours
Archive eligibility: after stabilization PASS and owner confirmation
```

Do **not** archive immediately when the 30-minute window expires.

## Owner duration options (OPEN)

| Option | Use |
|--------|-----|
| 6 hours | Aggressive; higher residual risk |
| 12 hours | Moderate |
| **24 hours** | **Recommended default** |
| 48 hours | Conservative / high-change environments |
| custom | Owner-defined with documented rationale |

## What stabilization observes

Aggregate health over the period (see DESTINATION_SUSTAINED_HEALTH_MODEL.md).  
Eligibility becomes true only when observation window **and** evidence gates pass; closure still needs owner confirmation.
