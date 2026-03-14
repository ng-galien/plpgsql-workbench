-- PostgREST roles + text/html domain for pgView
-- Aligned with Supabase conventions (anon, authenticated)
-- Run once on fresh DB (idempotent via DO blocks)

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

-- Anonymous role (Supabase convention: anon)
DO $$ BEGIN
  CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Authenticated role (Supabase convention: authenticated)
DO $$ BEGIN
  CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT anon TO authenticator;
GRANT authenticated TO authenticator;

-- pgv schema (always needed — SSR framework)
CREATE SCHEMA IF NOT EXISTS pgv;
GRANT USAGE ON SCHEMA pgv TO anon, authenticated;
