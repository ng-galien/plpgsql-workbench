-- Roles, domain, schemas
DO $$ BEGIN CREATE DOMAIN "text/html" AS TEXT; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'authenticator'; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE web_anon NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
GRANT web_anon TO authenticator;

CREATE SCHEMA IF NOT EXISTS pgv;
GRANT USAGE ON SCHEMA pgv TO web_anon;

CREATE SCHEMA IF NOT EXISTS docstore;
GRANT USAGE ON SCHEMA docstore TO web_anon;

CREATE SCHEMA IF NOT EXISTS docman;
GRANT USAGE ON SCHEMA docman TO web_anon;
