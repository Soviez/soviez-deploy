# Stage License (Stage Environments)

Stage License is an **optional monthly add-on** linked to one specific **License** on your account. It lets you **create new Stage environments** for that License (clone, refresh, rebuild when the runtime phase ships).

---

## What you get

| Included | Description |
|----------|-------------|
| Stage creation entitlement | Permission to run gated Stage operations for the covered License |
| Unlimited commercially | No per-License Stage count cap in billing — your server resources limit how many Stages you can run |
| Exact License binding | Coverage applies only to the License you purchase for — not your whole account |

---

## What Stage License does **not** do

Stage License expiration **does not**:

- Stop, delete, or block access to **existing** Stage environments
- Shut down your production Soviez ERP
- Block backup, restore, or local Stage lifecycle commands (list, status, stop, backup, drop)

When coverage ends, you can no longer **create** new Stages until you renew. Existing Stages keep running until you manage them locally or a future retention policy applies.

---

## Operation authorization (Phase 10.5 + 11)

Creating a Stage requires **operation authorization** (a short-lived Stage Operation Ticket) in addition to an active Stage License. Authorization sends only **minimal licensing metadata** (license/device/host fingerprints, digests, stage identity) — **no business data**.

After a Stage is created:

- It continues to run **offline** without continuous contact with Soviez Cloud.
- An **expired Stage License does not stop or delete** existing Stages.
- Private Stage tooling may include a **pseudonymous delivery ID** used only to attribute redistributed copies — not a phone-home beacon.
- A server administrator with **full root access can bypass local software checks**. Soviez does **not** claim unbreakable DRM.

Installer runtime: see [STAGE_ENVIRONMENTS.md](STAGE_ENVIRONMENTS.md) (`soviez.sh --stage`).

---

## Stage runtime (Phase 11)

`--stage` creates isolated Stage containers, dedicated networks, domains with **trusted** HTTPS, neutralized clones, and local origin certificates. Multiple Stages may exist for one License (server resources permitting). Retention auto-delete is **not** implemented yet — see [STAGE_RETENTION.md](STAGE_RETENTION.md).

---

## How to purchase

1. Sign in to the Soviez customer portal.
2. Open **Support** and find **Stage Environments**.
3. Select the **License** you want to cover.
4. Click **Purchase Stage License** — the portal fetches a server quote and redirects to secure checkout (monthly subscription).

You can also contact support for admin-granted or offline settlement options.

---

## Related documents

- [Stage retention policy (boundary)](STAGE_RETENTION.md) — not yet implemented
- [Privacy and sovereignty](PRIVACY_AND_SOVEREIGNTY.md)
- [Annual Technical Support](ANNUAL_SUPPORT.md)
