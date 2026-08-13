# Secret handling audit
- Passphrase via env/file; S3 keys in 600 secret files; SFTP identity file refs
- Profiles scrubbed of secrets; redaction on die messages
- Test: `tests/security/test_phase16_secret_handling.sh` PASS
