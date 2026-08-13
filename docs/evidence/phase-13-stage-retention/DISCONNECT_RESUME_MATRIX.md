# Disconnect / Resume Matrix
Deletion has a durable operation ID, per-Stage lock, and completed-step list. A failure after some owned resources are removed is `recovery_required`; retry skips completed steps.

Integration injects filestore failure, obtains the retention operation ID, clears the fault, and calls `--stage-retention-reattach`. It writes the tombstone without redoing completed work.
