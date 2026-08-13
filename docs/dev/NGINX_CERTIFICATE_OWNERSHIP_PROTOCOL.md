# NGINX_CERTIFICATE_OWNERSHIP_PROTOCOL.md

## Boundaries

- **Owned:** files under `$SOVIEZ_SSL_NGINX_OWNED_DIR` containing `# SOVIEZ_OWNED` marker + sidecar `.meta.json`  
- **Unmanaged:** all other Nginx configs — never deleted or overwritten by Soviez  

## Naming

`<environment_id>__<domain>.conf` (+ `.staged`, `.previous`, `.meta.json`)

## Lifecycle

1. Render staged config with checksum + metadata  
2. Collision detect (active + staged) for same domain  
3. `nginx -t` (or fixture equivalent)  
4. Atomic promote staged → active; keep `.previous`  
5. Safe reload (`nginx -s reload`; never global reset)  
6. Rollback from `.previous` on failure  

## Collision

Fail closed with `NGINX_CONFIG_CONFLICT`; operator must resolve — no silent replace.

## Cleanup

No broad wildcard deletion; no host-wide rewrite; no Docker prune.
