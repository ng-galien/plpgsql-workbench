-- pgv DDL: types and infrastructure
-- Applied via pg_schema (run-once migration)

CREATE SCHEMA IF NOT EXISTS pgv;

-- Domain text/html for PostgREST HTML content negotiation
DO $$ BEGIN
  CREATE DOMAIN "text/html" AS TEXT;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Search result type: convention for module search providers
-- Each module implements: {schema}.search(p_query text, p_limit int, p_offset int) -> SETOF pgv.search_result
DO $$ BEGIN
  CREATE TYPE pgv.search_result AS (
    href    text,    -- link to entity page (e.g. /factures?id=42)
    icon    text,    -- emoji or raw HTML icon
    kind    text,    -- entity type label (facture, client, document...)
    label   text,    -- primary display text
    detail  text,    -- secondary text / description
    score   real     -- relevance score 0.0-1.0 for sorting
  );
EXCEPTION WHEN duplicate_object OR unique_violation THEN NULL;
END $$;

-- i18n translations
CREATE TABLE IF NOT EXISTS pgv.i18n (
  lang  text NOT NULL,
  key   text NOT NULL,
  value text NOT NULL,
  PRIMARY KEY (lang, key)
);

-- FTS: French stemming + unaccent
CREATE EXTENSION IF NOT EXISTS unaccent;

DO $$ BEGIN
  CREATE TEXT SEARCH CONFIGURATION pgv_search (COPY = french);
  ALTER TEXT SEARCH CONFIGURATION pgv_search
    ALTER MAPPING FOR hword, hword_part, word
    WITH unaccent, french_stem;
EXCEPTION WHEN duplicate_object OR unique_violation THEN NULL;
END $$;

GRANT USAGE ON SCHEMA pgv TO anon;
GRANT SELECT ON pgv.i18n TO anon;
