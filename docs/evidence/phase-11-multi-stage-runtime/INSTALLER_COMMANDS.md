# INSTALLER_COMMANDS — Phase 11

| Command | Implemented | Notes |
|---------|-------------|-------|
| `--stage` | Yes | Connected create pipeline |
| `--stage-id` / `--stage-domain` | Yes | Required for non-TTY |
| `--stage-list` | Yes | Local |
| `--stage-status` | Yes | Local |
| `--stage-start` / `--stage-stop` | Yes | Local; post-expiry OK |
| `--stage-backup` | Yes | Local |
| `--stage-drop` | Yes | Confirmation required |
| `--stage-reattach` | Yes | Resume SM |
| Offline request export | Yes | `soviez.stage-offline-request.v1` |
| Offline package import | Yes | `--offline-import` → create |

Source: `src/cli/parse.sh`, `src/entrypoint.sh`, `src/commands/stage*.sh`.
