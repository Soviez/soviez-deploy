# Migration Stabilization Protocol

Default duration: **86400s (24h)**.  
Certification: `SOVIEZ_MIG_P22_FIXTURE=1` + `SOVIEZ_MIG_P22_ALLOW_CERT_CLOCK=1` + `SOVIEZ_MIG_P22_CERT_CLOCK_EPOCH` + short `SOVIEZ_MIG_P22_STABILIZATION_SECONDS`.  
Production clock override is denied.

Observation must span the configured duration with multiple ticks (not a single instantaneous check).  
Inject failures via `SOVIEZ_MIG_P22_INJECT_*` for certification.
