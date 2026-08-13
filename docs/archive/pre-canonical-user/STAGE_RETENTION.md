# Stage Retention

**Status:** Implemented — Phase 13 PASS · Version `0.13.0-phase13`

Every Stage has a retention lifetime that is separate from billing and access entitlement:

- Default: **14 calendar days** from the Stage's original creation.
- Maximum: **60 calendar days** from that same original creation.
- An extension sets the requested **total lifetime**. It does not add days to the current deadline or reset the creation clock.
- Stage License or Stage Operation Ticket expiry never stops or deletes an existing Stage.

## Check or extend retention

```text
soviez.sh --stage-retention-status [stage-id]
soviez.sh --stage-retention-extend <stage-id> --days <total-days>
```

Extensions can only move forward, cannot exceed 60 days, and require confirmation (interactive Stage-ID type-back or `--yes`). For example, `--days 30` means the Stage is retained until 30 calendar days after its original creation.

The Stage's neutralization page shows an English daily countdown and scheduled deletion date. Its timezone is shown in status output.

## What happens at expiry

The local retention scan first creates a final backup and verifies its checksum. It then runs Safe Shield, which verifies that every target is the selected Stage's own resource and that Production remains protected. Only then may it remove the Stage's explicit container, database, filestore, config, secrets, network, and inventory entry.

If backup, ownership, safety, or deletion is uncertain, automatic deletion stops and the Stage reports **Needs Action**. It is not deleted on ambiguity.

```text
soviez.sh --stage-retention-run <stage-id>
soviez.sh --stage-retention-retry <stage-id>
soviez.sh --stage-retention-reattach <operation-id>
```

Deletion and retry require confirmation. A final local tombstone retains deletion and backup-reference evidence. Retention has no phone-home behavior and does not upload backups or Stage data.

See [Stage License](STAGE_LICENSE.md) and [Stage Environments](STAGE_ENVIRONMENTS.md).
