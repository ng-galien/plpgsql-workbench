CREATE OR REPLACE FUNCTION pgv.progress(p_value numeric, p_max numeric DEFAULT 100, p_label text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<div class="pgv-progress">'
    || CASE WHEN p_label IS NOT NULL
         THEN '<label>' || pgv.esc(p_label) || ' <small>' || round(p_value / p_max * 100) || '%</small></label>'
         ELSE '' END
    || '<progress value="' || p_value || '" max="' || p_max || '"></progress>'
    || '</div>';
$function$;
