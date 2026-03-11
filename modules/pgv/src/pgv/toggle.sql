CREATE OR REPLACE FUNCTION pgv.toggle(p_name text, p_label text, p_checked boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<label><input type="checkbox" name="' || p_name || '" role="switch"'
    || CASE WHEN p_checked THEN ' checked' ELSE '' END
    || '> ' || pgv.esc(p_label) || '</label>';
$function$;
