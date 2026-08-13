# Signature path inventory

| Path | Gate | Production policy |
|------|------|-------------------|
| Connected release resolve/assert | `soviez_update_release_assert` + security adapters | fail-closed signed |
| Offline package import (P15) | `soviez_update_offline_import` | fake-sig denied unless bypass / engine reuse |
| Offline bundle import (P23) | `soviez_offline_trust_verify_json_file` | fake-sig denied unless bypass |
| Migration offline import | `soviez_migration_offline_import` | unsigned only with bypass triple |
| Self-update curl\|bash | ABSENT | N/A — denied by absence |
