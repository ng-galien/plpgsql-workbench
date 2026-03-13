CREATE OR REPLACE FUNCTION quote._mentions_html()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text := '';
  r record;
  v_has_any boolean := false;
BEGIN
  FOR r IN SELECT label, texte FROM quote.mention WHERE active = true ORDER BY id
  LOOP
    v_has_any := true;
    v_html := v_html || '<dt>' || pgv.esc(r.label) || '</dt><dd>' || pgv.esc(r.texte) || '</dd>';
  END LOOP;

  IF NOT v_has_any THEN
    RETURN '';
  END IF;

  RETURN '<details><summary>' || pgv.t('quote.title_mentions') || '</summary><dl>' || v_html || '</dl></details>';
END;
$function$;
