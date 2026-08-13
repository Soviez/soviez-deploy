# Existing server remediation strategy

## New deployments
Auto apply secure defaults (Gate S1) during `--new`.

## Existing Soviez-managed
1. `--security-check` audit-only
2. Operator decisions for downtime class
3. Controlled remediate (role revoke, port rebind) with rollback snapshots
4. Never silent credential weaken

## External Odoo being migrated
Assume untrusted source → Gate S4 quarantine mandatory before Production.

## Incident / possibly compromised
Evidence-first (`--security-incident`); prefer migrate-to-clean + quarantine over destructive auto-clean on live.
