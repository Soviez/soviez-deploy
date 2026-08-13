# Persistence audit (S2)

Read-only cron/systemd/rc/profile inventory and `/etc/ld.so.preload` state. Unexpected preload content fails the gate; never auto-removed (S3 owns deeper detection).
