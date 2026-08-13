# New Instance Connected Activation Model

**Status:** Implemented (Phase 8 foundation) — **PARTIAL**  
**Verdict:** Modular `--new` installer wired; auto/manual paths certified with mock SaaS + ORM stub. Full disposable Odoo ERP container E2E **not** exercised in certification environment.  
**Repos:** `soviez-sh` (`src/`, `build/assemble.sh`, `dist/soviez.sh` v0.8.0-phase8); Phases 5–7 SaaS APIs consumed as-is; `local_license_guard` **not modified**.  
**Weight:** 7 — **not awarded** until full PASS (cumulative remains **31%**).

---

## Objective

Deliver a **sovereignty-first connected new-instance flow** that:

1. **Modular installer** — `src/` modules assembled into `dist/soviez.sh` by `build/assemble.sh`.
2. **Explicit consent** — user approves each connected operation before egress.
3. **Device authorization** — Phase 5 browser-assisted PoP for all SaaS calls.
4. **License Slot reservation** — Phase 6 atomic reserve → provision → issue → ack lifecycle.
5. **Private image pull** — Phase 7 digest-pinned pull session with temp docker config.
6. **Tenant provisioning** — identity, database, container, optional domain/SSL.
7. **Fingerprint binding** — hardware+UUID compound fingerprint aligned with `local_license_guard`.
8. **Automatic activation** — official `action_activate_soviez_license` ORM path; key never in argv/logs.
9. **Manual activation preserved** — ends in `completed_activation_pending`; user activates via portal later.
10. **Disconnect/resume** — `--reattach` continues from persisted operation state.

---

## Non-goals (Phase 8)

| Item | Deferred to |
|------|-------------|
| `--init` activation | Out of scope (D003: auto on `--new` only) |
| Live Supabase / production SaaS E2E | Owner environment |
| Full disposable Odoo ERP container ORM E2E | Certification gap (PARTIAL reason) |
| Let's Encrypt production cutover | Phase 12 |
| `local_license_guard` changes | Explicitly forbidden |
| Commit / push / deploy | Owner authorization |

---

## Sovereignty boundaries

| Boundary | Rule |
|----------|------|
| **Running ERP** | Never requires continuous SaaS after activation. Connected ops are explicit user-started. |
| **Business data** | No database, filestore, or accounting data leaves the server during `--new`. |
| **Activation keys** | Never in process argv, shell history, or logs. Staged via stdin→0600 file inside container; wiped after ORM call. |
| **Device private keys** | Local only (`/etc/soviez/device/` planned paths); never transmitted. |
| **Registry credentials** | Temp docker `--config` only; deleted after pull. |
| **Consent** | Connection disclosure before first SaaS call; auto-consent only in `SOVIEZ_TEST_MODE`. |
| **Revocation** | Device revoke blocks future connected ops only — does not stop running ERP. |
| **Manual path** | User may defer activation; slot progresses to `completed_activation_pending`. |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  soviez.sh --new  (dist assembled from src/)                    │
├─────────────────────────────────────────────────────────────────┤
│  preflight → consent → device auth → slot reserve               │
│       → release resolve → manifest verify → pull session        │
│       → tenant identity → DB → container → domain/SSL (opt)     │
│       → fingerprint bind → license issue                        │
│       → [automatic: ORM activate + ack] | [manual: pending]     │
└───────────────┬─────────────────────────────────────────────────┘
                │ Device PoP HTTPS
                ▼
┌───────────────────────────────────────────────────────────────────┐
│  soviez-saas  /api/installer-auth/*  /api/installer/slots/*     │
│               /api/installer/registry/*                           │
└───────────────────────────────────────────────────────────────────┘
                │ pull ticket
                ▼
┌───────────────────────────────────────────────────────────────────┐
│  registry-gateway  (Phase 7) — OCI blob streaming                │
└───────────────────────────────────────────────────────────────────┘

Automatic activation (production path):
  docker exec -i  → stage key to /tmp/.soviez_activate_$$ (0600)
  odoo shell -d DB  → env["soviez.license.mixin"].action_activate_soviez_license(key)
  rm staging file
```

**Module assembly:** `build/assemble.sh` concatenates 36 `src/` modules in dependency order. **Do not edit `dist/soviez.sh` directly.**

---

## Operation state machine

States defined in `src/operations/state_machine.sh` and `schemas/new_operation_state.schema.json`.

**Happy path (automatic):**

`created → preflight → waiting_for_connection_consent → device_authorization_pending → device_authorized → slot_reserved → release_resolved → image_pull_authorized → image_pulled → tenant_identity_created → database_provisioned → container_started → [domain_pending → waiting_for_dns → ssl_pending →] instance_provisioned → fingerprint_bound → waiting_for_activation_method → license_issued → activation_pending → activated → validating → completed`

**Happy path (manual):**

Same through `license_issued → activation_pending → manual_activation_pending → completed_activation_pending`

**Recovery states:** `failed_retryable`, `recovery_required`, `failed_terminal`, `canceled`

**Resume:** `--reattach <operation-id>` re-enters at last persisted state; idempotent step guards via `soviez_sm_should_run_step`.

---

## Activation paths

### Automatic (default)

1. User selects `--activation automatic` (or default).
2. SaaS issues activation key via `/api/installer/slots/issue-license`.
3. Key stored locally at `0600` via `soviez_tenant_secret_write`.
4. `soviez_license_activate_via_odoo` invokes official ORM method.
5. Activation ack sent to SaaS (`/api/installer/slots/activation-ack`).
6. Terminal state: `completed`.

### Manual

1. User selects `--activation manual`.
2. License issued; key stored locally.
3. ORM activation **skipped**.
4. Terminal state: `completed_activation_pending`.
5. User completes activation via customer portal (existing offline verification path).

---

## ORM activation contract (binding)

Implementation: `src/license/activate_orm.sh`

| Rule | Enforcement |
|------|-------------|
| Official method only | `env["soviez.license.mixin"].action_activate_soviez_license(key)` |
| No argv key | Key piped via stdin into container staging file |
| Staging permissions | `umask 077`; `chmod 600` on remote file |
| Cleanup | File overwritten and unlinked before and after ORM call |
| No log leakage | `soviez_redact_text`; events.jsonl audited in tests |
| Test stub | `SOVIEZ_ODOO_STUB` or `SOVIEZ_TEST_MODE=1` marker files (no key written) |

**Certification gap:** Stub/`SOVIEZ_TEST_MODE` + `license_tools` fingerprint certification exercised. Full live Odoo container with real `odoo shell` ORM call **not** run in this environment.

---

## Phase integration matrix

| Phase | Integration in `--new` |
|-------|---------------------|
| **5 Device auth** | `soviez_device_client_start/authorize`; PoP on all SaaS calls |
| **6 Slot reservation** | Full reserve → provision → bind → issue → ack chain |
| **7 Registry pull** | Resolve release, verify manifest, pull session, digest-pinned pull |
| **Guard (read-only)** | Fingerprint format certified via `license_tools.py`; guard **not modified** |

---

## Data egress (`new-instance/v1`)

Per connected step, disclosed before send:

| Step | Egress class | Payload (application) |
|------|--------------|----------------------|
| Device auth start | `device-egress/v1` | Public key, fingerprint, label, nonce |
| Slot reserve/issue/ack | `slot-reservation/v1` | operation_id, idempotency_key, fingerprint, activation_method |
| Registry resolve/pull | `registry-pull/v1` | release_id, digest, architecture, PoP headers |

**Never transmitted:** activation keys, device private keys, business DB/filestore, passwords.

---

## Failure and recovery

| Failure | Behavior |
|---------|----------|
| Network drop mid-op | `--reattach` resumes from persisted state |
| Pull failure | State → `failed_retryable`; temp docker config cleaned |
| ORM activation failure | Staging file removed; state → `failed_retryable` |
| Slot TTL expiry (pre-provision) | SaaS-side hold released; op must restart |
| Manual path | No ORM failure possible; ends `completed_activation_pending` |

---

## Test certification summary

| Gate | Result |
|------|--------|
| `tests/run_all.sh` (6 unit + 5 integration) | **PASS** |
| `bash -n dist/soviez.sh` | **PASS** |
| ShellCheck | **UNAVAILABLE** on certification host |
| Auto path (mock SaaS + ORM stub) | **PASS** |
| Manual path (mock SaaS) | **PASS** |
| Disconnect/resume | **PASS** |
| Local CA SSL | **PASS** |
| Cleanup boundaries | **PASS** |
| Secret handling audit | **PASS** |
| Guard regression (no guard edits) | **PASS** (fingerprint cert; import requires `SOVIEZ_MIGRATION_SECRET`) |
| Full Odoo container ORM E2E | **NOT RUN** |

---

## Explicit exclusions

- Live production SaaS migrate
- Real Docker Hub pull against private cutover
- Let's Encrypt production issuance
- `local_license_guard` source changes
- Commit / push / deploy

---

## Evidence

`docs/evidence/phase-08-new-connected-activation/FINAL_REPORT.md`

Protocol: `docs/dev/NEW_COMMAND_PROTOCOL.md`
