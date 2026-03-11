-- pgv DDL: types and infrastructure
-- Applied via pg_schema (run-once migration)

CREATE SCHEMA IF NOT EXISTS pgv;

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
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT USAGE ON SCHEMA pgv TO web_anon;
