# Soviez.sh Product Contract

**Status:** OWNER-APPROVED CANONICAL CONTRACT  
**Version:** 0.24.6.3-platform-cli (internal platform build family)  
**Authority:** This document is the single Source of Truth for Soviez.sh product behavior. All other active documentation must align with it or explicitly defer to it.

**Implementation truth:** See [IMPLEMENTATION_STATUS_MATRIX.md](IMPLEMENTATION_STATUS_MATRIX.md) for what is certified live vs approved-but-not-yet-implemented.

---

## 1. Product purpose

Soviez.sh is the sovereign **CLI installer and operations plane** for self-hosted **Soviez ERP** (Odoo 18–based). It is not a permanently running daemon; long-running work uses persistent operation jobs and systemd-managed workers where designed.

Customers invoke one public executable:

```bash
soviez.sh ...
```

Installed at `/usr/local/bin/soviez.sh`, delegating to `/opt/soviez/platform/current/soviez.sh`.

Customers must **not** need repository-relative paths, `dist/` artifacts, or `src/` checkouts to invoke Soviez.sh.

---

## 2. Architectural invariants

| Invariant | Rule |
|-----------|------|
| Sovereignty | ERP runtime does not require continuous SaaS connectivity |
| Support expiry | Does **not** stop Production, backups, restore, or diagnostics |
| Stage entitlement expiry | Blocks **new** Stage mutations; does **not** immediately destroy existing Stages |
| Telemetry | No hidden periodic phone-home; network only on user-initiated or explicitly defined service actions |
| Secrets | Never in Git, logs, docs, or evidence |
| Webmin/Virtualmin | **NEVER** installed by Soviez |
| PostgreSQL | Private Docker network only; never public `:5432` |
| Odoo backends | Loopback only (`127.0.0.1:8069` HTTP; `127.0.0.1:8072` evented when multi-worker) |
| DB roles | `soviez_admin` (bootstrap) vs `soviez_app` (Odoo runtime); app role least-privilege |
| Malware response | Detect → preserve evidence → quarantine → classify; **never** auto-delete business assets |
| Release immutability | Named release → digest is permanent; new build → new release name |
| Legacy merge-in migration | **NOT_SUPPORTED** publicly; use `--migration-*` |

---

## 3. Public CLI families

### 3.1 Core (read-only / local)

```bash
soviez.sh --help
soviez.sh --version
soviez.sh --list
soviez.sh --operations
soviez.sh --security-status
```

### 3.2 Provisioning

```bash
soviez.sh --init          # APPROVED: prepare/harden host (see §4)
soviez.sh --new           # Create Production (connected activation)
```

### 3.3 Production lifecycle

```bash
soviez.sh --status <id>           # APPROVED (see matrix)
soviez.sh --update <id> [--release <name>]
soviez.sh --backup <id>
soviez.sh --restore ...
```

### 3.4 Stage

```bash
soviez.sh --stage ...
soviez.sh --stage-list
soviez.sh --stage-status <id>
soviez.sh --stage-start <id>
soviez.sh --stage-stop <id>
soviez.sh --stage-backup <id>
```

### 3.5 Resource management

```bash
soviez.sh --tune
soviez.sh --tune --dry-run
soviez.sh --tune --explain    # APPROVED (see matrix)
```

### 3.6 Release information

```bash
soviez.sh --releases              # APPROVED (see matrix)
soviez.sh --release-status <id>   # APPROVED (see matrix)
```

### 3.7 Migration

```bash
soviez.sh --migration-*
```

**Forbidden:** legacy merge-in migration interface (use `--migration-*` only)

### 3.8 Emergency

```bash
soviez.sh --safe-mode <production-id>       # APPROVED (see matrix)
soviez.sh --safe-mode-exit <production-id>  # APPROVED (see matrix)
```

### 3.9 Diagnostics

```bash
soviez.sh --doctor    # APPROVED read-only health diagnosis (see matrix)
```

---

## 4. `--init` (host preparation)

**Approved meaning:** Prepare and harden the server for Soviez.

**Must include (when fully implemented):** OS validation (Ubuntu LTS), security update preflight, Docker Engine, platform installation, filesystem layout, Docker networks, Nginx, firewall, AppArmor validation, Fail2Ban, unattended security updates, ClamAV baseline, YARA/native security integration, system services, security validation, idempotent re-run.

**Must never:** install Webmin or Virtualmin.

**Current implementation note:** Host bootstrap `--init` is certified on the **dual Production wizard** (`Soviez ERP/soviez.sh`). Modular PATH CLI convergence is in progress — see implementation matrix.

---

## 5. ERP deployment source

Soviez ERP is deployed from **Docker Hub images**, not GitHub source checkout.

| State | Model |
|-------|-------|
| **Current** | Public Docker Hub repository may be used (`soviez/soviez-erp` family) |
| **Future** | Private Docker Hub + short-lived pull authorization via entitlement |

**Deployment authority:** Named release → signed metadata → `repository@sha256:<digest>`. The `latest` tag is **not** deployment authority.

---

## 6. Named release model

| Concept | Example |
|---------|---------|
| Release name (owner-defined) | `Sam0.2` |
| Internal platform build | `0.24.6.3-platform-cli` |
| Channel | `stable`, `certification`, `preview` |
| ERP digest | `sha256:…` (immutable deployment identity) |

**Immutability:** Once `Sam0.2 → digest A` is published, it must never become `Sam0.2 → digest B`. A changed build requires `Sam0.3` (or next owner-defined name).

Channel promotion (e.g. certification → stable) must not require image rebuild if digest is identical.

---

## 7. `--new` lifecycle

```text
platform self-update preflight
→ server/resource preflight
→ entitlement / named release resolution
→ exact ERP image digest resolution
→ docker pull repository@sha256:…
→ PostgreSQL bootstrap (soviez_admin + soviez_app)
→ secure networking
→ Odoo + PostgreSQL config
→ automatic tuning
→ Nginx + domain + SSL
→ security validation
→ health / acceptance (Needs Action on failure)
```

Automatic activation is part of connected `--new` where designed.

---

## 8. Platform self-update

Every invocation enters through the stable installed launcher. Connected **mutating** commands perform platform-current preflight.

| Control | Requirement |
|---------|-------------|
| Ed25519 signature | Mandatory (fail closed) |
| SHA256 artifact | Mandatory (fail closed) |
| Unsigned fallback | Forbidden |
| Atomic activation | Yes |
| Previous version retained | Yes |
| Lock / concurrency | Yes |
| Interrupted download | Safe (no partial activation) |
| Downgrade | Blocked |

**Distinct from ERP update:** Platform/security/compatibility self-update is allowed even if Technical Support expired. ERP product/image update requires Product Updates entitlement.

---

## 9. Resource tuning (`--tune`)

Detects CPU, RAM, swap, storage, DB/filestore size, Production/Stage counts, security overhead, host reserve; calculates Odoo, PostgreSQL, and Docker SHM settings; supports resize-up/down with checkpoint, apply, validate, rollback.

**Odoo (adaptive):** `workers` may be `> 0` on sufficiently sized hosts or `0` on small hosts. Not workers=0-only architecture.

**Topology when workers > 0:**

```text
HTTP:      127.0.0.1:8069
Evented:   127.0.0.1:8072
Nginx:     / → 8069, /websocket → 8072, /longpolling → validated backend
```

Small-host fallback: Nginx must not proxy WebSocket to a dead `:8072`.

---

## 10. PostgreSQL security

- Private Docker network only
- App role: `NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS`
- No membership in `pg_execute_server_program`, `pg_read_server_files`, `pg_write_server_files`
- Odoo admin compromise must **not** automatically imply PostgreSQL superuser, host root, or Docker control (defense-in-depth boundary)

---

## 11. Security baseline

| Control | Contract |
|---------|----------|
| Containers | No privileged, no docker.sock, no host network, NoNewPrivileges |
| Nginx | TLS termination, `nginx -t` before reload |
| Firewall | Default deny; public 22/80/443 only |
| Production outbound | Generally allowed (integrations) |
| Quarantine outbound | External egress denied |
| ClamAV | Intended baseline (complementary to YARA); operational verification required |
| YARA | Full complementary scanner (not reduced to ClamAV subset) |
| AppArmor | Enabled; never disable for compatibility |
| Fail2Ban | Verified log semantics only |
| apt locks | Wait or fail; never kill apt/dpkg or delete lockfiles |
| Malware | Quarantine, not blind delete |

See [security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md](security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md).

---

## 12. Stage

- Isolated from Production; resource limits prevent Stage exhausting Production
- Retention: default **14 calendar days**; absolute max **60 days** from creation
- Before auto-delete: final backup + Safe Shield; on failure → preserve + Needs Action
- Lifecycle: create, clone, refresh, rebuild, start, stop, status, backup, delete (per matrix)

---

## 13. Backup / restore / migration

- Backup available independent of Technical Support expiry
- Untrusted restore: quarantine → egress block → DB/YARA/ClamAV scans → promote/reject
- Migration: `--migration-*` only; source retained by default
- High-impact ops: checkpoint → change → verify → rollback if required

---

## 14. Licensing & support

- Entitlement resolver is authoritative (Stripe is a commercial origin, not the authority)
- New sales: annual or multi-year Technical Support
- Legacy monthly: existing customers only
- Product Updates entitlement is separate from Technical Support

---

## 15. Production acceptance

A new environment is not successful until verified (where applicable): HTTPS, login, least-privilege DB, WebSocket, attachments, PDF, container security, listener policy, firewall, security scanners, backup, resource headroom. Failure → **Needs Action**, not fake success.

---

## 16. Documentation hierarchy

| Document | Role |
|----------|------|
| **This file** | Product contract |
| [IMPLEMENTATION_STATUS_MATRIX.md](IMPLEMENTATION_STATUS_MATRIX.md) | Certified vs approved |
| [user/](user/) | Operator guides |
| [architecture/](architecture/) | Architecture deep-dives |
| [security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md](security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md) | Security blueprint (Soviez-adapted) |
| [evidence/](evidence/) | Historical certification (immutable) |

---

## 17. Internal compatibility surfaces (not public customer contract)

The dual Production wizard (`Soviez ERP/soviez.sh`) remains an internal/compatibility host-provisioning path during PATH CLI convergence. It is **not** a second public lifecycle customers must learn. Public documentation describes a single `soviez.sh` command installed on PATH.

Registry Gateway is an **internal** Soviez-operated service; it is not a customer-deployed component.
