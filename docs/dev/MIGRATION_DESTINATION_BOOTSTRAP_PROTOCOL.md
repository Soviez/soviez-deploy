# Migration Destination Bootstrap Protocol

Command: `sudo soviez.sh --migration-bootstrap-destination [--confirm]`

## Preflight

Ubuntu 22.04/24.04, amd64, disk/inodes/RAM/CPU, Docker/Compose/Nginx/systemd readiness (fixtures allowed in TEST_MODE).

## Installer

Signed immutable package; refuse `latest`; verify signature/checksum/arch.

## Identity

Temporary bootstrap ID + one-time bootstrap code; `non_sellable=true`, `non_slot_consuming=true`, `production_activated=false`.

Operation type: `migration_destination_bootstrap`
