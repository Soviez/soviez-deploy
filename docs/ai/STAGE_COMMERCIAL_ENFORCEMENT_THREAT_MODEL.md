# Stage Commercial Enforcement Threat Model (Phase 10.5)

**Status:** IN PROGRESS (foundation implemented; Phase 11 runtime unauthorized)  
**Honesty posture:** Commercial hardening and leak attribution — **not** unbreakable DRM.  
**Related:** `STAGE_OPERATION_AUTHORIZATION_MODEL.md`, `docs/dev/STAGE_OPERATION_TICKET_PROTOCOL.md`, evidence pack `phase-10-5-stage-commercial-hardening/`.

---

## 1. Objective

Raise the cost of unauthorized Stage creation and Stage tooling redistribution while preserving Sovereignty First:

- Ticket expiry gates **START** of gated operations only.
- Expired Stage License does **not** stop or delete existing Stages.
- No continuous phone-home; no business-data egress.
- Full Root on the customer host can replace local software — residual risk is documented, not denied.

---

## 2. Assets

| Asset | Sensitivity | Notes |
|-------|-------------|-------|
| Stage Operation Ticket (signed) | High | Short-lived; binds license/device/host/FP/DB/stage/domain/release/tooling/arch/op |
| Stage Operation private signing key | Critical | SaaS-only; never in helper package |
| Approved tooling digests | High | Private registry; digest-pinned |
| Offline authorization package | High | One-use; local ledger |
| Stage-origin certificate | Medium | Local evidence; no phone-home |
| `delivery_trace_id` | Low–Med | Pseudonymous leak attribution only |
| `subject_pseudonym` | Low–Med | License-derived hash — not name/email/business data |
| Neutralization result | Medium | Certified controls before Stage acceptance |

---

## 3. Adversaries

| Adversary | Capability | Primary risk |
|-----------|------------|--------------|
| Unentitled customer | Valid device, no Stage License | Attempt gated ops without entitlement |
| Entitled customer oversharing tooling | Distributes helper/artifact | Leak of private tooling |
| Compromised device credential | Stolen PoP key | Authorize ops for wrong host if bindings fail |
| Network observer | Sees HTTPS metadata | Metadata only if disclosure violated |
| Full Root on Stage host | Replace verifier, rewrite ledger | Bypass local enforcement |
| AI-assisted attacker | Script ticket replay / binding fuzz | Replay, binding mismatch, ledger wipe |
| Insider SaaS misuse | Abuse service-role / keys | Cross-account authorize |

---

## 4. Trust boundaries

```
[SaaS signing + entitlement]  --ticket-->  [Device PoP client]
        |                                        |
        | offline package                        v
        +---------------------------->  [stage-operation-helper]
                                                 |
                                                 v
                                        [Local ledger + origin cert]
                                                 |
                                                 v (Phase 11 — NOT this phase)
                                        [Stage containers / --stage]
```

- **SaaS** trusts Device Auth + Stage License entitlement + binding fields.
- **Helper** trusts public keys only; verifies `soviez.stage-operation.v1`.
- **Bash/installer** must not certify Stages by flipping a local Boolean (future Phase 11 contract).
- **Root** is outside the trust model for local integrity.

---

## 5. Controls (implemented or designed this phase)

| Control | Mechanism |
|---------|-----------|
| Separate signing domain | `soviez.stage-operation.v1` ≠ Device Auth, License, release-manifest, registry pull, Migration HMAC, Stripe |
| Binding matrix | license, device, host pubkey fp, production FP, DB UUID, stage ID, domain, release digest, tooling digest, arch, operation |
| Short ticket TTL | Gates START only (`exp`); does not stop running Stages |
| Online lifecycle | authorize → consume → complete; status; revoke unused |
| Offline package + local ledger | One-use consumption; Root can tamper (residual) |
| Digest-pinned tooling | Private registry; fixture `sha256:aaa…a` for tests |
| Traceability | `delivery_trace_id` + `subject_pseudonym` only |
| Neutralization certification | Explicit control map; fail closed |
| Origin certificate | Local file; survives entitlement expiry; no phone-home |

---

## 6. Residual risks (accepted)

1. **Full Root replaces helper** — local checks bypassed; detectable/deterrable via digests and origin cert absence, not cryptographically prevented.
2. **Root rewrites local consumption ledger** — offline replay possible on that host.
3. **Stolen Stage Operation private key** — catastrophic; key separation + rotation required (ops).
4. **AI-assisted binding fuzz** — mitigated by strict assertBindings + denial codes; not zero-day proof.
5. **Tooling redistribution** — `delivery_trace_id` attributes delivery, does not remotely disable copies.

---

## 7. Explicit non-claims

- Not unbreakable DRM.
- Not a continuous kill-switch for Stages.
- Not Phase 11 runtime, `--stage` wiring, Stage containers, or `local_license_guard` change.
- Ticket expiry ≠ Stage runtime expiry.

---

## 8. Evidence

See `docs/evidence/phase-10-5-stage-commercial-hardening/` (stubs; parent fills test numbers).
