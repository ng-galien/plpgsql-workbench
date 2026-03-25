CREATE OR REPLACE FUNCTION quote._legal_notices_html()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text := '';
  r record;
  v_has_any boolean := false;
BEGIN
  FOR r IN SELECT label, body FROM quote.legal_notice WHERE active = true ORDER BY id
  LOOP
    v_has_any := true;
    v_html := v_html || '<dt>' || pgv.esc(r.label) || '</dt><dd>' || pgv.esc(r.body) || '</dd>';
  END LOOP;

  IF NOT v_has_any THEN
    RETURN '';
  END IF;

  RETURN pgv.accordion(VARIADIC ARRAY[pgv.t('quote.title_mentions'), '<dl>' || v_html || '</dl>']);
END;
$function$;
