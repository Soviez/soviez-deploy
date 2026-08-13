# Artifact provenance model

Because the tree may be dirty and uncommitted, provenance **must not** claim a Git commit SHA as sole identity.

## Required fields
```text
repository_path
git_head (or "none"/unborn)
dirty_state = true|false
changed_file_digest_inventory (path → sha256 of file contents)
generated_source_manifest (assemble module list + module digests)
installer_version
artifact_sha256
certification_run_id
timestamp_utc
host_environment (os, arch, docker/colima identity)
test_runner = phase25_final_certification / tests/run_all.sh
phase24_baseline_sha = c0bb0e3e2130243387d58c11c153abd8506deaa9ecc77322cfbada077816b0b7
```

## Mapping
```text
source identity (dirty-tree inventory)
→ generated installer
→ artifact SHA256
→ release manifest (if any)
→ certification evidence
```
