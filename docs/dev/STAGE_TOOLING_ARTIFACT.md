# Stage Tooling Artifact (Phase 10.5)

**Status:** Foundation / fixture  
**Packaging decision:** `signed_package` (smallest private artifact)  
**Distribution:** Phase 7 private registry, **digest-pinned** — not public tags  
**Helper package:** `soviez-sh/services/stage-operation-helper`  
**Also see:** `services/stage-operation-helper/ARTIFACT.md`

---

## 1. Purpose

Deliver a private, independently versioned **Stage tooling** artifact that:

- Verifies Stage Operation Tickets (`soviez.stage-operation.v1`)
- Certifies neutralization controls
- Writes Stage-origin certificates locally
- Carries a pseudonymous `delivery_trace_id` for leak attribution

It does **not** contain private signing keys, Hub credentials, customer secrets, or business data.

---

## 2. Layout (signed_package)

```text
soviez-stage-tooling/
  MANIFEST.json           # digest-pinned metadata + delivery_trace_id
  bin/soviez-stage-helper # Node TS verifier (public keys only)
  neutralization/         # controls schema / fixtures
  README.txt              # disclosure: leak attribution ID; no telemetry
```

Packaging enum (migration `086` / catalog): `oci_artifact` | `oci_sidecar` | `signed_package` | `helper_container`.  
**Chosen for 10.5 fixture:** `signed_package`.

---

## 3. Digest pinning

- Tooling digests are approved in `stage_tooling_artifacts` (SaaS).
- Tickets bind `tooling_artifact_id` + `tooling_digest`.
- Mismatch → `TOOLING_NOT_APPROVED`.
- Architecture-specific builds when native binaries are required.
- Independently versioned from Production ERP image digests.

**Test fixture digest:**

```text
sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

---

## 4. Privacy disclosure (shipping README)

Private tooling may include a **pseudonymous delivery ID** (`delivery_trace_id`) used only to attribute redistributed copies. It is not a phone-home beacon. No name, email, or business data is embedded for telemetry.

---

## 5. Trust and residual risk

- Helper verifies with **public keys only**.
- Full Root can replace the binary — residual risk (see threat model).
- Soviez does not claim unbreakable DRM.

---

## 6. Phase boundary

Artifact and helper exist and are **wired by Phase 11** `--stage` (verify / neutralize / origin cert).  
Runtime pull of private tooling on live Hub remains environment-dependent; fixture digests used in certification. Phase 12 unauthorized.
