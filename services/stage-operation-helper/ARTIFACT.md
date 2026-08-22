# Stage tooling artifact fixture (Phase 10.5)

Packaging decision: **signed_package** (smallest private artifact).

```text
soviez-stage-tooling/
  MANIFEST.json          # digest-pinned metadata + delivery_trace_id placeholder
  bin/soviez-stage-helper  # verifier/helper (public keys only)
  neutralization/controls.json schema
  README.txt             # disclosure: leak attribution ID; no telemetry
```

- Obtained via Phase 7 private registry / digest pin — not public tags.
- Contains no private signing keys, no customer secrets, no Hub credentials.
- Architecture-specific builds when native binaries are required.
- Independently versioned from Production ERP image.

Digest fixture (tests only):

`sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`
