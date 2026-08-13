# Root Causes — Why Phase 15 Was PARTIAL

1. **Docker ERP path stubbed** — Certification host previously lacked a usable Docker daemon for real ERP image `-i/-u`; candidate upgrade used fixtures → incomplete E2E.
2. **Reboot matrix incomplete** — Update checkpoints had reconcile contracts, but no shared Colima VM stop/start proving `UPDATE_RECOVERY_REQUIRED` for irreversible switch/rollback.
3. **License Guard candidate honesty** — Temporary candidate needed an installer identity contract without Guard bypass or a second permanent slot; Guard lacks first-class temp-candidate mode (Root residual must be disclosed).
4. **Image lifecycle gap** — Post-update image retention lacked classify/reference/TOCTOU cleanup; risk of broad prune or deleting current/rollback/shared refs.

## Closure
All four addressed in final certification (see `FINAL_REPORT.md`). No product constitution or SaaS UI changes required.
