# PUBLICATION_MANIFEST

Authoritative per-file TSV for soviez-sh: `_manifest_soviez_sh.tsv` (generated this audit).

## Counts

| Repo | Publishable files (classified) | Notes |
|------|-------------------------------:|-------|
| soviez-sh | **3043** | {'PUBLISH_REQUIRED': 833, 'GENERATED_ARTIFACT': 2, 'CANONICAL_DOCUMENTATION': 402, 'CERTIFICATION_EVIDENCE': 1806} |
| Soviez ERP | **1** | `soviez.sh` only for this cycle |
| soviez-deploy | **1** | `soviez.sh` only |
| soviez-saas | **~161+** lifecycle-expanded files (API/libs/migrations/admin surfaces); UI review set separate | See SAAS_PUBLICATION_SCOPE.md |

## soviez-sh — classification summary

| Classification | Count | Must publish? |
|---------------|------:|---------------|
| PUBLISH_REQUIRED | 833 | YES |
| GENERATED_ARTIFACT | 2 | YES (`dist/soviez.sh` + `.sha256`) |
| CANONICAL_DOCUMENTATION | 402 | YES |
| CERTIFICATION_EVIDENCE | 1806 | Policy: PUBLISH_SUMMARY_ONLY recommended for bulk; keep gate summaries (see EVIDENCE_PUBLICATION_POLICY.md) |
| UNKNOWN_PROVENANCE (in publish set) | **0** | N/A |

### Representative publishable entries (not exhaustive)

| repository | relative path | classification | owning feature | why | dependency | kind |
|------------|---------------|----------------|----------------|-----|------------|------|
| soviez-sh | `VERSION` | PUBLISH_REQUIRED | versioning | cert version 0.24.5.2-postcert-corr1 | none | runtime-meta |
| soviez-sh | `dist/soviez.sh` | GENERATED_ARTIFACT | installer | certified artifact SHA `af5b6c09ece36fd9a6a9b89cdcac09a16880bfeaff4619f821812dd99497359c` | built from `src/` | generated |
| soviez-sh | `dist/soviez.sh.sha256` | GENERATED_ARTIFACT | installer | hash sidecar | dist | generated |
| soviez-sh | `src/**` | PUBLISH_REQUIRED | lifecycle/security | modular runtime S1–S6 + post-cert | saas APIs | runtime |
| soviez-sh | `tests/**` | PUBLISH_REQUIRED | certification | regression + phase25 | none | test |
| soviez-sh | `tools/**` | PUBLISH_REQUIRED | tooling | docs_validate, secret_scan, assemble | none | tools |
| soviez-sh | `docs/README.md` + `docs/user|dev|ai|security/**` | CANONICAL_DOCUMENTATION | docs | D128 canonical portal | code | docs |
| soviez-sh | `docs/evidence/phase-25-final-certification/**` | CERTIFICATION_EVIDENCE | P25 | certification claims | none | evidence |
| soviez-sh | `docs/evidence/post-cert-discrepancy-closure/**` | CERTIFICATION_EVIDENCE | D129 | post-cert proof | wizards | evidence |
| Soviez ERP | `soviez.sh` | PUBLISH_REQUIRED_CROSS_REPO | dual-wizard | Stage proxy_mode, workers=0, WS/longpoll | must match deploy | runtime |
| soviez-deploy | `soviez.sh` | PUBLISH_REQUIRED_CROSS_REPO | dual-wizard | byte-identical to ERP wizard | must match ERP | runtime |
| soviez-saas | `supabase/migrations/078–090_*.sql` | PUBLISH_REQUIRED_CROSS_REPO | schema | entitlements/device/registry/stage/migration/offline | installer contracts | schema |
| soviez-saas | `src/lib/{device-auth,entitlements,registry,stage-*,migration-*,offline-bundle,slot-reservation,commercial,annual-support}/**` | PUBLISH_REQUIRED_CROSS_REPO | control-plane | SaaS APIs used by installer | soviez-sh | runtime |
| soviez-saas | `src/app/api/installer*/**` + stage/support/checkout stage routes | PUBLISH_REQUIRED_CROSS_REPO | control-plane | installer-facing HTTP | soviez-sh | runtime |

Full soviez-sh path list: `_manifest_soviez_sh.tsv` (3043 rows).
