# CLI Architecture

- Parser: `src/cli/parse.sh` (`soviez_cli_parse`, `soviez_cli_usage`)
- Dispatch: `src/entrypoint.sh` (`soviez_main`)
- ~189 commands / ~234 flags
- Quirk: first `--stage` case arm wins (Stage create); later migration `--stage <id>` arm is dead
- `--merge-in` does not exist
- `--init` is wizard-only, not modular

See `docs/user/CLI_REFERENCE.md` and evidence `CLI_SOURCE_AUDIT.md`.
