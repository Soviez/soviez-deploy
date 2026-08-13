# High-risk defects

## H1 — UFW not Docker-aware
UFW opens 22/80/443 only; published container ports can remain reachable via Docker iptables. No `DOCKER-USER` chain management.

## H2 — Disposable/staging paths use weak fixed DB password `odoo`/`odoo`
`soviez-sh` migration staging / update real_docker / restore_test fixtures. Safe only if never host-published and never reused as Production. Risk if operators confuse staging with Production or publish ports.

## H3 — Missing `proxy_mode=True` in production tenant conf
Behind Nginx without explicit proxy_mode, client IP / URL generation / trusted proxy behavior may be incorrect (security + ops).

## H4 — No DB technical-persistence scanner
No read-only inspection of `ir.actions.server` / malicious patterns before restore→live.

## H5 — Restore/migration first-boot quarantine incomplete
Offline package quarantine ≠ blocked-egress first boot + cron/mail/webhook neutralization + security acceptance gate.

## H6 — Secrets visible to `docker inspect` / container env
`POSTGRES_PASSWORD`, `--db_password`, `SOVIEZ_MIGRATION_SECRET` passed as container env / argv-equivalent env. Inspect-visible on host root compromise.

## H7 — Modular `soviez-sh` production DB provision is stub
`src/database/provision.sh` non-test path only records db name; real Production still depends on ERP monolith installer — dual-path governance risk during Phase 25.
