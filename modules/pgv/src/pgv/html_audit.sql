CREATE OR REPLACE FUNCTION pgv.html_audit(p_schema text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_rec record;
  v_rows text := '';
  v_warn int := 0;
  v_ok int := 0;
  v_rules jsonb;
BEGIN
  -- Rules: tag pattern -> primitive, with exclusion if primitive is also called
  -- excl: if present, skip match when this pattern is also found (avoids false positives)
  v_rules := '[
    {"tag":"<template data-toast",  "prim":"pgv.toast()",          "call":"pgv.toast("},
    {"tag":"<template data-redirect","prim":"pgv.redirect()",     "call":"pgv.redirect("},
    {"tag":"<form data-rpc",        "prim":"pgv.form()",          "call":"pgv.form("},
    {"tag":"<button data-rpc",      "prim":"pgv.action()",        "call":"pgv.action("},
    {"tag":"<details>",             "prim":"pgv.accordion()",     "call":"pgv.accordion("},
    {"tag":"<select>",              "prim":"pgv.sel()",           "call":"pgv.sel("},
    {"tag":"<dl>",                  "prim":"pgv.dl()",            "call":"pgv.dl("},
    {"tag":"<article",              "prim":"pgv.card()",          "call":"pgv.card("},
    {"tag":"<input ",               "prim":"pgv.input()",         "call":"pgv.input(",         "excl":"type=\\\"hidden\\\""},
    {"tag":"type=\\\"checkbox\\\"","prim":"pgv.checkbox()",     "call":"pgv.checkbox("},
    {"tag":"type=\\\"radio\\\"",   "prim":"pgv.radio()",         "call":"pgv.radio("},
    {"tag":"<textarea",             "prim":"pgv.textarea()",      "call":"pgv.textarea("},
    {"tag":"<progress",             "prim":"pgv.progress()",      "call":"pgv.progress("},
    {"tag":"<table",                "prim":"pgv.md_table()",      "call":"pgv.md_table("},
    {"tag":"pgv-alert",             "prim":"pgv.alert()",         "call":"pgv.alert("},
    {"tag":"pgv-badge",             "prim":"pgv.badge()",         "call":"pgv.badge("},
    {"tag":"pgv-stat",              "prim":"pgv.stat()",          "call":"pgv.stat("},
    {"tag":"pgv-grid",              "prim":"pgv.grid()",          "call":"pgv.grid("},
    {"tag":"pgv-tabs",              "prim":"pgv.tabs()",          "call":"pgv.tabs("},
    {"tag":"pgv-breadcrumb",        "prim":"pgv.breadcrumb()",    "call":"pgv.breadcrumb("},
    {"tag":"pgv-empty",             "prim":"pgv.empty()",         "call":"pgv.empty("},
    {"tag":"pgv-timeline",          "prim":"pgv.timeline()",      "call":"pgv.timeline("},
    {"tag":"pgv-workflow",          "prim":"pgv.workflow()",      "call":"pgv.workflow("},
    {"tag":"pgv-avatar",            "prim":"pgv.avatar()",        "call":"pgv.avatar("},
    {"tag":"selectSearch",          "prim":"pgv.select_search()", "call":"pgv.select_search("},
    {"tag":"x-data=\\\"lazy\\\"","prim":"pgv.lazy()",           "call":"pgv.lazy("}
  ]'::jsonb;

  FOR v_rec IN
    WITH fn_bodies AS (
      SELECT p.proname, p.prosrc AS def
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema
        AND (p.proname LIKE 'get_%' OR p.proname LIKE 'post_%')
    ),
    rule_checks AS (
      SELECT f.proname,
             r->>'tag' AS tag,
             r->>'prim' AS prim,
             f.def LIKE '%' || (r->>'tag') || '%' AS has_tag,
             f.def LIKE '%' || (r->>'call') || '%' AS has_call,
             CASE WHEN r->>'excl' IS NOT NULL
                  THEN f.def LIKE '%' || (r->>'excl') || '%'
                  ELSE false END AS has_excl
      FROM fn_bodies f
      CROSS JOIN jsonb_array_elements(v_rules) AS r
    )
    SELECT proname, tag, prim
    FROM rule_checks
    WHERE has_tag AND NOT has_call AND NOT has_excl
    ORDER BY proname, tag
  LOOP
    v_rows := v_rows || '| ' || pgv.badge('WARN', 'warning')
      || ' | ' || v_rec.proname || '()'
      || ' | `' || pgv.esc(v_rec.tag) || '`'
      || ' | ' || v_rec.prim || ' |' || chr(10);
    v_warn := v_warn + 1;
  END LOOP;

  IF v_warn = 0 THEN
    v_ok := 1;
  END IF;

  RETURN pgv.dl(
    'HTML audit', p_schema,
    'Bilan',
      CASE WHEN v_warn > 0 THEN pgv.badge(v_warn || ' raw HTML', 'warning') || ' ' ELSE '' END
      || CASE WHEN v_ok > 0 THEN pgv.badge('clean', 'success') ELSE '' END)
    || '<md>' || chr(10)
    || '| Niveau | Source | Tag | Primitive |' || chr(10)
    || '|--------|--------|-----|-----------|' || chr(10)
    || v_rows
    || '</md>';
END;
$function$;
