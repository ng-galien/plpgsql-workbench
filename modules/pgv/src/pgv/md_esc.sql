CREATE OR REPLACE FUNCTION pgv.md_esc(p_text text, p_max_len integer DEFAULT 80)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT left(
    replace(replace(replace(pgv.esc(p_text), '|', '\|'), E'\n', ' '), E'\r', ''),
    p_max_len
  );
$function$;
