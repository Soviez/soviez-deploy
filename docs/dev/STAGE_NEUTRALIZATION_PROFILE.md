# Stage Neutralization Profile (Phase 11)

**Status:** Implemented — PASS  
**Orchestration:** `src/stage/neutralization.sh`  
**Certification:** `soviez-stage-helper neutralize` (Phase 10.5)

---

## 1. Purpose

Prevent a Stage clone of Production from acting as Production: no customer emails, payments, webhooks, or production callbacks. Neutralization is a **certification gate** — without helper approval the Stage is not completed.

---

## 2. Controls list

| Control key | Required true |
|-------------|---------------|
| `outgoing_email_disabled` | Yes |
| `sms_disabled` | Yes |
| `payment_providers_disabled` | Yes |
| `webhooks_disabled` | Yes |
| `external_cron_isolated` | Yes |
| `production_url_callbacks_blocked` | Yes |
| `stage_identity_marker_set` | Yes |
| `database_is_neutralized_flag` | Yes |

Applied by ERP/`soviez-bin neutralize` (or test fixtures writing `neutralization.env`). Helper reads the controls JSON and emits a certification artifact.

---

## 3. Must-disable classifications

| Class | Examples | Stage requirement |
|-------|----------|-------------------|
| Outbound messaging | SMTP, SMS gateways | Disabled |
| Money movement | Payment acquirers / providers | Disabled |
| External push | Webhooks, production URL callbacks | Disabled / blocked |
| Unscoped automation | External cron hitting Production endpoints | Isolated |
| Identity | `soviez.stage_id`, `database.is_neutralized` | Must be set |

---

## 4. Certification

1. Bash applies / invokes neutralize in Stage context.
2. Bash collects controls JSON (`soviez_stage_neutralize_controls_json`).
3. Helper `neutralize --claims --controls --cert-out` returns `ok: true` or denies.
4. Failure → `NEUTRALIZATION_FAILED`; Stage must not reach `completed` / origin cert.

**Bash Boolean alone is insufficient.** Skipping the helper leaves an uncertified Stage.

---

## 5. Limitations

- Full Root can replace helper or forge local control files after replacement — residual risk, not DRM.
- Test mode uses fixture env files + real helper binary; live path uses `docker exec … soviez-bin neutralize`.
- Deep ERP module-by-module audit of every third-party connector is best-effort via the neutralize CLI; unknown future connectors may need profile updates.
- Neutralization does not encrypt or wipe Production data — it only configures the Stage clone.

---

## 6. Retention banner (Phase 13)

The neutralized Stage config receives local `retention-banner.txt` and `retention-banner.html` with an English status message:

`Stage environment · Neutralized · <daily countdown>`

It also shows scheduled deletion date, timezone or extension limit, and—when Safe Shield/backup/deletion cannot safely proceed—**Deletion overdue — Needs Action** with a data-protection explanation. The banner is derived from local retention metadata; it is not telemetry and does not depend on entitlement.
