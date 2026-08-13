# Ticket Replay Security

No new ticket engine. Adapters in `src/security/replay_audit.sh` enforce purpose separation.

Behavior reused from Phase 15/23 stores:
- first valid use allowed
- exact retry / idempotent same operation retained by owner engines
- distinct second consume of same nonce/package id denied
- wrong purpose (Registry pull vs update apply vs migration auth vs Stage) denied
