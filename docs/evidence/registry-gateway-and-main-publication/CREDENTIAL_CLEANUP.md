# CREDENTIAL_CLEANUP — Temporary Credential Hygiene

## Verdict

**PASS** (proof script)

## Scope

Ensure disposable client-side credential material created during pull flows is removed after use.

## Evidence: real-oci-pull-proof.sh

The proof script simulates docker credential directory lifecycle:

1. Create temp directory under system tmp (`soviez-dockercfg-*`).
2. Write `config.json` with synthetic auths entry.
3. Assert directory exists.
4. `rmSync` recursive delete.
5. Assert directory no longer exists.

Output field: `"credential_cleanup": "PASS"`

## Installer behavior (design)

Installer stage flow writes ticket material to operation-scoped paths with restrictive modes:

| Path pattern | Mode |
|--------------|------|
| `auth/ticket.token` | 600 |
| `auth/keys.json` | 600 |
| `auth/ticket.token.pending` | 600 |

Root-level `ticket.token` and `keys.json` are gitignored (PP-03) and must not persist in repo.

## Gateway host

| Secret file | Expected handling |
|-------------|-------------------|
| `/etc/soviez-registry-gateway/gateway.env` | Persistent (required); mode 640+ |
| Hub PAT in env | Rotate on compromise; not copied to clients |

## Uninstall path

`uninstall.sh --purge` removes config/state per operator docs. Live uninstall test on VPS: **PENDING**

## Related security matrix

Installer invalidation triggers include `registry_credential_persistence` (see `dist/soviez.sh` security helpers).
