# CLI proposal (conceptual — not implemented)

## Principles
Exact targeting; human + JSON; stable exit codes; idempotent; retry/recover via Phase 14 where stateful; no secrets in argv; no broad cleanup; no live rollout; no Phase 25 commands.

## Proposed commands

| Command | Purpose |
|---------|---------|
| `--security-status [--json]` | Report hardening posture (STRICT_SIG, lockdown, scan last result) |
| `--security-verify [--json]` | Run local security self-check (static gates) |
| `--security-scan [--json]` | Invoke local secret scan over tree/`dist` |
| `--offline-phase24-readiness` | **Existing** — keep; optionally enrich PASS/WARNING/BLOCKED |

## Explicitly not proposed
- `--purge-*`, `--docker-prune`, `--release-publish`, `--go-live`
- Any command that mutates live customer commercial state

## Exit codes (CLI level)
0 success; 10 readiness warning; 20 security failure; 30 conflict; 40 recovery required; 50 usage error.
