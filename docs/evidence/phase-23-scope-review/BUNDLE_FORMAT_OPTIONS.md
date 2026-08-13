# BUNDLE_FORMAT_OPTIONS

| Option | Pros | Cons |
|--------|------|------|
| tar.zst + OCI + JSON + detached sigs | Deterministic, compressible | Need path/symlink rules |
| Encrypted tar.zst | Confidentiality | Key distribution (owner) |
| Pure OCI only | Image-centric | Weak auth/docs/addons |
| Zip | Familiar | Weaker determinism; bombs |

## Recommended default
Deterministic **tar.zst** + OCI image layout + canonical JSON manifest + detached **Ed25519** signatures. Payload encryption optional (owner); if used, wrap to Device/License public material — never password-only in bundle.
