CREATE OR REPLACE FUNCTION docman.page_detail(p_doc_id uuid)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc jsonb;
  v_body text;
  v_label jsonb;
  v_entity jsonb;
  v_relation jsonb;
  v_labels_html text := '';
  v_entities_html text := '';
  v_relations_html text := '';
BEGIN
  v_doc := docman.peek(p_doc_id);

  IF v_doc ? 'error' THEN
    RETURN pgv.page('Erreur', '/docs', app.nav_items(),
      '<p>Document non trouve.</p>');
  END IF;

  -- Info card
  v_body := pgv.card('Informations',
    pgv.dl(
      'Fichier', pgv.esc(v_doc->>'filename'),
      'Chemin', pgv.esc(v_doc->>'file_path'),
      'Type', coalesce(pgv.badge(v_doc->>'doc_type', 'primary'), pgv.badge('non classe', 'warning')),
      'Date document', coalesce(v_doc->>'document_date', '-'),
      'Source', pgv.esc(coalesce(v_doc->>'source', '-')),
      'Taille', pgv.filesize((v_doc->>'size_bytes')::bigint),
      'Importe le', pgv.esc(left(v_doc->>'created_at', 10))
    ),
    CASE WHEN v_doc->>'classified_at' IS NULL THEN
      pgv.action('/rpc/page?p_path=/docs/' || p_doc_id || '/classify', 'Classifier', '#app')
    ELSE
      pgv.badge('Classe le ' || left(v_doc->>'classified_at', 10), 'success')
    END
  );

  -- Summary
  IF v_doc->>'summary' IS NOT NULL THEN
    v_body := v_body || pgv.card('Resume', '<p>' || pgv.esc(v_doc->>'summary') || '</p>');
  END IF;

  -- Labels
  FOR v_label IN SELECT * FROM jsonb_array_elements(v_doc->'labels')
  LOOP
    v_labels_html := v_labels_html
      || pgv.badge(v_label->>'name',
          CASE (v_label->>'kind') WHEN 'category' THEN 'primary' ELSE 'default' END)
      || ' ';
  END LOOP;
  IF v_labels_html = '' THEN v_labels_html := '<em>Aucun label</em>'; END IF;
  v_body := v_body || pgv.card('Labels', v_labels_html);

  -- Entities
  FOR v_entity IN SELECT * FROM jsonb_array_elements(v_doc->'entities')
  LOOP
    v_entities_html := v_entities_html || '<tr>'
      || '<td>' || pgv.esc(v_entity->>'kind') || '</td>'
      || '<td>' || pgv.esc(v_entity->>'name') || '</td>'
      || '<td>' || pgv.esc(v_entity->>'role') || '</td>'
      || '</tr>';
  END LOOP;
  IF v_entities_html = '' THEN
    v_body := v_body || pgv.card('Entites', '<em>Aucune entite liee</em>');
  ELSE
    v_body := v_body || pgv.card('Entites',
      '<table role="grid"><thead><tr><th>Type</th><th>Nom</th><th>Role</th></tr></thead><tbody>'
      || v_entities_html || '</tbody></table>');
  END IF;

  -- Relations
  FOR v_relation IN SELECT * FROM jsonb_array_elements(v_doc->'relations')
  LOOP
    v_relations_html := v_relations_html || '<tr>'
      || '<td>' || pgv.esc(v_relation->>'kind') || '</td>'
      || '<td><a href="/docs/' || (v_relation->>'related_id')
      || '" hx-get="/rpc/page?p_path=/docs/' || (v_relation->>'related_id')
      || '" hx-push-url="/docs/' || (v_relation->>'related_id') || '">'
      || pgv.esc(v_relation->>'related_file') || '</a></td>'
      || '<td>' || pgv.esc(v_relation->>'direction') || '</td>'
      || '</tr>';
  END LOOP;
  IF v_relations_html = '' THEN
    v_body := v_body || pgv.card('Relations', '<em>Aucune relation</em>');
  ELSE
    v_body := v_body || pgv.card('Relations',
      '<table role="grid"><thead><tr><th>Type</th><th>Document</th><th>Direction</th></tr></thead><tbody>'
      || v_relations_html || '</tbody></table>');
  END IF;

  RETURN pgv.page(v_doc->>'filename', '/docs/' || p_doc_id, app.nav_items(), v_body);
END;
$function$;
