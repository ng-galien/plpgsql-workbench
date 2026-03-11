CREATE OR REPLACE FUNCTION cad.help(p_filter text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rec record;
  v_out text := 'CAD Spatial Toolbox' || E'\n';
BEGIN
  v_out := v_out || '===================' || E'\n';

  FOR v_rec IN
    SELECT p.proname AS name,
           pg_catalog.pg_get_function_identity_arguments(p.oid) AS args,
           d.description AS doc
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    LEFT JOIN pg_catalog.pg_description d ON d.objoid = p.oid
    WHERE n.nspname = 'cad'
      AND (p_filter IS NULL OR p.proname ILIKE '%' || p_filter || '%'
           OR coalesce(d.description, '') ILIKE '%' || p_filter || '%')
    ORDER BY p.proname
  LOOP
    v_out := v_out || E'\n' || v_rec.name || '(' || v_rec.args || ')'
      || E'\n  ' || coalesce(v_rec.doc, '(no description)')
      || E'\n';
  END LOOP;

  RETURN v_out;
END;
$function$;
