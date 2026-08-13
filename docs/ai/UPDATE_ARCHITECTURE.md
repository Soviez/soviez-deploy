# Update architecture

## Existing
`mode_update`: pull `:latest`; optional web name else **all tenants**; schema upgrade.

## Unsafe
Implicit all-tenant; unpinned latest.

## Planned
`--update <exact-prod-tenant>` only; annual product_updates + license ownership; digest via pull session; no interrupt of in-flight DB migration on token expiry.
