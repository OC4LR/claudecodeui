-- 01-init.sql: Create dev database and user for local development
-- Runs once on first PostgreSQL initialization (marker-based tracking)

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'dev') THEN
        CREATE ROLE dev WITH LOGIN SUPERUSER CREATEDB CREATEROLE;
        RAISE NOTICE 'Created role: dev';
    END IF;
END
$$;

SELECT 'CREATE DATABASE dev OWNER dev'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dev')\gexec

GRANT ALL PRIVILEGES ON DATABASE dev TO dev;
