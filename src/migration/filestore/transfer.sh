# shellcheck shell=bash

soviez_migration_filestore_transfer() {
  # Alias used by orchestration — delegates to presync for bulk transfer
  soviez_migration_filestore_presync "$@"
}
