# Migration Abort and Recovery Protocol

`sudo soviez.sh --migration-abort <pair-id>` — idempotent. Source stays active; token not consumed; DNS/maintenance unchanged; revoke pair certs + bootstrap identity; preserve evidence; destination reusable.

Reboot: ops state → `recovery_required` / `--migration-recover`.
