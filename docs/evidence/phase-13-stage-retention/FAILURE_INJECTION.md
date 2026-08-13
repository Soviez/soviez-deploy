# Failure Injection
Tested injected failures include final backup, checksum, Safe Shield collision, stop/Nginx/database/filestore removal, and deadline metadata beyond immutable maximum.

Observed contract: backup/Shield/metadata failures preserve the Stage and need action; destructive-step failure records recovery-required; retry/reattach continues safely. No test failure targets Production.
