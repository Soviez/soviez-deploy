# Execution Model

1. `dist/soviez.sh` sources assembled modules
2. `soviez_cli_parse` sets `SOVIEZ_CLI_COMMAND`
3. `soviez_main` dispatches to `soviez_cmd_*`
4. Long work creates operation IDs under ops registry
5. Terminal disconnect ≠ abort; use reattach/recover

Test mode uses disposable roots when `SOVIEZ_TEST_MODE=1`.
