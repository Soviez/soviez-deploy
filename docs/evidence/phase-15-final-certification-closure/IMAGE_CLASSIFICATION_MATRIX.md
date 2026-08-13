# Image Classification Matrix

| Classification | Meaning | Delete? |
|----------------|---------|---------|
| `current` | Active Production digest | No |
| `rollback` | Prior digest in safety window | No |
| `used_by_running_container` | In use | No |
| `used_by_stopped_container` | Stopped ref | No |
| `used_by_other_production` | Another Production | No |
| `used_by_stage` | Stage ref | No |
| `used_by_candidate` | Update candidate | No |
| `protected_by_active_operation` | Op in flight | No |
| `protected_by_recovery` | Recovery set | No |
| `ownership_ambiguous` | Labels missing/mismatch | No |
| `eligible_for_cleanup` | Unreferenced managed image past window | Yes (exact delete only) |
