CREATE OR REPLACE FUNCTION purchase._fournisseur_options()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text := '<option value="">-- Choisir un fournisseur --</option>';
  r record;
BEGIN
  FOR r IN SELECT id, name FROM crm.client WHERE active ORDER BY name LOOP
    v_html := v_html || format('<option value="%s">%s</option>', r.id, pgv.esc(r.name));
  END LOOP;
  RETURN v_html;
END;
$function$;
