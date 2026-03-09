CREATE OR REPLACE FUNCTION docman.frag_search(p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_filters jsonb := '{}'::jsonb;
  v_docs jsonb;
  v_doc jsonb;
  v_id text;
  v_body text := '';
BEGIN
  -- Build filters from form data
  IF nullif(p_body->>'q', '') IS NOT NULL THEN
    v_filters := v_filters || jsonb_build_object('q', p_body->>'q');
  END IF;
  IF nullif(p_body->>'doc_type', '') IS NOT NULL THEN
    v_filters := v_filters || jsonb_build_object('doc_type', p_body->>'doc_type');
  END IF;
  IF nullif(p_body->>'source', '') IS NOT NULL THEN
    v_filters := v_filters || jsonb_build_object('source', p_body->>'source');
  END IF;
  IF nullif(p_body->>'extension', '') IS NOT NULL THEN
    v_filters := v_filters || jsonb_build_object('extension', p_body->>'extension');
  END IF;

  v_docs := docman.search(v_filters);

  IF jsonb_array_length(v_docs) = 0 THEN
    RETURN '<p><em>Aucun resultat.</em></p>'::"text/html";
  END IF;

  v_body := '<table role="grid"><thead><tr>'
    || '<th>Fichier</th><th>Type doc</th><th>Ext</th><th>Source</th><th>Taille</th><th>Date</th><th>Statut</th>'
    || '</tr></thead><tbody>';

  FOR v_doc IN SELECT * FROM jsonb_array_elements(v_docs)
  LOOP
    v_id := v_doc->>'id';
    v_body := v_body || '<tr>'
      || '<td><a href="/docs/' || v_id || '" hx-get="/rpc/page?p_path=/docs/' || v_id || '" hx-push-url="/docs/' || v_id || '">'
      || pgv.esc(v_doc->>'filename') || '</a></td>'
      || '<td>' || coalesce(pgv.badge(v_doc->>'doc_type', 'primary'), '-') || '</td>'
      || '<td>' || coalesce(pgv.badge(v_doc->>'extension'), '-') || '</td>'
      || '<td>' || pgv.esc(coalesce(v_doc->>'source', '-')) || '</td>'
      || '<td>' || pgv.filesize((v_doc->>'size_bytes')::bigint) || '</td>'
      || '<td>' || coalesce(v_doc->>'document_date', left(v_doc->>'created_at', 10)) || '</td>'
      || '<td>' || CASE WHEN v_doc->>'classified_at' IS NOT NULL
          THEN pgv.badge('classe', 'success')
          ELSE pgv.badge('en attente', 'warning')
        END || '</td>'
      || '</tr>';
  END LOOP;

  v_body := v_body || '</tbody></table>';
  v_body := v_body || '<small>' || jsonb_array_length(v_docs) || ' resultat(s)</small>';

  RETURN v_body::"text/html";
END;
$function$;
