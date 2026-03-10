CREATE OR REPLACE FUNCTION pgv.dl(VARIADIC p_pairs text[])
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE v_html text := '<dl class="pgv-dl">'; i int;
BEGIN
  FOR i IN 1..array_length(p_pairs, 1) BY 2 LOOP
    v_html := v_html || '<dt>' || p_pairs[i] || '</dt><dd>' || coalesce(p_pairs[i+1], '-') || '</dd>';
  END LOOP;
  RETURN v_html || '</dl>';
END;
$function$;
