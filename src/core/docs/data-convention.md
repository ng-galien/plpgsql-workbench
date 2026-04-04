---
topic: data-convention
---
# Convention data_* — Query API for table data sources

## Overview

`data_*` functions serve JSON datasets for table-oriented clients.
They handle filtering, search (FTS), and cursor-based navigation (next/prev).

Convention: `data_*` = JSON datasets consumed by the client shell or SDUI components.

## Signature

  data_{resource}(p_params jsonb DEFAULT '{}') RETURNS jsonb

Always jsonb in, jsonb out. One signature, no ambiguity.

## Input parameters (p_params)

Three namespaces in the same object:

  Prefix   Role                              Examples
  -------  --------------------------------  -----------------------
  p_*      Business filters (exact match)    p_status, p_from, p_type
  q        Full-text search (FTS)            q
  _*       Meta (navigation)                 _offset, _size

Example:

  {"p_status": "new", "p_from": "lead", "q": "facture", "_offset": 0, "_size": 20}

Rules:
- p_* = WHERE exact match (NULL = no filter)
- q = WHERE FTS via search_vec @@ plainto_tsquery
- _offset = 0-based, default 0 (managed by the plugin, not the user)
- _size = page size, default 20

## Output format

  {
    "rows": [
      [1, "lead", "pgv", "new", "2026-03-13 14:30"],
      [2, "ops", "cad", "resolved", "2026-03-12 10:15"]
    ],
    "has_more": true
  }

- No `cols` in response — columns declared in pgv.table() config
- rows = array of arrays, order matches cols in config
- has_more = true if there are more rows beyond current page (LIMIT size+1 trick)
- No `total` — no COUNT(*) query, cursor-based navigation only
- rows empty = return "rows": [], "has_more": false

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
    v_offset int := coalesce((p_params->>'_offset')::int, 0);
    v_size   int := coalesce((p_params->>'_size')::int, 20);
    -- Result
    v_rows   jsonb;
    v_has_more bool;
  BEGIN
    -- Fetch size+1 rows to detect has_more
    SELECT coalesce(jsonb_agg(row), '[]') INTO v_rows
    FROM (
      SELECT jsonb_build_array(t.id, t.col_a, t.col_b, t.status, t.created_at) AS row
      FROM {schema}.{table} t
      WHERE (v_status IS NULL OR t.status = v_status)
        AND (v_from IS NULL OR t.from_col = v_from)
        AND (v_q IS NULL OR t.search_vec @@ plainto_tsquery('pgv_search', v_q))
      ORDER BY t.created_at DESC
      LIMIT v_size + 1 OFFSET v_offset
    ) sub;

    -- If we got size+1 rows, there's more — trim the extra row
    v_has_more := jsonb_array_length(v_rows) > v_size;
    IF v_has_more THEN
      v_rows := v_rows - v_size;  -- remove last element
    END IF;

    RETURN jsonb_build_object(
      'rows',     v_rows,
      'has_more', v_has_more
    );
  END;
  $$;

## PostgREST routing

`data_*` functions are called directly over RPC:

  POST /rpc/data_{resource}
  Content-Profile: {schema}
  Content-Type: application/json
  Accept: application/json
  Body: {"p_params": {"p_status": "new", "q": "facture", "_offset": 0}}

## Grants

Like the rest of the backend JSON API:

  GRANT EXECUTE ON FUNCTION {schema}.data_{resource}(jsonb) TO anon;

## Table integration

A SDUI client or table component declares the datasource config:

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

The client handles rendering, filtering UI, sorting (client),
next/prev navigation (server), search (FTS via q), and loading states.

## i18n keys

All table labels should use `pgv.t()` for internationalization:

  Key                    Default (fr)       Usage
  ---------------------  -----------------  ---------------------------
  pgv.table_next         Suivant            Next button
  pgv.table_prev         Précédent          Previous button
  pgv.table_empty        Aucun résultat     Empty state message
  pgv.table_loading      Chargement…        Loading state
  pgv.table_search       Rechercher…        Search input placeholder

These keys must be seeded in pgv.i18n_seed() and fr.json.
