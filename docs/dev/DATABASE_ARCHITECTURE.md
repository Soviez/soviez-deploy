# Database Architecture

- Bootstrap admin role vs app role (`soviez_admin` / `soviez_app` defaults)
- App role prohibited: SUPERUSER, CREATEROLE, CREATEDB, REPLICATION, BYPASSRLS
- COPY PROGRAM / server-file access denied (S1 tests)
- Restore/migration never reintroduce SUPERUSER on rollback
- Owner: `src/database/`, `src/security/platform/*pg*`
