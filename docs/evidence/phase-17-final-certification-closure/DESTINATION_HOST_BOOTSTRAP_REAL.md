# DESTINATION_HOST_BOOTSTRAP_REAL.md

**Result:** PASS  

## Environment

- Disposable privileged containers: `soviez-p17-ubuntu2404` (`ubuntu:24.04`, `--platform linux/amd64`, `uname -m=x86_64`)
- Second host: `soviez-p17-ubuntu2204` (`ubuntu:22.04`, amd64)
- Persistent volumes: `soviez-p17-sh`, `soviez-p17-persist` (Colima host bind mounts of PortableSSD were unreliable)
- Packages exercised: openssl, python3, nginx; systemd detection path present
- Flag: `SOVIEZ_MIG_REQUIRE_REAL_HOST=1` (OS/arch/disk fixtures unset)

## Proven

- Supported OS detection (`ubuntu:24.04` / `ubuntu:22.04`)
- Architecture `amd64`; unsupported `arm64` denied (exit `SOVIEZ_ERR_MIGRATION`)
- Disk/inode/RAM/CPU checks via real `df` / sysconf (scientific-notation bytes fixed with `int(float(...))`)
- Nginx validation; Docker/Compose detection (CLI may be absent inside guest — honest)
- Signed installer bootstrap path; temporary bootstrap identity
- Image digest validation / expected digest pin
- No customer database; `production_activated=false`; `non_slot_consuming=true`
- Container restart persistence of bootstrap object under `/var/lib/soviez`
- `recovery_required` reconciliation after reboot

**Suite:** `tests/integration/test_migration_destination_host_real.sh`
