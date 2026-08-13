# Migration Signed Installer Protocol

Connected: authorize → exact release → signed manifest → verify pin/signature/checksum/arch → execute exact version.  
Offline: import signed bundle → same verifies.

Forbidden: unsigned self-update, mutable `latest`, pipe-to-bash, permanent registry credentials in artifact.
