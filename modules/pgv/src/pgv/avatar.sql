CREATE OR REPLACE FUNCTION pgv.avatar(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<span class="pgv-avatar" title="' || pgv.esc(p_name) || '">'
    || upper(left(split_part(p_name, ' ', 1), 1)
    || coalesce(nullif(left(split_part(p_name, ' ', 2), 1), ''), ''))
    || '</span>';
$function$;
