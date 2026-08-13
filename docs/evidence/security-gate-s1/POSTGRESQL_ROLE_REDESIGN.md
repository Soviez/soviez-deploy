# PostgreSQL role redesign

Bootstrap: soviez_admin (superuser via image)
App: soviez_app — LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS
DB owner = soviez_app; schema public granted to app
CREATEDB default: NO (Soviez provisions DB)
