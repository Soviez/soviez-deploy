# Migration Source Discovery Protocol

Command: `sudo soviez.sh --migration-discover <production-id>`

## Rules

- Exact Production ID only; Stages and wildcards denied  
- Non-destructive: no quiesce, maintenance, backup creation, DNS, License mutation, token consume  
- Collect identity, capacity aggregates, runtime, addons (names/versions), Stages (unselected), backup classification, network readiness  
- Sign discovery object; TTL 24h  

Operation type: `migration_source_discovery`
