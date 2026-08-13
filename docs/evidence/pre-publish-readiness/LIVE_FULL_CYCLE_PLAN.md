# LIVE_FULL_CYCLE_PLAN

**Do not execute in this audit.** Future plan after publication:

1. Provision isolated VPSs + DNS + SaaS sandbox + test License/Device
2. Clean server → install/init soviez-sh artifact `{VERSION}`
3. Production `--new` → activation → License/Device/slot binding
4. Domain + TLS → Odoo up → verify WebSocket/realtime (`workers=0`, `/websocket`)
5. Backup (local) → configure off-host target → backup again
6. Stage enable → refresh/clone → Stage proxy_mode/WS checks
7. Connected update candidate → switch → rollback scenario
8. Offline update path with entitled bundle
9. SaaS unavailable behavior (deny/grace as designed)
10. Support expiry behavior
11. Backup restore + untrusted restore quarantine
12. Migration source→destination: authorize, stream, quarantine, cutover, rollback, archive (**no automatic purge**)
13. Security scans / diagnostics / reboot recovery
14. Capture evidence pack under new `docs/evidence/live-full-cycle-sim/`

Destructive ops (future): rollback switch, restore overwrite of disposable DB, migration cutover on disposable hosts, quarantine deletes of disposable artifacts — **never on customer Production**.
