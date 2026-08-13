# REBOOT_RECOVERY_E2E

**Date:** 2026-07-30  
**Result:** **PASS** (isolated disposable container reboot)

## Environment constraint

- Host is macOS without `systemctl` / `systemd-nspawn`.
- Strongest available substitute: disposable Docker container (`postgres:16` already present) with bind-mounted Stage state under `$HOME` (Colima only reliably mounts `$HOME`; `/tmp` and `/Volumes/PortableSSD` did not sync host↔container in probes).

## Flow

1. Start disposable host container writing `host_boot.log` + heartbeat into mounted SOVIEZ_ROOT.
2. Start durable Stage worker; pause at `filestore_snapshot_created`.
3. Kill worker process.
4. `docker restart` container → boot log increments (boots≥2).
5. CLI reattach / resume create from checkpoint.
6. Dump checksum unchanged (not blindly rewritten).
7. Operation reaches `completed`; origin cert present; post-reboot heartbeat advances.

## Commands

```bash
bash tests/integration/test_stage_reboot_recovery_e2e.sh
```

## Proven

| Assertion | Result |
|-----------|--------|
| Container reboot marker increments | PASS |
| Resume from checkpoint | PASS |
| Dump not rewritten | PASS |
| Completed + origin cert | PASS |
| Post-reboot heartbeat advances | PASS |

## Attempted alternatives

- Host `systemctl`: unavailable
- `systemd-nspawn`: unavailable
- Pulling dedicated systemd image: not authorized / blocked by auto-review; not required after container reboot substitute succeeded
