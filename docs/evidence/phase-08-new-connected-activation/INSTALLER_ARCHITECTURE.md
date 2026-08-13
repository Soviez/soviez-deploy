# INSTALLER_ARCHITECTURE — Phase 8

## Design principle

Modular bash source in `src/` → single distributable `dist/soviez.sh` via `build/assemble.sh`. **Never edit `dist/` directly.**

## Module layers

```
entrypoint.sh
  └── cli/parse.sh          # --new, --reattach, flags
  └── commands/new.sh       # orchestration
  └── commands/reattach.sh  # resume wrapper

operations/
  ├── state_machine.sh      # 29 states, transition rules
  └── engine.sh             # lock, persist, events.jsonl

core/                       # errors, logging, redact, json, paths, preflight
auth/                       # device keys, signing, client (Phase 5)
api/                        # http, slots_client, registry_client
registry/                   # manifest_verify, pull_client (Phase 7)
tenant/                     # identity, secrets (0600)
docker/ + database/         # provision stubs (test mode) / real (prod)
ssl/ + nginx/               # local CA, validate, render
license/                    # fingerprint, choice, activate_orm, ack
ui/                         # dashboard, consent
```

## Assembly order

36 modules concatenated in dependency order — see `build/assemble.sh` `MODULES` array.

Each module wrapped with `# --- begin <path> ---` / `# --- end <path> ---` markers.

## Operation persistence

| Artifact | Format | Purpose |
|----------|--------|---------|
| `state.json` | JSON | Current state + correlation ids |
| `events.jsonl` | JSONL | Append-only audit trail |
| `lock` | file | Single-worker exclusion |

Schema: `schemas/new_operation_state.schema.json`

## Test mode vs production

| Concern | Test (`SOVIEZ_TEST_MODE=1`) | Production |
|---------|----------------------------|------------|
| Docker | Stub markers in `stubs/` | Real containers |
| SaaS | `mock_saas_server.py` | Real soviez-saas |
| ORM | `SOVIEZ_ODOO_STUB` or marker file | `odoo shell` + official method |
| Consent | `SOVIEZ_AUTO_CONSENT=1` | Interactive prompt |

## Sovereignty hooks

- `soviez_redact_text` on all log paths
- `soviez_tenant_secret_write` mode 600
- Temp docker config deleted after pull
- ORM key via stdin staging only

## Version

`0.8.0-phase8` — SHA256 in `dist/soviez.sh.sha256`
