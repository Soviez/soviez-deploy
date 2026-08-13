# shellcheck shell=bash

soviez_migration_p22_retirement_provider() {
  # Provider hooks are advisory — never terminate host.
  printf '{"provider":"none","host_termination_authorized":false}\n'
}
