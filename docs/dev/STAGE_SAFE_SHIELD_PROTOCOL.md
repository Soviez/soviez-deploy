# Stage Safe Shield Protocol (Phase 13)

**Purpose:** Fail closed before retention deletion. Safe Shield is local-only and runs after a verified final backup, before any destructive Stage cleanup.

## Required validations

1. Sanitize the requested Stage ID; resolve its Stage directory and exact inventory identity.
2. Require `identity.json` and a Stage-origin certificate; identity Stage ID must match the requested ID.
3. Require exact derived Stage DB, container, and dedicated network names. Reject `odoo`, `postgres`, Production-like names, or non-Stage network ownership.
4. Resolve filestore, config, and secrets paths. Each must be a real, non-symlink path under the selected Stage directory; `..` paths are rejected.
5. If an Nginx Stage config exists, require or create the local ownership marker and require it to match the Stage ID.
6. Reject shared or ambiguous origin-certificate paths.
7. Reject an active conflicting retention lock unless the current worker holds it.

## Outcomes

Success returns `OK`. Any failed check returns a structured Safe Shield failure, prevents deletion, and records `SAFE_SHIELD_VALIDATION_FAILED` with `needs_action`. The engine separately checks Production health before destructive removal.

## Protected boundaries

Safe Shield authorizes only the named Stage's explicit resources. It does not authorize Production DB/container/filestore, shared certificate material, another Stage, wildcard database targets, or global Docker prune. Shared wildcard certificates are retained; only unshared Stage certificate material may be removed.

The protocol detects ordinary inventory/path ambiguity but cannot protect against a Full Root actor who replaces local code or evidence. That residual is documented honestly; it is not DRM.
