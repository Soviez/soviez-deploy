# Migration (Soviez → Soviez)

## Overview

Phased migration (discovery → pairing → domain/TLS → streaming transfer → authorization/rebind → cutover → stabilization → archive/retirement).

```text
source purge is never automatic.
```

## There is no `--merge-in`

Historical plan names `--merge-in` / `--migrate-in` were **never** implemented as a single flag. Use the `--migration-*` command family.

## Major phases (operator view)

1. **Discover** source Production
2. **Bootstrap** destination + **pair** with confirmations
3. **Readiness** + Stage select (optional)
4. **Domain / DNS challenge / landing / TLS / routing**
5. **Transfer** (direct streaming, resumable)
6. **Authorization / activate destination / license rebind**
7. **Cutover** + DNS try-again / abort / rollback window
8. **Stabilization / archive / retirement readiness**
9. **S4 quarantine** before cutover when required for untrusted/staging paths

## Selected commands

```bash
./dist/soviez.sh --migration-discover <production-id>
./dist/soviez.sh --migration-bootstrap-destination [--confirm]
./dist/soviez.sh --migration-pair <production-id> --destination-code CODE [--confirm]
./dist/soviez.sh --migration-readiness <pair-id>
./dist/soviez.sh --migration-transfer-start <pair-id> [--confirm]
./dist/soviez.sh --migration-activate-destination <pair-id> [--confirm]
./dist/soviez.sh --migration-cutover-start <pair-id> [--confirm]
./dist/soviez.sh --migration-cutover-rollback <operation-id> [--confirm]
./dist/soviez.sh --migration-status <operation-id>
```

See [CLI_REFERENCE.md](CLI_REFERENCE.md) for the full migration flag list.

## Detailed historical operator notes

Fragmented pre-canonical migration guides are archived under `docs/archive/pre-canonical-user/` and superseded by this document + developer migration architecture.
