CREATE OR REPLACE FUNCTION project._client_options()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text := '';
  r record;
BEGIN
  FOR r IN SELECT id, name FROM crm.client WHERE active ORDER BY name LOOP
    v_html := v_html || '<option value="' || r.id || '">' || pgv.esc(r.name) || '</option>';
  END LOOP;
  RETURN v_html;
END;
$function$;
