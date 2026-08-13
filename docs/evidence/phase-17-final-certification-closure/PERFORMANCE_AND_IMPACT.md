# PERFORMANCE_AND_IMPACT.md

Phase 17 paths are metadata-only. Discovery/bootstrap/pairing/readiness complete in seconds on disposable fixtures. Source HTTP and PostgreSQL remain available during discovery. No maintenance window. Colima host reboot matrices are intentionally heavy and run last in `run_all`. Destination guest bootstrap uses qemu `linux/amd64` under Colima on Apple Silicon — acceptable for certification, slower than native amd64 bare metal.
