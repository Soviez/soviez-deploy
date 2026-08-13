# Reproducibility model

## Must prove in Phase 25
- Source-to-artifact mapping (module list + digests → dist SHA)
- Artifact SHA stability across identical clean assemble inputs **when dirty inventory is frozen**
- Release-manifest fields bind to exact artifact SHA + version
- Offline bundle builds (when revalidated) bind digests + signatures

## Need not claim
- Bit-identical rebuilds across different hosts/toolchains without pinned tool versions
- Git commit reproducibility when no commit exists

## Pass rule
If dirty tree changes between assemble and certification, **FAIL** `FINAL_CERT_ARTIFACT_MISMATCH` / provenance incomplete unless re-assembled and inventory updated.
