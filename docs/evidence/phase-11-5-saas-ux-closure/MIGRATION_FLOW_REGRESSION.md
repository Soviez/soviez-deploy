# MIGRATION_FLOW_REGRESSION.md

## Preserved semantics

- Token balance still sourced from license `ip_migration_credits` + profile credits (card + summary)
- Overview card retains **Migrate Instance** and pending-migration cancel behavior
- Instance → Migration tab points customers back to the existing Overview Migrate Instance wizard
- No external Odoo import UI

## Seed

Main Production seeded with `ip_migration_credits: 1` → summary `migrationTokens: 1`.
