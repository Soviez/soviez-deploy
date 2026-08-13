# Offline operation

## Existing

Manual activation (fingerprint → Cloud key when you can reach the portal → paste) and fully offline runtime after activation.

## Phase 7 — offline image bundles (foundation)

For air-gapped or disconnected installs, Soviez is building toward **signed offline image bundles**:

| Property | Detail |
|----------|--------|
| **Signed metadata** | Release manifest domain `soviez.release-manifest.v1` — verifiable without calling SaaS. |
| **Digest pinned** | Bundle declares exact `sha256:…`; archive checksum verified locally. |
| **No Hub required at verify** | Signature and checksum checks run on your server. |
| **No permanent Docker cred** | Offline path does not store Hub org tokens. |

Full distribution and installer import workflow is planned for a later phase. Phase 7 delivers the verification contract only.

## Running ERP when Cloud or registry is unavailable

**Confirmed:** An activated Soviez ERP instance does **not** need Soviez Cloud or the private registry to keep running. Loss of connectivity affects only operations you explicitly start that require the network (e.g. a new image pull, slot reservation, or device-linked API call).

## Planned

Signed offline installer/entitlement/update bundles and offline migration receipt exchange for isolated networks (Phase 23 and related).
