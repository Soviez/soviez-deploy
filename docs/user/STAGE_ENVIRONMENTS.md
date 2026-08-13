# Stage Environments

## What Stage is

A **non-Production** Soviez ERP environment cloned/created from managed Production for testing, demos, or previews. Commercially unlimited count subject to resources and **Stage entitlement**.

## Entitlement

Stage create/clone/refresh/rebuild require Stage entitlement from SaaS (or signed offline Stage package).

```text
Stage entitlement expiry blocks create/clone/refresh/rebuild according to policy.
It does NOT shut down or delete an already-existing Stage merely because entitlement expired.
```

Local ops that continue after entitlement expiry: list, status, start, stop, backup, drop (operator-initiated).

## Retention (canonical)

```text
default lifetime = 14 calendar days
absolute maximum total lifetime = 60 days from immutable original creation time
```

- Extension via `--stage-retention-extend <id> --days N` (cannot exceed 60 from original creation)
- Countdown / Needs Action surfaces via retention status
- Retention run performs final backup then Safe Shield deletion path
- Safe Shield protects against unsafe deletion

## Commands (modular)

```bash
./dist/soviez.sh --stage --production-tenant <id> --stage-domain FQDN
./dist/soviez.sh --stage-list
./dist/soviez.sh --stage-status <stage-id>
./dist/soviez.sh --stage-start|stop|backup|drop <stage-id>
./dist/soviez.sh --stage-retention-status [stage-id]
./dist/soviez.sh --stage-retention-extend <stage-id> --days N
./dist/soviez.sh --stage-retention-run
./dist/soviez.sh --stage --offline-request
./dist/soviez.sh --stage --offline-import PATH
```

## Domain / TLS / security

Stage requires its own domain. Same private Odoo binding policy as Production. Quarantine rules apply to untrusted restores into Stage.
