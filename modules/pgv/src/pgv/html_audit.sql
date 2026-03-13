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
  v_rules := '[
    {"tag":"<template data-toast",  "prim":"pgv.toast()",     "call":"pgv.toast("},
    {"tag":"<template data-redirect","prim":"pgv.redirect()", "call":"pgv.redirect("},
    {"tag":"<form data-rpc",        "prim":"pgv.form()",      "call":"pgv.form("},
    {"tag":"<button data-rpc",      "prim":"pgv.action()",    "call":"pgv.action("},
    {"tag":"<details>",             "prim":"pgv.accordion()", "call":"pgv.accordion("},
    {"tag":"<select>",              "prim":"pgv.sel()",       "call":"pgv.sel("},
    {"tag":"<dl>",                  "prim":"pgv.dl()",        "call":"pgv.dl("},
    {"tag":"<article",              "prim":"pgv.card()",      "call":"pgv.card("}
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
             f.def LIKE '%' || (r->>'call') || '%' AS has_call
      FROM fn_bodies f
      CROSS JOIN jsonb_array_elements(v_rules) AS r
    )
    SELECT proname, tag, prim
    FROM rule_checks
    WHERE has_tag AND NOT has_call
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
