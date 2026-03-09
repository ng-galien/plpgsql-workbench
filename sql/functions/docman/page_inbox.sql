CREATE OR REPLACE FUNCTION docman.page_inbox()
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_docs jsonb;
  v_body text := '';
  v_doc jsonb;
  v_id text;
BEGIN
  v_docs := docman.search('{"classified": false, "limit": 50}'::jsonb);

  IF jsonb_array_length(v_docs) = 0 THEN
    RETURN pgv.page('Inbox', '/docs', app.nav_items(),
      pgv.card(null, '<p>Aucun document en attente de classification.</p>'));
  END IF;

  v_body := '<table role="grid"><thead><tr>'
    || '<th>Fichier</th><th>Type</th><th>Source</th><th>Taille</th><th>Date import</th>'
    || '</tr></thead><tbody>';

  FOR v_doc IN SELECT * FROM jsonb_array_elements(v_docs)
  LOOP
    v_id := v_doc->>'id';
    v_body := v_body || '<tr>'
      || '<td><a href="/docs/' || v_id || '" hx-get="/rpc/page?p_path=/docs/' || v_id || '" hx-push-url="/docs/' || v_id || '">'
      || pgv.esc(v_doc->>'filename') || '</a></td>'
      || '<td>' || coalesce(pgv.badge(v_doc->>'extension'), '-') || '</td>'
      || '<td>' || pgv.esc(coalesce(v_doc->>'source', '-')) || '</td>'
      || '<td>' || pgv.filesize((v_doc->>'size_bytes')::bigint) || '</td>'
      || '<td>' || pgv.esc(left(v_doc->>'created_at', 10)) || '</td>'
      || '</tr>';
  END LOOP;

  v_body := v_body || '</tbody></table>';

  RETURN pgv.page('Inbox (' || jsonb_array_length(v_docs) || ')', '/docs', app.nav_items(), v_body);
END;
$function$;
