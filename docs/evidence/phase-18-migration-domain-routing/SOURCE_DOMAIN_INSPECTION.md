# SOURCE_DOMAIN_INSPECTION

`src/migration/domain/source_inspection.sh` collects read-only DNS/cert/health snapshot and `source_routing_fingerprint`.

- `read_only=true`, `mutated=false`
- No writes to source nginx, DNS, or certificates
- Covered by unit assertions + `SOURCE_ROUTING_NON_MUTATION` / static gate
