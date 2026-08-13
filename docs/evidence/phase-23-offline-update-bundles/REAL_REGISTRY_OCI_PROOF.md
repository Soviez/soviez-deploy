# REAL_REGISTRY_OCI_PROOF

Suite: `tests/integration/test_phase23_real_registry_oci.sh`

Proves (disposable localhost Registry:2 + docker save OCI fallback when skopeo absent):
- private Registry fixture labeled `soviez.phase23.disposable=1`
- exact image digest recorded (sha256:…, not tag trust)
- ephemeral `DOCKER_CONFIG` created and removed (credential cleanup)
- OCI payload packaged into signed offline bundle
- secret scan: no private keys / Docker auths / registry passwords in bundle
- offline import verifies Phase 23 bundle with digest

Updated by authoritative certification run.
