# Tombstone Protocol
Before final Stage-directory removal, the engine writes `/var/soviez/retention-tombstones/<stage-id>.json` (test mode remapped). It records Stage/parent identity references, original creation, deadline, extensions, completion time/reason, operation ID, backup path/checksum, completed deletion manifest, Safe Shield status, and policy version.

License ID is abbreviated in tombstone output; no secrets or business data are recorded.
