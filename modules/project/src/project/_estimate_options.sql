CREATE OR REPLACE FUNCTION project._estimate_options(p_client_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE v_html text := ''; r record;
BEGIN
  FOR r IN SELECT d.id, d.number, d.subject FROM quote.estimate d
    WHERE d.status = 'accepted' AND (p_client_id IS NULL OR d.client_id = p_client_id)
    ORDER BY d.created_at DESC
  LOOP
    v_html := v_html || '<option value="' || r.id || '">' || pgv.esc(r.number || ' — ' || r.subject) || '</option>';
  END LOOP;
  RETURN v_html;
END;
$function$;
