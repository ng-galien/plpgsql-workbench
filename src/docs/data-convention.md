---
topic: data-convention
---
# Convention data_* — Query API for pgv.table()

## Overview

`data_*` functions serve JSON datasets for the `pgv.table()` Alpine plugin.
They handle filtering, search (FTS), and server-side pagination.

Convention: `get_*` = HTML pages, `post_*` = actions, `data_*` = JSON datasets.

## Signature

  data_{resource}(p_params jsonb DEFAULT '{}') RETURNS jsonb

Always jsonb in, jsonb out. One signature, no ambiguity.

## Input parameters (p_params)

Three namespaces in the same object:

  Prefix   Role                              Examples
  -------  --------------------------------  -----------------------
  p_*      Business filters (exact match)    p_status, p_from, p_type
  q        Full-text search (FTS)            q
  _*       Meta (pagination)                 _page, _size

Example:

  {"p_status": "new", "p_from": "lead", "q": "facture", "_page": 1, "_size": 20}

Rules:
- p_* = WHERE exact match (NULL = no filter)
- q = WHERE FTS via search_vec @@ plainto_tsquery
- _page = 1-based, default 1
- _size = page size, default 20

## Output format

  {
    "total": 142,
    "page": 1,
    "size": 20,
    "rows": [
      [1, "lead", "pgv", "new", "2026-03-13 14:30"],
      [2, "ops", "cad", "resolved", "2026-03-12 10:15"]
    ]
  }

- No `cols` in response — columns declared in pgv.table() config
- rows = array of arrays, order matches cols in config
- total = count before pagination (for page count)
- rows empty = return "rows": []

## Full-Text Search (FTS)

### Setup (once per database)

  -- Custom FTS config: unaccent + french stemming
  CREATE TEXT SEARCH CONFIGURATION pgv_search (COPY = french);
  ALTER TEXT SEARCH CONFIGURATION pgv_search
    ALTER MAPPING FOR hword, hword_part, word
    WITH unaccent, french_stem;

### Per table

Add a generated tsvector column with weighted fields:

  ALTER TABLE {schema}.{table} ADD COLUMN search_vec tsvector
    GENERATED ALWAYS AS (
      setweight(to_tsvector('pgv_search', coalesce({col_A},'')), 'A') ||
      setweight(to_tsvector('pgv_search', coalesce({col_B},'')), 'B')
    ) STORED;

  CREATE INDEX idx_{table}_search ON {schema}.{table} USING GIN(search_vec);

Weights: A = most relevant (title, name), B = secondary (body, description),
C = tertiary, D = least relevant.

### In data_*() functions

  AND (v_q IS NULL OR search_vec @@ plainto_tsquery('pgv_search', v_q))

FTS features:
- Stemming: "facture" matches "factures", "facturation", "facture"
- Accent-insensitive: "resolu" matches "resolu"
- Case-insensitive: "FACTURE" matches "facture"
- Ranking: ts_rank(search_vec, query) for relevance ordering

### Multilingual

pgv_search defaults to French. For other languages, create additional configs:

  CREATE TEXT SEARCH CONFIGURATION pgv_search_en (COPY = english);
  ALTER TEXT SEARCH CONFIGURATION pgv_search_en
    ALTER MAPPING FOR hword, hword_part, word
    WITH unaccent, english_stem;

Per-tenant language config via workbench.config or tenant.lang column.

## Skeleton

  CREATE FUNCTION {schema}.data_{resource}(p_params jsonb DEFAULT '{}')
  RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
  DECLARE
    -- Business filters
    v_status text := p_params->>'p_status';
    v_from   text := p_params->>'p_from';
    -- Search
    v_q      text := p_params->>'q';
    -- Meta
    v_page   int  := coalesce((p_params->>'_page')::int, 1);
    v_size   int  := coalesce((p_params->>'_size')::int, 20);
    -- Result
    v_total  int;
    v_rows   jsonb;
  BEGIN
    -- Count (same WHERE, no LIMIT)
    SELECT count(*) INTO v_total
    FROM {schema}.{table} t
    WHERE (v_status IS NULL OR t.status = v_status)
      AND (v_from IS NULL OR t.from_col = v_from)
      AND (v_q IS NULL OR t.search_vec @@ plainto_tsquery('pgv_search', v_q));

    -- Rows (paginated)
    SELECT coalesce(jsonb_agg(row), '[]') INTO v_rows
    FROM (
      SELECT jsonb_build_array(t.id, t.col_a, t.col_b, t.status, t.created_at) AS row
      FROM {schema}.{table} t
      WHERE (v_status IS NULL OR t.status = v_status)
        AND (v_from IS NULL OR t.from_col = v_from)
        AND (v_q IS NULL OR t.search_vec @@ plainto_tsquery('pgv_search', v_q))
      ORDER BY t.created_at DESC
      LIMIT v_size OFFSET (v_page - 1) * v_size
    ) sub;

    RETURN jsonb_build_object(
      'total', v_total,
      'page',  v_page,
      'size',  v_size,
      'rows',  v_rows
    );
  END;
  $$;

## PostgREST routing

data_* functions are called directly, NOT through pgv.route():

  POST /rpc/data_{resource}
  Content-Profile: {schema}
  Content-Type: application/json
  Accept: application/json
  Body: {"p_params": {"p_status": "new", "q": "facture", "_page": 1}}

## Grants

Same as get_*/post_*:

  GRANT EXECUTE ON FUNCTION {schema}.data_{resource}(jsonb) TO web_anon;

## pgv.table() integration

The page function (get_*) declares the table config:

  pgv.table(jsonb_build_object(
    'rpc',     'data_messages',
    'schema',  'workbench',
    'filters', jsonb_build_array(
      jsonb_build_object('name','p_status','type','select','label','Statut',
        'options', jsonb_build_array(
          jsonb_build_array('','Tous'),
          jsonb_build_array('new','Nouveau'))),
      jsonb_build_object('name','q','type','search','label','Recherche')
    ),
    'cols', jsonb_build_array(
      jsonb_build_object('key','id','label','#','class','pgv-col-link',
        'href','/workbench/message?p_id={id}'),
      jsonb_build_object('key','from','label','De'),
      jsonb_build_object('key','status','label','Statut','class','pgv-col-badge'),
      jsonb_build_object('key','date','label','Date','class','pgv-col-date')
    ),
    'page_size', 20
  ))

The Alpine plugin pgvTable handles: rendering, filtering, sorting (client),
pagination (server), search (FTS via q), loading states.
