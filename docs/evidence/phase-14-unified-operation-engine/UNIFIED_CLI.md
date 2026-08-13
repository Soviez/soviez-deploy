# Unified CLI Specifications

**Phase:** 14  
**Verdict:** PASS  

## 1. Parameter Specifications

The main entrypoint parsing routes args cleanly:

- `--operations [--active|--failed|--type <t>|--environment <e>]` — List, filter, or query indexed operations.
- `--operation-status <id>` — Print detailed status payload of a given operation ID.
- `--operation-reattach <id>` — Re-establish connection to a running worker.
- `--operation-cancel <id> [--yes]` — Safely terminate active commands with support rollbacks.
- `--operation-retry <id>` — Resume a failed retryable operation.
- `--operation-recover <id> [--yes]` — Reconcile and fix stale locks or interrupted workflows.
- `--operation-logs <id> [n]` — Tail safe, redacted process logs.

## 2. Backward Compatibility Aliases

Existing command flags (`--reattach`, `--stage-reattach`, `--ssl-reattach`, `--stage-retention-reattach`) are preserved 100%. Under the hood, they invoke the unified `soviez_ops_adapter_reattach` method. This guarantees zero impact on existing systemd timers or legacy admin scripts.
