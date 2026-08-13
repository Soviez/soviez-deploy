# Destination Bootstrap Model — Phase 17

**Prepare a new destination host without activating Production, burning Migration Token, changing DNS, or transferring business data.**

## Recommended identity answer (pending OD)

Destination bootstrap creates a **temporary migration bootstrap identity** / **neutral host record** — **not** a permanent active Production instance.

| Artifact | Phase 17 |
|----------|----------|
| Neutral host record | Allowed |
| Temporary destination environment / bootstrap ID | Allowed |
| Permanent Production instance | **Forbidden** |
| License Slot permanent bind | **Forbidden** |
| Customer DB creation | **Forbidden** |
| Domain cutover / DNS mutation | **Forbidden** |

## Preflight (minimum)

- Supported Linux distribution/version (OD-09)
- Architecture (OD-10)
- Root/sudo, SSH readiness, time sync, hostname
- Storage, inodes, RAM, CPU
- Docker + Compose presence/install policy
- Firewall baseline
- Nginx or approved reverse proxy: **install now vs defer Phase 18** (OD-21)
- Required directories, local secret store, systemd
- Operation state paths, backup staging, migration staging paths
- Exact destination host identity

## Bootstrap steps (conceptual)

1. Validate destination host  
2. Obtain and verify signed installer (see `SIGNED_INSTALLER_BOOTSTRAP.md`)  
3. Install runtime prerequisites (Docker/Compose/dirs)  
4. Destination `--init` readiness (neutral)  
5. Optional Device Authorization for temporary identity  
6. Register temporary bootstrap ID  
7. Validate destination readiness (no ERP Production)  
8. Emit bootstrap report  

## What may run before activation

| Allowed | Forbidden |
|---------|-------------|
| Installer / diagnostics | Business ERP Production |
| Docker / optional image pull (OD-22) | Permanent License Slot burn |
| Neutral DB-free checks | Customer DB |
| Local secret store scaffolding | Domain cutover |
| Ops engine paths | Maintenance landing (Phase 18) |

## License Guard

See `LICENSE_GUARD_BOOTSTRAP_BOUNDARY.md`. Source remains valid and active.

## Abort

Disable temporary bootstrap identity; revoke temp trust; clean temp secrets; leave host reusable; preserve diagnostics; no broad cleanup.

## Ops

`migration_destination_bootstrap` — states in `OPERATION_ENGINE_MODEL.md`.
