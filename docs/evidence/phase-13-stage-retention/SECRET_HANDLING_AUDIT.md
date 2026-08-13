# Secret Handling Audit
Retention final backups remain on the customer host. Runtime logs and tombstones do not include Stage secrets, private keys, activation keys, ticket tokens, database contents, or filestore contents.

Tombstone license reference is abbreviated. Backup evidence stores path and checksum only. No retention code sends data to SaaS or another remote endpoint.
