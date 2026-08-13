# Source Discovery Model — Phase 17

**Non-destructive. Exact Production only. No business payload egress.**

## Targeting

- Require explicit `<production-id>` (or equivalent exact selector).
- Reject Stage IDs, ambiguous multi-match, and wrong-host identities.
- Codes: `MIGRATION_SOURCE_REQUIRED|INVALID|AMBIGUOUS|IDENTITY_MISMATCH`.

## Local collection (minimum)

### Identity (local; subset may egress per OD-15)

| Field | Sensitive? | Notes |
|-------|------------|-------|
| source Production environment ID | No | |
| License ID | Minimal metadata | Account-scoped |
| database UUID | Minimal | Identity, not contents |
| host identity / fingerprint | Minimal | |
| device identity | Minimal | |
| container/runtime identity | Local preferred | |
| current image digest | Minimal | |
| ERP major/product version | Minimal | |
| architecture / OS | Minimal | |
| Docker/Compose versions | Minimal | |
| PostgreSQL major version | Minimal | |

### Data footprint (sizes/counts only — never contents)

| Field | Sensitive? |
|-------|------------|
| database / filestore / addon / config sizes | No (aggregates) |
| estimated transfer size, file count, inode notes | No |
| largest components (path categories, not file bytes) | Careful — paths only |

### Runtime

| Field | Notes |
|-------|-------|
| Production container / PG / Nginx status | Local |
| domain / SSL status | Inspect only |
| active operations / maintenance / update/restore/backup | Conflict gate |
| Stage inventory | See `STAGE_DISCOVERY_MODEL.md` |
| backup health | Capability + latest verified age metadata |

### Addons / configuration

| Collect | Never collect |
|---------|---------------|
| addon paths, module names/versions | Addon source trees as payloads |
| custom/third-party inventory | Secret values |
| Python/system dependency names | Passwords, keys |
| configuration fingerprint (hash) | Full config dumps |
| env **names** only | Env **values** |
| integration presence boolean/category | Webhook secrets |

### Network

| Collect | Notes |
|---------|-------|
| outbound connectivity class | No phone-home loop |
| ports / firewall / NAT / IPv4/IPv6 | Assessment |
| bandwidth/latency **estimates** | Synthetic probes only |
| DNS **state** | No mutation |
| source→destination reachability requirements | Pairing later |

## Sensitive — stays local

Database dumps, filestore, attachments, addon source, secret-bearing configs, customer/employee/accounting records, passwords, private keys, SSH keys, activation secrets, unrestricted logs, backup payloads, env values.

## Egress (if connected) — permitted metadata only

Documented allowlist (owner OD-15): account ID, License ID, source environment ID, device proof, host fingerprints, version, image digest, arch, PG major, non-sensitive capability inventory, readiness status, signed nonce, Migration Token **eligibility** (not consume), timestamps, idempotency key.

**No hidden telemetry. No periodic phone-home. No payload relay.**

## Persistence

- Discovery snapshot ID under local migration state dir (proposed).
- Signed discovery report optional; expires per OD-18.
- Exact Production binding immutable for snapshot lifetime.

## Ops

Operation type: `migration_source_discovery` — states in `OPERATION_ENGINE_MODEL.md`.

## Abort / reboot

Leave source ERP running; preserve evidence; clean temp secrets; no token burn; no DNS; no maintenance.
