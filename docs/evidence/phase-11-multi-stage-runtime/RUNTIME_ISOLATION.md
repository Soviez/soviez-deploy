# RUNTIME_ISOLATION

| Resource | Isolation |
|----------|-----------|
| Docker network | **Dedicated** `soviez-net-stage-<id>` (D060) |
| Container | `soviez-stage-<id>` |
| MAC | Unique LAA |
| DB filter | `^stage_<id>$` |
| Labels | `soviez.role=stage` |

Legacy shared `soviez-net-stage` not used for new Stages.
