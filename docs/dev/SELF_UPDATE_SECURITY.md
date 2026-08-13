# Self-Update Security

Legacy unsigned curl|bash self-update is absent from `src/` and `dist/soviez.sh`.

Installer updates use the signed release/offline bundle path: fetch → verify manifest/signature/purpose/digest/target → stage → atomic replace. Never execute before verification.
