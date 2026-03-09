-- PostgREST roles + text/html domain for pgView
-- Run once on fresh DB (idempotent via IF NOT EXISTS / DO blocks)

-- Domain that makes PostgREST return raw HTML (Content-Type: text/html)
DO $$ BEGIN
  CREATE DOMAIN "text/html" AS TEXT;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Authenticator role (PostgREST connects as this)
DO $$ BEGIN
  CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'authenticator';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Anonymous role (unauthenticated requests)
DO $$ BEGIN
  CREATE ROLE web_anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT web_anon TO authenticator;

-- App schema (public-facing functions live here)
CREATE SCHEMA IF NOT EXISTS app;
GRANT USAGE ON SCHEMA app TO web_anon;

-- pgv schema (reusable UI primitives)
CREATE SCHEMA IF NOT EXISTS pgv;
GRANT USAGE ON SCHEMA pgv TO web_anon;

-- docman schema (document management)
CREATE SCHEMA IF NOT EXISTS docman;
GRANT USAGE ON SCHEMA docman TO web_anon;

-- docstore schema (file index)
CREATE SCHEMA IF NOT EXISTS docstore;
GRANT USAGE ON SCHEMA docstore TO web_anon;

-- workbench.config access for app settings page
GRANT USAGE ON SCHEMA workbench TO web_anon;
GRANT SELECT, INSERT, UPDATE ON workbench.config TO web_anon;
